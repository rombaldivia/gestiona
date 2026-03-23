import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/e164_phone_utils.dart';
import '../../inventory/domain/stock_movement.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../quotes/domain/quote_line.dart';
import '../../quotes/ui/widgets/quote_add_item_sheet.dart';
import '../../quotes/ui/widgets/quote_line_tile.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../domain/sale.dart';
import '../domain/sale_document_type.dart';
import '../domain/sale_status.dart';
import '../presentation/sales_controller.dart';

class SaleEditorPage extends ConsumerStatefulWidget {
  const SaleEditorPage({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<SaleEditorPage> createState() => _SaleEditorPageState();
}

class _SaleEditorPageState extends ConsumerState<SaleEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _docCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _notesCtrl;

  SaleDocumentType _documentType = SaleDocumentType.nit;
  SaleStatus _status = SaleStatus.completed;
  String _phoneE164 = '';
  late final String _phoneInitialCountryCode;
  late final String _phoneInitialNationalNumber;

  bool _saving = false;
  final List<QuoteLine> _lines = [];

  bool get _inventoryLocked => widget.sale.stockApplied;

  @override
  void initState() {
    super.initState();
    _docCtrl = TextEditingController(text: widget.sale.documentNumber ?? '');
    _nameCtrl = TextEditingController(
      text: widget.sale.customerNameOrBusinessName ?? '',
    );
    _emailCtrl = TextEditingController(text: widget.sale.customerEmail ?? '');
    _notesCtrl = TextEditingController(text: widget.sale.notes ?? '');

    _documentType = widget.sale.documentType ?? SaleDocumentType.nit;
    _status = widget.sale.status;

    final parsedPhone = parsePhoneForField(widget.sale.customerPhone);
    _phoneInitialCountryCode = parsedPhone.iso2Code;
    _phoneInitialNationalNumber = parsedPhone.nationalNumber;
    _phoneE164 = widget.sale.customerPhone ?? '';

    _lines.addAll(widget.sale.lines);
  }

  @override
  void dispose() {
    _docCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  Future<void> _addItem() async {
    if (_inventoryLocked) {
      _showInfo(
        'Esta venta ya aplicó inventario. Por seguridad, el detalle ya no se puede modificar.',
      );
      return;
    }

    final invItems = ref.read(inventoryItemsProvider);

    final line = await showModalBottomSheet<QuoteLine?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuoteAddItemSheet(inventoryItems: invItems),
    );

    if (line == null) return;
    setState(() => _lines.add(line));
  }

  void _editQty(String lineId, double qty) {
    if (_inventoryLocked) {
      _showInfo(
        'Esta venta ya aplicó inventario. El detalle está bloqueado para evitar doble descuento.',
      );
      return;
    }

    final i = _lines.indexWhere((e) => e.lineId == lineId);
    if (i < 0) return;

    setState(() {
      _lines[i] = _lines[i].copyWith(qty: qty);
    });
  }

  void _removeLine(String lineId) {
    if (_inventoryLocked) {
      _showInfo(
        'Esta venta ya aplicó inventario. El detalle está bloqueado para evitar inconsistencias.',
      );
      return;
    }

    setState(() {
      _lines.removeWhere((e) => e.lineId == lineId);
    });
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _applyStockForCompletedSale(Sale sale) async {
    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }

    final ent = await ref.read(entitlementsProvider(user.uid).future);
    final inventory = ref.read(inventoryItemsProvider);
    final grouped = _groupInventoryQuantities(sale.lines);

    for (final entry in grouped.entries) {
      final itemId = entry.key;
      final qty = entry.value;
      final item = inventory.where((x) => x.id == itemId).firstOrNull;

      if (item == null) {
        throw StateError('No se encontró el ítem de inventario $itemId.');
      }

      if (!item.tracksStock) continue;

      if (item.stock < qty) {
        throw StateError(
          'Stock insuficiente para "${item.name}". Disponible: ${item.stock.toStringAsFixed(0)} · Requerido: ${qty.toStringAsFixed(0)}',
        );
      }

      await ref.read(inventoryControllerProvider.notifier).adjustStock(
            itemId: itemId,
            delta: -qty,
            type: StockMovementType.outQty,
            note: 'Venta ${sale.numberLabel}',
            ent: ent,
          );
    }
  }

  Future<void> _restoreStockFromAppliedSale(Sale sale) async {
    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }

    final ent = await ref.read(entitlementsProvider(user.uid).future);
    final inventory = ref.read(inventoryItemsProvider);
    final grouped = _groupInventoryQuantities(sale.lines);

    for (final entry in grouped.entries) {
      final itemId = entry.key;
      final qty = entry.value;
      final item = inventory.where((x) => x.id == itemId).firstOrNull;

      if (item == null) continue;
      if (!item.tracksStock) continue;

      await ref.read(inventoryControllerProvider.notifier).adjustStock(
            itemId: itemId,
            delta: qty,
            type: StockMovementType.inQty,
            note: 'Reversión ${sale.numberLabel}',
            ent: ent,
          );
    }
  }

