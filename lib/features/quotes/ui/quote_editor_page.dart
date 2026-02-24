import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'helpers/quote_recotize_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../inventory/presentation/inventory_providers.dart';
import '../domain/quote.dart';
import '../domain/quote_line.dart';
import '../domain/quote_status.dart';
import '../pdf/quote_pdf.dart';
import '../presentation/quotes_controller.dart';
import 'widgets/quote_add_item_sheet.dart';
import 'widgets/quote_line_tile.dart';

import '../processes/domain/process_template.dart';
import '../processes/ui/helpers/process_to_quote_lines.dart';
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

  late final TextEditingController _customerCtrl;
  late final TextEditingController _notesCtrl;

  QuoteStatus _status = QuoteStatus.draft;
  final List<QuoteLine> _lines = [];

  String _phoneE164 = '';

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(text: widget.quote.customerName ?? '');
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

  Quote _buildUpdatedQuote() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return widget.quote.copyWith(
      customerName: _customerCtrl.text.trim(),
      customerPhone: _phoneE164.trim().isEmpty ? null : _phoneE164.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      lines: _lines,
      status: _status,
      updatedAtMs: now,
    );
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await ref.read(quotesControllerProvider.notifier).upsert(_buildUpdatedQuote());
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // WhatsApp rápido (como gestionaconwhatsapp)
  Future<void> _sendWhatsAppText() async {
    if (_phoneE164.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega número WhatsApp')),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 1 ítem')),
      );
      return;
    }

    await ref.read(quotesControllerProvider.notifier).upsert(_buildUpdatedQuote());
    final q = _buildUpdatedQuote();

    final buffer = StringBuffer();
    buffer.writeln('*Cotización COT #${q.sequence}-${q.year}*');
    if ((q.customerName ?? '').trim().isNotEmpty) {
      buffer.writeln('Cliente: ${q.customerName!.trim()}');
    }
    buffer.writeln('');

    for (final l in q.lines) {
      buffer.writeln('• ${l.nameSnapshot} x${_fmt(l.qty)} = Bs ${_fmt(l.lineTotalBob)}');
    }

    buffer.writeln('');
    buffer.writeln('*Total: Bs ${_fmt(q.totalBob)}*');

    final number = _phoneE164.replaceAll(RegExp(r'[^\d]'), ''); // sin +
    final encoded = Uri.encodeComponent(buffer.toString());
    final uri = Uri.parse('whatsapp://send?phone=$number&text=$encoded');

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PDF share (para adjuntar PDF)
  Future<Uint8List> _buildPdfBytes() async {
    final q = _buildUpdatedQuote();
    final bytes = await QuotePdf.build(
      quote: q,
      lines: q.lines,
      totalBob: q.totalBob,
    );
    return Uint8List.fromList(bytes);
  }

  Future<void> _sharePdf() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 1 ítem para generar PDF')),
      );
      return;
    }

    await ref.read(quotesControllerProvider.notifier).upsert(_buildUpdatedQuote());

    final bytes = await _buildPdfBytes();
    final filename = 'COT_${widget.quote.sequence}-${widget.quote.year}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Añadir ítem / proceso
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

    return Scaffold(
      appBar: AppBar(
        title: Text('COT #${widget.quote.sequence}-${widget.quote.year}'),
        actions: [
          IconButton(
            tooltip: 'Recotizar',
            icon: const Icon(Icons.currency_exchange),
            onPressed: () {
              QuoteRecotizeSheet.open(
                context: context,
                isPro: () => true,
                getLines: () => List.of(_lines),
                setLines: (next) => setState(() {
                  _lines
                    ..clear()
                    ..addAll(next);
                }),
              );
            },
          ),
          
          // Estado
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
              decoration: const InputDecoration(labelText: 'Cliente'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),

            IntlPhoneField(
              initialCountryCode: 'BO',
              initialValue: _phoneE164,
              decoration: const InputDecoration(labelText: 'WhatsApp'),
              onChanged: (phone) {
                _phoneE164 = phone.completeNumber;
              },
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // ✅ BOTONES QUE FALTABAN
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

            const SizedBox(height: 12),

            // Envíos (mantiene tema de gestiona)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasLines ? _sharePdf : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Enviar PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (hasPhone && hasLines) ? _sendWhatsAppText : null,
                    icon: const Icon(Icons.send),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                      child: Text('Aún no hay ítems.', style: TextStyle(color: scheme.outline)),
                    ),
                  for (final l in _lines)
                    QuoteLineTile(
                      line: l,
                      onRemove: () => setState(() => _lines.remove(l)),
                      onEditQty: () {},
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: Bs ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}
