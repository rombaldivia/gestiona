import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/presentation/inventory_by_id_provider.dart';

import '../../subscription/domain/entitlements.dart';
import '../../subscription/domain/plan_tier.dart';
import '../../subscription/presentation/entitlements_scope.dart';

import '../domain/quote.dart';
import '../domain/quote_line.dart';
import '../domain/quote_status.dart';
import '../pdf/quote_pdf.dart';
import '../presentation/quotes_controller.dart';

import 'helpers/quote_recotize_sheet.dart';
import 'widgets/quote_add_item_sheet.dart';
import 'widgets/quote_line_tile.dart';

import '../processes/ui/helpers/process_to_quote_lines.dart';
import '../../work_orders/domain/work_order.dart';
import '../../work_orders/ui/work_order_editor_page.dart';
import '../../work_orders/presentation/work_orders_controller.dart';
import '../processes/ui/widgets/pick_process_template_dialog.dart';

class QuoteEditorPage extends ConsumerStatefulWidget {
  const QuoteEditorPage({super.key, required this.quote});
  final Quote quote;

  @override
  ConsumerState<QuoteEditorPage> createState() => _QuoteEditorPageState();
}

class _QuoteEditorPageState extends ConsumerState<QuoteEditorPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _customerCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _nitCtrl;
  late final TextEditingController _billToCtrl;

  QuoteStatus _status = QuoteStatus.draft;
  final List<QuoteLine> _lines = [];
  List<QuoteLine>? _undoLinesSnapshot;
  String _phoneE164 = '';
  int?   _deliveryAtMs;

  @override
  void initState() {
    super.initState();
    _titleCtrl    = TextEditingController(text: widget.quote.title ?? '');
    _customerCtrl = TextEditingController(text: widget.quote.customerName ?? '');
    _notesCtrl    = TextEditingController(text: widget.quote.notes ?? '');
    _nitCtrl      = TextEditingController(text: widget.quote.customerNit ?? '');
    _billToCtrl   = TextEditingController(text: widget.quote.billToName ?? '');
    _status       = widget.quote.status;
    _lines.addAll(widget.quote.lines);
    _phoneE164    = widget.quote.customerPhone ?? '';
    _deliveryAtMs = widget.quote.deliveryAtMs;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    _nitCtrl.dispose();
    _billToCtrl.dispose();
    super.dispose();
  }

  void _stashUndoSnapshot() {
    _undoLinesSnapshot ??= List<QuoteLine>.from(_lines);
  }

  void _undoRecotize() {
    final snap = _undoLinesSnapshot;
    if (snap == null) return;
    setState(() {
      _lines..clear()..addAll(snap);
      _undoLinesSnapshot = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recotización revertida')),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  String _buildWhatsappText(double totalBob) {
    final b = StringBuffer();
    b.writeln('COT #${widget.quote.sequence}-${widget.quote.year}');
    b.writeln('Cliente: ${_customerCtrl.text.trim()}');
    b.writeln();
    for (final l in _lines) {
      b.writeln('• ${l.nameSnapshot}  x${l.qty.toStringAsFixed(0)}  = Bs ${l.lineTotalBob.toStringAsFixed(2)}');
    }
    b.writeln();
    b.writeln('Total: Bs ${totalBob.toStringAsFixed(2)}');
    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) {
      b.writeln();
      b.writeln('Notas: $notes');
    }
    return b.toString();
  }

  Future<void> _askMarkAsSent() async {
    if (_status == QuoteStatus.sent || _status == QuoteStatus.accepted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Marcar como enviada?'),
        content: const Text('¿Deseas cambiar el estado a "Enviada"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, marcar enviada'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _status = QuoteStatus.sent);
      final ctrl = ref.read(quotesControllerProvider.notifier);
      final q = widget.quote.copyWith(
        status:       QuoteStatus.sent,
        customerName: _customerCtrl.text.trim(),
        lines:        _lines,
      );
      await ctrl.upsert(q);
    }
  }

  Future<void> _sendWhatsapp(double total) async {
    final phone = _phoneE164.trim();
    if (phone.isEmpty || _lines.isEmpty) return;
    if (mounted) await _askMarkAsSent();
    final digits = phone.replaceAll('+', '');
    final text   = _buildWhatsappText(total);
    final uri    = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _createWorkOrder() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = widget.quote.copyWith(
      title:         _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      deliveryAtMs:  _deliveryAtMs,
      customerName:  _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
      customerPhone: _phoneE164.isEmpty ? null : _phoneE164,
      customerNit:   _nitCtrl.text.trim().isEmpty ? null : _nitCtrl.text.trim(),
      billToName:    _billToCtrl.text.trim().isEmpty ? null : _billToCtrl.text.trim(),
      lines:         _lines,
      status:        _status,
    );

    final steps = _lines.asMap().entries.map((e) {
      final idx  = e.key;
      final line = e.value;
      final qtyStr = line.qty == line.qty.roundToDouble()
          ? line.qty.toInt().toString()
          : line.qty.toStringAsFixed(2);
      return WorkOrderStep(
        id:    '${now}_$idx',
        title: line.nameSnapshot,
        qty:   line.qty,
        unit:  line.unitSnapshot ?? 'und',
        notes: 'Cantidad: $qtyStr ${line.unitSnapshot ?? 'und'}',
      );
    }).toList();

    final woCtrl    = ref.read(workOrdersControllerProvider.notifier);
    final allOrders = ref.read(workOrdersControllerProvider).value?.orders ?? [];
    final existing  = allOrders.where((o) => o.quoteId == q.id).firstOrNull;

    final WorkOrder wo;
    if (existing != null) {
      wo = existing.copyWith(
        quoteTitle:    q.title,
        deliveryAtMs:  q.deliveryAtMs,
        customerName:  q.customerName,
        customerPhone: q.customerPhone,
        steps:         steps,
        updatedAtMs:   DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      final template = woCtrl.newOrder(
        quoteId:       q.id,
        quoteSequence: q.sequence,
        customerName:  q.customerName,
        customerPhone: q.customerPhone,
      );
      wo = template.copyWith(
        quoteTitle:   q.title,
        deliveryAtMs: q.deliveryAtMs,
        steps:        steps,
      );
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkOrderEditorPage(order: wo)),
    );
  }

  Future<void> _sharePdf() async {
    if (_lines.isEmpty) return;
    final q = widget.quote.copyWith(lines: _lines);
    final Uint8List bytes = await QuotePdf.build(
      quote: q, lines: q.lines, totalBob: q.totalBob,
    );
    if (mounted) await _askMarkAsSent();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'COT_${widget.quote.sequence}-${widget.quote.year}.pdf',
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final q = widget.quote.copyWith(
        title:         _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        deliveryAtMs:  _deliveryAtMs,
        customerName:  _customerCtrl.text.trim(),
        customerPhone: _phoneE164.trim(),
        customerNit:   _nitCtrl.text.trim().isEmpty ? null : _nitCtrl.text.trim(),
        billToName:    _billToCtrl.text.trim().isEmpty ? null : _billToCtrl.text.trim(),
        notes:         _notesCtrl.text.trim(),
        status:        _status,
        lines:         _lines,
      );
      await ref.read(quotesControllerProvider.notifier).upsert(q);
      _undoLinesSnapshot = null;
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addItem() async {
    final invItems = ref.read(inventoryItemsProvider);
    final line = await showModalBottomSheet<QuoteLine?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuoteAddItemSheet(inventoryItems: invItems),
    );
    if (line != null) setState(() => _lines.add(line));
  }

  Future<void> _addProcess() async {
    final template = await showDialog(
      context: context,
      builder: (_) => const PickProcessTemplateDialog(),
    );
    if (template == null) return;
    final invById  = ref.read(inventoryByIdProvider);
    final newLines = processTemplateToQuoteLines(
      template: template, inventoryById: invById,
    );
    if (newLines.isNotEmpty) setState(() => _lines.addAll(newLines));
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final total    = widget.quote.copyWith(lines: _lines).totalBob;
    final hasPhone = _phoneE164.trim().isNotEmpty;
    final hasLines = _lines.isNotEmpty;
    final ent      = EntitlementsScope.maybeOf(context) ?? Entitlements.forTier(PlanTier.free);
    final isPro    = ent.tier == PlanTier.pro;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('COT #${widget.quote.sequence}-${widget.quote.year}'),
          actions: [
            IconButton(
              tooltip: 'Revertir recotización',
              icon: const Icon(Icons.undo),
              onPressed: (_undoLinesSnapshot == null) ? null : _undoRecotize,
            ),
            IconButton(
              tooltip: isPro ? 'Recotizar' : 'Recotizar (API solo PRO)',
              icon: const Icon(Icons.currency_exchange),
              onPressed: () async {
                await QuoteRecotizeSheet.open(
                  context: context,
                  lines: _lines,
                  onApply: (newLines) {
                    _stashUndoSnapshot();
                    setState(() => _lines..clear()..addAll(newLines));
                  },
                );
              },
            ),
            IconButton(
              tooltip: 'WhatsApp',
              icon: const Icon(Icons.chat),
              onPressed: (!hasPhone || !hasLines) ? null : () => _sendWhatsapp(total),
            ),
            IconButton(
              tooltip: 'PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: !hasLines ? null : _sharePdf,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<QuoteStatus>(
                value: _status,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(16),
                items: QuoteStatus.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.label, style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (s) {
                  if (s != null) setState(() => _status = s);
                },
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del proyecto',
                  hintText:  'Ej: Impresión catálogo Hermenca',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              _DeliveryDatePicker(
                valueMs:   _deliveryAtMs,
                onChanged: (ms) => setState(() => _deliveryAtMs = ms),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerCtrl,
                decoration: const InputDecoration(labelText: 'Cliente'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nitCtrl,
                decoration: const InputDecoration(
                  labelText:  'NIT / CI',
                  hintText:   'Ej: 1234567',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _billToCtrl,
                decoration: const InputDecoration(
                  labelText:  'Factura a nombre de',
                  hintText:   'Ej: Empresa Hermenca S.R.L.',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              IntlPhoneField(
                initialValue: _phoneE164,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                onChanged: (p) => _phoneE164 = p.completeNumber,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addItem,
                      icon:  const Icon(Icons.add),
                      label: const Text('Ítem'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _addProcess,
                      icon:  const Icon(Icons.playlist_add),
                      label: const Text('Proceso'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_lines.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Aún no hay ítems en la cotización.'),
                ),
              for (final l in _lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: QuoteLineTile(
                    line: l,
                    onRemove: () => setState(() => _lines.remove(l)),
                    onEditQty: (newQty) {
                      setState(() {
                        final idx = _lines.indexOf(l);
                        if (idx >= 0) _lines[idx] = l.copyWith(qty: newQty);
                      });
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Total',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text('Bs ${_fmt(total)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary)),
                  ],
                ),
              ),
              if (_status == QuoteStatus.accepted) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF312E81),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _createWorkOrder,
                    icon:  const Icon(Icons.engineering_outlined),
                    label: const Text('Crear Orden de Trabajo',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget: selector de fecha de entrega ──────────────────────────────────────
class _DeliveryDatePicker extends StatelessWidget {
  const _DeliveryDatePicker({required this.valueMs, required this.onChanged});

  final int?              valueMs;
  final void Function(int?) onChanged;

  String get _display {
    if (valueMs == null) return 'Fecha de entrega (opcional)';
    final d = DateTime.fromMillisecondsSinceEpoch(valueMs!);
    return 'Entrega: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = valueMs != null;
    final color   = hasDate
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon:  Icon(Icons.calendar_today_outlined, size: 18, color: color),
            label: Text(_display, style: TextStyle(color: color)),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding:   const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              side:      BorderSide(
                color: hasDate
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            onPressed: () async {
              final initial = valueMs != null
                  ? DateTime.fromMillisecondsSinceEpoch(valueMs!)
                  : DateTime.now().add(const Duration(days: 7));
              final picked = await showDatePicker(
                context:     context,
                initialDate: initial,
                firstDate:   DateTime(2020),
                lastDate:    DateTime(2035),
              );
              if (picked != null) onChanged(picked.millisecondsSinceEpoch);
            },
          ),
        ),
        if (hasDate) ...[
          const SizedBox(width: 6),
          IconButton(
            icon:    const Icon(Icons.close, size: 18),
            tooltip: 'Quitar fecha',
            onPressed: () => onChanged(null),
          ),
        ],
      ],
    );
  }
}
