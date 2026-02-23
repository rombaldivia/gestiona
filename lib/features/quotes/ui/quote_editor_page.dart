import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/whatsapp.dart';
import '../domain/quote.dart';
import '../domain/quote_line.dart';
import '../presentation/quotes_controller.dart';
import 'widgets/quote_add_item_sheet.dart';
import 'widgets/quote_line_tile.dart';
import '../pdf/quote_pdf.dart';

import '../../dollar/presentation/dollar_providers.dart';
import '../../inventory/presentation/inventory_providers.dart';

class QuoteEditorPage extends ConsumerStatefulWidget {
  const QuoteEditorPage({super.key, required this.quote});
  final Quote quote;

  @override
  ConsumerState<QuoteEditorPage> createState() => _QuoteEditorPageState();
}

class _QuoteEditorPageState extends ConsumerState<QuoteEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerCtrl;
  late final TextEditingController _notesCtrl;

  late List<QuoteLine> _lines;
  late String _phoneE164;

  bool _saving = false;
  bool _recotizing = false;
  bool _sendingPdf = false;

  bool get _hasUsdLines => _lines.any((l) => (l.usdRateSnapshot ?? 0) > 0);
  bool get _hasLines => _lines.isNotEmpty;

  double get _total => _lines.fold(0.0, (sum, l) => sum + l.lineTotalBob);

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(text: widget.quote.customerName ?? '');
    _notesCtrl = TextEditingController(text: widget.quote.notes ?? '');
    _phoneE164 = widget.quote.customerPhone ?? '';
    _lines = List<QuoteLine>.from(widget.quote.lines);
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final invState = ref.read(inventoryControllerProvider);
    final items = invState.asData?.value.items ?? const [];
    if (!mounted) return;

    final line = await showModalBottomSheet<QuoteLine>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuoteAddItemSheet(inventoryItems: items),
    );

    if (line != null) setState(() => _lines.add(line));
  }

  void _removeLine(String lineId) {
    setState(() => _lines.removeWhere((l) => l.lineId == lineId));
  }

  Future<void> _editQty(QuoteLine line) async {
    final c = TextEditingController(
      text: line.qty == line.qty.roundToDouble()
          ? line.qty.toStringAsFixed(0)
          : line.qty.toStringAsFixed(2),
    );
    final newQty = await showDialog<double?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar cantidad'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
              Navigator.pop(context, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (newQty == null || newQty <= 0) return;

    setState(() {
      final i = _lines.indexWhere((l) => l.lineId == line.lineId);
      if (i >= 0) _lines[i] = line.copyWith(qty: newQty);
    });
  }

  /// Regla: si USD actual sube vs snapshot => sube precio Bs SOLO en esta cotización.
  Future<void> _recotizarUsdSoloSiSubio() async {
    if (_recotizing) return;
    if (!_hasUsdLines) return;

    setState(() => _recotizing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(dollarRepositoryProvider);
      final usdNow = await repo.fetchLastRate();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      int touched = 0;

      final updated = _lines.map((l) {
        final usdOld = l.usdRateSnapshot;
        if (usdOld == null || usdOld <= 0) return l;
        if (usdNow <= usdOld) return l;

        final factor = usdNow / usdOld;
        touched++;

        return l.copyWith(
          unitPriceBobSnapshot: l.unitPriceBobSnapshot * factor,
          usdRateSnapshot: usdNow,
          usdRateSourceSnapshot: 'dolarapibolivia',
          usdRateUpdatedAtMsSnapshot: nowMs,
        );
      }).toList();

      setState(() => _lines = updated);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            touched == 0
                ? 'Recotización: el USD no subió (no se cambió nada).'
                : 'Recotización aplicada a $touched línea(s). USD: ${usdNow.toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo recotizar USD: $e')),
      );
    } finally {
      if (mounted) setState(() => _recotizing = false);
    }
  }

  String _buildWhatsAppMessage() {
    final seq = widget.quote.sequence;
    final year = widget.quote.year;
    final customer = _customerCtrl.text.trim().isEmpty
        ? '(Sin nombre)'
        : _customerCtrl.text.trim();

    final sb = StringBuffer();
    sb.writeln('🧾 COTIZACIÓN #$seq-$year');
    sb.writeln('Cliente: $customer');
    sb.writeln('');

    for (final l in _lines) {
      final qtyStr = (l.qty == l.qty.roundToDouble())
          ? l.qty.toStringAsFixed(0)
          : l.qty.toStringAsFixed(2);

      final sku = (l.skuSnapshot ?? '').trim().isEmpty ? '' : ' • SKU ${l.skuSnapshot}';

      sb.writeln('• ${l.nameSnapshot}$sku');
      sb.writeln(
        '  $qtyStr x Bs ${l.unitPriceBobSnapshot.toStringAsFixed(2)} = Bs ${l.lineTotalBob.toStringAsFixed(2)}',
      );
    }

    sb.writeln('');
    sb.writeln('TOTAL: Bs ${_total.toStringAsFixed(2)}');

    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) {
      sb.writeln('');
      sb.writeln('Notas: $notes');
    }

    sb.writeln('');
    sb.writeln('Gracias por su preferencia.');

    return sb.toString();
  }

  Future<void> _sendWhatsAppQuick() async {
    if (!_hasLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 1 ítem antes de enviar.')),
      );
      return;
    }

    final msg = _buildWhatsAppMessage();
    final digits = waSanitizePhone(_phoneE164);
    final uri = waMeUri(message: msg, phoneDigits: digits);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
      );
    }
  }

  Future<void> _sendPdfShare() async {
    if (_sendingPdf) return;
    if (!_hasLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 1 ítem para generar el PDF.')),
      );
      return;
    }

    setState(() => _sendingPdf = true);
    try {
      final bytes = await _buildQuotePdfBytes();
      final filename = 'cotizacion-${widget.quote.sequence}-${widget.quote.year}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar/compartir el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingPdf = false);
    }
  }

   Future<Uint8List> _buildQuotePdfBytes() async {
    final q = widget.quote.copyWith(
      customerName: _customerCtrl.text.trim(),
      customerPhone: _phoneE164.trim().isEmpty ? null : _phoneE164.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      lines: _lines,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final bytes = await QuotePdf.build(
      quote: q,
      lines: _lines,
      totalBob: _total,
    );
    return bytes;
  }

  void _openSendSheet() {
    if (!_hasLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos 1 ítem antes de enviar.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enviar cotización',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Enviar rápido (WhatsApp)'),
                subtitle: const Text('Texto listo y profesional'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _sendWhatsAppQuick();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Enviar como PDF'),
                subtitle: Text(_sendingPdf ? 'Generando…' : 'Compartir PDF por WhatsApp'),
                onTap: _sendingPdf
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _sendPdfShare();
                      },
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
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

    return Scaffold(
      appBar: AppBar(
        title: Text('COT #${widget.quote.sequence}-${widget.quote.year}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
          children: [
            const _SectionHeader(icon: Icons.person_outline, title: 'Cliente'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _customerCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre / Razón social *',
                hintText: 'Ej: Ferretería López',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            IntlPhoneField(
              initialCountryCode: 'BO',
              initialValue: _phoneE164.replaceFirst('+591', ''),
              decoration: const InputDecoration(labelText: 'WhatsApp / Teléfono'),
              onChanged: (p) => _phoneE164 = p.completeNumber,
              disableLengthCheck: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const _SectionHeader(icon: Icons.inventory_2_outlined, title: 'Ítems'),
                const Spacer(),
                if (_hasUsdLines) ...[
                  FilledButton.tonalIcon(
                    onPressed: _recotizing ? null : _recotizarUsdSoloSiSubio,
                    icon: _recotizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.currency_exchange, size: 18),
                    label: const Text('Recotizar USD'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar ítem'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_lines.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: const Text(
                  'Toca "Agregar ítem" para añadir productos del inventario.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: QuoteLineTile(
                    line: line,
                    onEditQty: () => _editQty(line),
                    onRemove: () => _removeLine(line.lineId),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            const _SectionHeader(icon: Icons.notes_outlined, title: 'Notas (opcional)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Condiciones de pago, tiempo de entrega…',
              ),
            ),
          ],
        ),
      ),

      // ✅ BOTÓN GRANDE “ENVIAR” ABAJO
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Text(
                      'Bs ${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_saving || !_hasLines) ? null : _openSendSheet,
                  icon: const Icon(Icons.send),
                  label: const Text('ENVIAR'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
