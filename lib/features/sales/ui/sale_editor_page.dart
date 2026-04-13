import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/e164_phone_utils.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../inventory/domain/stock_movement.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../quotes/domain/quote_line.dart';
import '../../quotes/ui/widgets/quote_add_item_sheet.dart';
import '../../quotes/ui/widgets/quote_line_tile.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../domain/sale.dart';
import '../domain/sale_document_type.dart';
import '../domain/sale_status.dart';
import '../../../core/widgets/module_permission_guard.dart';
import '../presentation/sales_controller.dart';

class SaleEditorPage extends ConsumerStatefulWidget {
  const SaleEditorPage({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<SaleEditorPage> createState() => _SaleEditorPageState();
}

enum _SaleStockDecision {
  cancel,
  continueSale,
  restock,
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

  String _buildE164Phone({
    required String countryCode,
    required String nationalNumber,
  }) {
    final cc = countryCode.trim();
    final nn = nationalNumber.trim().replaceAll(RegExp(r'\s+'), '');
    if (nn.isEmpty) return '';
    if (cc.isEmpty) return nn;
    return '$cc$nn';
  }

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

    final canAdd = await _handleStockWarningBeforeAdd(line);
    if (!canAdd) return;

    setState(() => _lines.add(line));
  }

  Future<bool> _handleStockWarningBeforeAdd(QuoteLine line) async {
    final itemId = line.inventoryItemId;
    if (itemId == null || itemId.trim().isEmpty) return true;

    InventoryItem? item =
        ref.read(inventoryItemsProvider).where((x) => x.id == itemId).firstOrNull;

    if (item == null || !item.tracksStock) return true;
    if (item.stock >= line.qty) return true;

    while (item!.stock < line.qty) {
      final missingQty = line.qty - item.stock;
      final decision = await _showStockDecisionDialog(
        item: item,
        missingQty: missingQty,
        title: 'Stock insuficiente',
        messagePrefix:
            'El ítem "${item.name}" no tiene stock suficiente para esta venta.',
      );

      if (decision == _SaleStockDecision.cancel) {
        return false;
      }

      if (decision == _SaleStockDecision.continueSale) {
        return true;
      }

      final updated = await _showQuickRestockDialog(
        item: item,
        missingQty: missingQty,
        noteSeed: 'Reposición rápida desde venta',
      );

      if (!updated) {
        return false;
      }

      item = ref
          .read(inventoryItemsProvider)
          .where((x) => x.id == itemId)
          .firstOrNull;

      if (item == null) {
        throw StateError('No se pudo recargar el ítem de inventario.');
      }
    }

    return true;
  }

  Future<_SaleStockDecision> _showStockDecisionDialog({
    required InventoryItem item,
    required double missingQty,
    required String title,
    required String messagePrefix,
  }) async {
    final decision = await showDialog<_SaleStockDecision>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(
          '$messagePrefix\n\n'
          'Disponible: ${item.stock.toStringAsFixed(0)} ${item.unit ?? ''}\n'
          'Falta: ${missingQty.toStringAsFixed(0)} ${item.unit ?? ''}\n\n'
          '¿Qué deseas hacer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _SaleStockDecision.cancel),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(context, _SaleStockDecision.continueSale),
            child: const Text('Continuar sin reponer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _SaleStockDecision.restock),
            child: const Text('Actualizar stock'),
          ),
        ],
      ),
    );

