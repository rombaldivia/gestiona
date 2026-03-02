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

  QuoteStatus _status = QuoteStatus.draft;
  final List<QuoteLine> _lines = [];

  // ✅ Snapshot para revertir recotización (hasta que guardes)
  List<QuoteLine>? _undoLinesSnapshot;

  String _phoneE164 = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl    = TextEditingController(text: widget.quote.title ?? '');
    _customerCtrl = TextEditingController(text: widget.quote.customerName ?? '');
    _notesCtrl = TextEditingController(text: widget.quote.notes ?? '');
    _status = widget.quote.status;
    _lines.addAll(widget.quote.lines);
    _phoneE164 = widget.quote.customerPhone ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _stashUndoSnapshot() {
    _undoLinesSnapshot ??= List<QuoteLine>.from(_lines);
  }

  void _undoRecotize() {
    final snap = _undoLinesSnapshot;
    if (snap == null) return;

    setState(() {
      _lines
        ..clear()
        ..addAll(snap);
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
      b.writeln(
        '• ${l.nameSnapshot}  x${l.qty.toStringAsFixed(0)}  = Bs ${l.lineTotalBob.toStringAsFixed(2)}',
      );
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

  Future<void> _sendWhatsapp(double total) async {
    final phone = _phoneE164.trim();
    if (phone.isEmpty || _lines.isEmpty) return;

    final digits = phone.replaceAll('+', '');
    final text = _buildWhatsappText(total);
    final uri =
        Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _createWorkOrder() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = widget.quote.copyWith(
      title:         _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      customerName:  _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
      customerPhone: _phoneE164.isEmpty ? null : _phoneE164,
      lines:         _lines,
      status:        _status,
    );

    // Cada línea de la cotización se convierte en una etapa de la OT
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

    // Usa el controller para obtener el correlativo correcto
    final woCtrl = ref.read(workOrdersControllerProvider.notifier);
    final template = woCtrl.newOrder(
      quoteId:       q.id,
      quoteSequence: q.sequence,
      customerName:  q.customerName,
      customerPhone: q.customerPhone,
    );

    final wo = template.copyWith(
      quoteTitle: q.title,
      steps:      steps,
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkOrderEditorPage(order: wo)),
    );
  }

  Future<void> _sharePdf() async {
    if (_lines.isEmpty) return;
    final q = widget.quote.copyWith(lines: _lines);

    // ✅ tu QuotePdf en este repo usa build()
    final Uint8List bytes = await QuotePdf.build(
      quote: q,
      lines: q.lines,
      totalBob: q.totalBob,
    );

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
        title:        _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        customerName: _customerCtrl.text.trim(),
        customerPhone: _phoneE164.trim(),
        notes: _notesCtrl.text.trim(),
        status: _status,
        lines: _lines,
      );
      await ref.read(quotesControllerProvider.notifier).upsert(q);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización guardada')),
      );

      // ✅ después de guardar, ya no tiene sentido undo
      _undoLinesSnapshot = null;
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

    if (line != null) {
      setState(() => _lines.add(line));
    }
  }

  Future<void> _addProcess() async {
    final template = await showDialog(
      context: context,
      builder: (_) => const PickProcessTemplateDialog(),
    );
    if (template == null) return;

    final invById = ref.read(inventoryByIdProvider);
    final newLines = processTemplateToQuoteLines(
      template: template,
      inventoryById: invById,
    );

    if (newLines.isNotEmpty) {
      setState(() => _lines.addAll(newLines));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.quote.copyWith(lines: _lines).totalBob;

    final hasPhone = _phoneE164.trim().isNotEmpty;
    final hasLines = _lines.isNotEmpty;

    final ent =
        EntitlementsScope.maybeOf(context) ?? Entitlements.forTier(PlanTier.free);
    final isPro = ent.tier == PlanTier.pro;

    return Scaffold(
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
                  setState(() {
                    _lines
                      ..clear()
                      ..addAll(newLines);
                  });
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
              items: QuoteStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: (s) {
                if (s != null) setState(() => _status = s);
              },
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
          const SizedBox(width: 8),
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
                hintText: 'Ej: Impresión catálogo Hermenca',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerCtrl,
              decoration: const InputDecoration(labelText: 'Cliente'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
                    icon: const Icon(Icons.add),
                    label: const Text('Ítem'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _addProcess,
                    icon: const Icon(Icons.playlist_add),
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
                    child: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    'Bs ${_fmt(total)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Botón Crear OT solo si está Aceptada ──────────────────────
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
                  icon: const Icon(Icons.engineering_outlined),
                  label: const Text('Crear Orden de Trabajo',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
