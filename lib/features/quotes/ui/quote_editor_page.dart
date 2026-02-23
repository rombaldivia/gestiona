import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/presentation/inventory_providers.dart';
import '../domain/quote.dart';
import '../domain/quote_line.dart';
import '../domain/quote_status.dart';
import '../presentation/quotes_controller.dart';
import 'widgets/quote_add_item_sheet.dart';
import 'widgets/quote_line_tile.dart';

// ✅ NUEVO: picker + helper
import '../processes/ui/widgets/pick_process_template_dialog.dart';
import '../processes/ui/helpers/process_to_quote_lines.dart';
import '../processes/domain/process_template.dart';

class QuoteEditorPage extends ConsumerStatefulWidget {
  const QuoteEditorPage({super.key, required this.quote});

  final Quote quote;

  @override
  ConsumerState<QuoteEditorPage> createState() => _QuoteEditorPageState();
}

class _QuoteEditorPageState extends ConsumerState<QuoteEditorPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _customerCtrl;
  late final TextEditingController _notesCtrl;

  QuoteStatus _status = QuoteStatus.draft;
  String _phoneE164 = '';

  final List<QuoteLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(
      text: widget.quote.customerName ?? '',
    );
    _notesCtrl = TextEditingController(text: widget.quote.notes ?? '');
    _status = widget.quote.status;
    _lines.addAll(widget.quote.lines);
    _phoneE164 = widget.quote.customerPhone ?? '';
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<double?> _askQty(double initial) async {
    final ctrl = TextEditingController(text: initial.toString());
    double? out;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cantidad'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ej: 2'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.replaceAll(',', '.').trim();
              out = double.tryParse(v);
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return out;
  }

  Future<void> _addLine() async {
    final items = ref.read(inventoryItemsProvider);

    final line = await showModalBottomSheet<QuoteLine?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuoteAddItemSheet(inventoryItems: items),
    );

    if (line != null) setState(() => _lines.add(line));
  }

  // ✅ NUEVO: Traer proceso y convertirlo a items
  Future<void> _addFromProcessTemplate() async {
    final template = await showDialog<ProcessTemplate?>(
      context: context,
      builder: (_) => const PickProcessTemplateDialog(),
    );

    if (template == null) return;

    final inv = ref.read(inventoryItemsProvider);
    final invById = {for (final x in inv) x.id: x};

    final newLines = processTemplateToQuoteLines(
      template: template,
      inventoryById: invById,
    );

    if (newLines.isEmpty) return;

    setState(() => _lines.addAll(newLines));
  }

  void _removeLine(String lineId) {
    setState(() => _lines.removeWhere((l) => l.lineId == lineId));
  }

  Future<void> _editQty(QuoteLine line) async {
    final newQty = await _askQty(line.qty);
    if (newQty == null || newQty <= 0) return;
    setState(() {
      final i = _lines.indexWhere((l) => l.lineId == line.lineId);
      if (i >= 0) _lines[i] = line.copyWith(qty: newQty);
    });
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = widget.quote.copyWith(
        customerName: _customerCtrl.text.trim(),
        customerPhone: _phoneE164.trim().isEmpty ? null : _phoneE164.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        lines: _lines,
        status: _status,
        updatedAtMs: now,
      );

      await ref.read(quotesControllerProvider.notifier).upsert(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNew =
        widget.quote.lines.isEmpty && widget.quote.customerName == null;

    return Scaffold(
      appBar: AppBar(
        title: Text('COT #${widget.quote.sequence}-${widget.quote.year}'),
        actions: [
          if (!isNew)
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
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 13),
                        ),
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
              controller: _customerCtrl,
              decoration: const InputDecoration(
                labelText: 'Cliente',
                hintText: 'Ej: Juan Pérez',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Detalles…',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir ítem'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addFromProcessTemplate,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Traer proceso'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Aún no hay ítems.',
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                  for (final l in _lines)
                    QuoteLineTile(
                      line: l,
                      onRemove: () => _removeLine(l.lineId),
                      onEditQty: () => _editQty(l),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: Bs ${widget.quote.copyWith(lines: _lines).totalBob.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