  Map<String, double> _groupInventoryQuantities(List<QuoteLine> lines) {
    final result = <String, double>{};

    for (final line in lines) {
      final itemId = line.inventoryItemId;
      if (itemId == null || itemId.trim().isEmpty) continue;
      result[itemId] = (result[itemId] ?? 0) + line.qty;
    }

    return result;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_lines.isEmpty) {
      _showInfo('Agrega al menos un ítem a la venta.');
      return;
    }

    setState(() => _saving = true);

    try {
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty && !email.contains('@')) {
        _showInfo('Correo electrónico inválido.');
        return;
      }

      var sale = widget.sale.copyWith(
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        status: _status,
        documentType: _documentType,
        documentNumber: _docCtrl.text.trim().isEmpty ? null : _docCtrl.text.trim(),
        customerNameOrBusinessName:
            _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        customerPhone: _phoneE164.trim().isEmpty ? null : _phoneE164.trim(),
        customerEmail: email.isEmpty ? null : email,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: List<QuoteLine>.from(_lines),
      );

      final wasApplied = widget.sale.stockApplied;
      final nowCompleted = sale.status == SaleStatus.completed;

      if (!wasApplied && nowCompleted) {
        await _applyStockForCompletedSale(sale);
        sale = sale.copyWith(stockApplied: true);
      } else if (wasApplied && !nowCompleted) {
        await _restoreStockFromAppliedSale(widget.sale);
        sale = sale.copyWith(stockApplied: false);
      } else {
        sale = sale.copyWith(stockApplied: wasApplied);
      }

      await ref.read(salesControllerProvider.notifier).upsert(sale);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showInfo(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<double>(0, (sum, line) => sum + line.lineTotalBob);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sale.numberLabel),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_saving ? 'Registrando...' : 'Registrar venta'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_inventoryLocked) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Esta venta ya actualizó inventario. Puedes cambiar datos del cliente o anularla, pero el detalle está bloqueado para evitar doble descuento.',
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datos del cliente', style: AppTextStyles.title),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<SaleDocumentType>(
                    initialValue: _documentType,
                    items: SaleDocumentType.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _documentType = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _docCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText:
                          _documentType == SaleDocumentType.nit ? 'NIT' : 'CI',
                      hintText: _documentType == SaleDocumentType.nit
                          ? 'Ej: 1020304050'
                          : 'Ej: 1234567',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre o razón social',
                      hintText: 'Ej: Juan Pérez o Imprenta Andina SRL',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) {
                      final hasDoc = _docCtrl.text.trim().isNotEmpty;
                      if (hasDoc && (v == null || v.trim().isEmpty)) {
                        return 'Si llenas documento, llena también el nombre.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  IntlPhoneField(
                    initialCountryCode: _phoneInitialCountryCode,
                    initialValue: _phoneInitialNationalNumber,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    onChanged: (p) => _phoneE164 = p.completeNumber,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'tucorreo@ejemplo.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SaleStatus>(
                    initialValue: _status,
                    items: SaleStatus.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _status = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      hintText: 'Observaciones de la venta',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Detalle', style: AppTextStyles.title),
                ),
                FilledButton.icon(
                  onPressed: _inventoryLocked ? null : _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar ítem'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_lines.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Todavía no agregaste ítems a la venta.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: QuoteLineTile(
                    line: line,
                    onRemove: () => _removeLine(line.lineId),
                    onEditQty: (qty) => _editQty(line.lineId, qty),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resumen', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  _SummaryRow(label: 'Subtotal', value: 'Bs ${_fmt(total)}'),
                  const SizedBox(height: 6),
                  _SummaryRow(
                    label: 'Total',
                    value: 'Bs ${_fmt(total)}',
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? AppTextStyles.title.copyWith(fontSize: 16)
        : AppTextStyles.body.copyWith(fontSize: 14);

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