    return decision ?? _SaleStockDecision.cancel;
  }

  Future<bool> _showQuickRestockDialog({
    required InventoryItem item,
    required double missingQty,
    required String noteSeed,
  }) async {
    final qtyC = TextEditingController(
      text: missingQty > 0 ? missingQty.toStringAsFixed(0) : '',
    );
    final noteC = TextEditingController(text: noteSeed);

    final restock = await showDialog<(double, String?)>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Actualizar stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyC,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad a agregar',
                suffixText: item.unit,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteC,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(
                qtyC.text.trim().replaceAll(',', '.'),
              );
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cantidad inválida.')),
                );
                return;
              }
              final note = noteC.text.trim();
              Navigator.pop(context, (qty, note.isEmpty ? null : note));
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (restock == null) return false;

    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }

    final ent = await ref.read(entitlementsProvider(user.uid).future);

    await ref.read(inventoryControllerProvider.notifier).adjustStock(
          itemId: item.id,
          delta: restock.$1,
          type: StockMovementType.inQty,
          note: restock.$2,
          ent: ent,
        );

    return true;
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
    final grouped = _groupInventoryQuantities(sale.lines);

    for (final entry in grouped.entries) {
      final itemId = entry.key;
      final qty = entry.value;
      InventoryItem? item = ref
          .read(inventoryItemsProvider)
          .where((x) => x.id == itemId)
          .firstOrNull;

      if (item == null) {
        throw StateError('No se encontró el ítem de inventario $itemId.');
      }

      if (!item.tracksStock) continue;

      var shouldDiscount = true;

      while (item!.stock < qty) {
        final missingQty = qty - item.stock;
        final decision = await _showStockDecisionDialog(
          item: item,
          missingQty: missingQty,
          title: 'Stock insuficiente',
          messagePrefix:
              'No hay stock suficiente para "${item.name}" al registrar la venta.',
        );

        if (decision == _SaleStockDecision.cancel) {
          throw StateError(
            'Venta cancelada por stock insuficiente para "${item.name}".',
          );
        }

        if (decision == _SaleStockDecision.continueSale) {
          shouldDiscount = false;
          break;
        }

        final updated = await _showQuickRestockDialog(
          item: item,
          missingQty: missingQty,
          noteSeed: 'Reposición rápida desde venta ${sale.numberLabel}',
        );

        if (!updated) {
          throw StateError(
            'Venta cancelada por stock insuficiente para "${item.name}".',
          );
        }

        item = ref
            .read(inventoryItemsProvider)
            .where((x) => x.id == itemId)
            .firstOrNull;

        if (item == null) {
          throw StateError('No se pudo recargar el ítem de inventario.');
        }
      }

      if (shouldDiscount) {
        await ref.read(inventoryControllerProvider.notifier).adjustStock(
              itemId: itemId,
              delta: -qty,
              type: StockMovementType.outQty,
              note: 'Venta ${sale.numberLabel}',
              ent: ent,
            );
      }
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
        documentNumber:
            _docCtrl.text.trim().isEmpty ? null : _docCtrl.text.trim(),
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<double>(0, (sum, line) => sum + line.lineTotalBob);

    return ModulePermissionGuard(
      moduleKey: 'sales',
      moduleLabel: 'Ventas',
      requireEdit: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.sale.numberLabel),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _inventoryLocked ? 'Inventario aplicado' : 'Borrador',
                style: TextStyle(
                  color: _inventoryLocked
                      ? AppColors.billing
                      : AppColors.workOrders,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _inventoryLocked
          ? null
          : FloatingActionButton.extended(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Agregar ítem'),
            ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<SaleDocumentType>(
                        initialValue: _documentType,
                        decoration: const InputDecoration(
                          labelText: 'Documento',
                        ),
                        items: SaleDocumentType.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _documentType = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _docCtrl,
                        decoration: const InputDecoration(
                          labelText: 'NIT / Documento',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre / Razón social',
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Ingresa un nombre';
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
                        ),
                        disableLengthCheck: true,
                        onChanged: (phone) {
                          _phoneE164 = _buildE164Phone(
                            countryCode: phone.countryCode,
                            nationalNumber: phone.number,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<SaleStatus>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          labelText: 'Estado',
                        ),
                        items: SaleStatus.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notas',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Detalle',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (_lines.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay ítems agregados.'),
                  ),
                )
              else
                ..._lines.map(
                  (line) => QuoteLineTile(
                    line: line,
                    onEditQty: _inventoryLocked
                        ? (_) {}
                        : (qty) => _editQty(line.lineId, qty),
                    onRemove: _inventoryLocked
                        ? null
                        : () => _removeLine(line.lineId),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        'Bs ${_fmt(total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Guardando...' : 'Guardar venta'),
        ),
      ),
      ),
    );
  }
}
