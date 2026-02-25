import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../subscription/domain/entitlements.dart';
import '../../../subscription/domain/plan_tier.dart';
import '../../../subscription/presentation/entitlements_scope.dart';

import '../../domain/quote_line.dart';

enum _Mode { binanceApi, margin }

class QuoteRecotizeSheet extends StatefulWidget {
  const QuoteRecotizeSheet({
    super.key,
    required this.lines,
    required this.onApply,
  });

  final List<QuoteLine> lines;
  final ValueChanged<List<QuoteLine>> onApply;

  static Future<void> open({
    required BuildContext context,
    required List<QuoteLine> lines,
    required ValueChanged<List<QuoteLine>> onApply,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuoteRecotizeSheet(lines: lines, onApply: onApply),
    );
  }

  @override
  State<QuoteRecotizeSheet> createState() => _QuoteRecotizeSheetState();
}

class _QuoteRecotizeSheetState extends State<QuoteRecotizeSheet> {
  final _rateCtrl = TextEditingController();
  final _marginCtrl = TextEditingController(text: '0');

  _Mode _mode = _Mode.margin;
  bool _loading = false;

  bool get _isPro {
    final ent =
        EntitlementsScope.maybeOf(context) ?? Entitlements.forTier(PlanTier.free);
    return ent.tier == PlanTier.pro;
  }

  double _parseDouble(String s, {double fallback = 0}) {
    final t = s.replaceAll(',', '.').trim();
    final v = double.tryParse(t);
    return v ?? fallback;
  }

  Future<void> _fetchBinanceRate() async {
    if (!_isPro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dólar API (Binance) es solo PRO')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('https://bo.dolarapi.com/v1/dolares/binance');
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final data = jsonDecode(res.body);
      final ventaRaw =
          (data is Map<String, dynamic>) ? data['venta'] : null;

      final venta = ventaRaw is num
          ? ventaRaw.toDouble()
          : _parseDouble(ventaRaw?.toString() ?? '', fallback: 0);

      if (venta <= 0) {
        throw Exception('Respuesta inválida (venta=$ventaRaw)');
      }

      _rateCtrl.text = venta.toStringAsFixed(2);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Binance: Bs ${venta.toStringAsFixed(2)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo traer Binance: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply() {
    final marginPct = _parseDouble(_marginCtrl.text, fallback: 0);

    // ✅ MODO MARGEN: FREE permitido, no necesita tasa USD
    if (_mode == _Mode.margin) {
      if (marginPct == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Margen 0%: no hay cambios')),
        );
        Navigator.of(context).pop();
        return;
      }

      final factor = 1 + (marginPct / 100.0);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final newLines = widget.lines.map((l) {
        return l.copyWith(
          unitPriceBobSnapshot: l.unitPriceBobSnapshot * factor,
          // opcional: si quieres “marcar” que se recotizó por margen
          usdRateSnapshot: l.usdRateSnapshot,
          usdRateSourceSnapshot: l.usdRateSourceSnapshot ?? 'margin',
          usdRateUpdatedAtMsSnapshot: nowMs,
        );
      }).toList();

      widget.onApply(newLines);
      Navigator.of(context).pop();
      return;
    }

    // ✅ MODO API: SOLO PRO
    if (!_isPro) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dólar API (Binance) es solo PRO')),
      );
      return;
    }

    final rate = _parseDouble(_rateCtrl.text, fallback: 0);
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una tasa USD válida')),
      );
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final newLines = widget.lines.map((l) {
      final oldRate = l.usdRateSnapshot;

      // ✅ CLAVE: si el ítem ya tenía usdRateSnapshot, mantenemos el “USD implícito”
      // USD implícito = priceBob / oldRate  => newBob = usd * newRate
      if (oldRate != null && oldRate > 0) {
        final usdImplicit = l.unitPriceBobSnapshot / oldRate;
        final newBob = usdImplicit * rate;
        return l.copyWith(
          unitPriceBobSnapshot: newBob,
          usdRateSnapshot: rate,
          usdRateSourceSnapshot: 'binance',
          usdRateUpdatedAtMsSnapshot: nowMs,
        );
      }

      // Si no tenía oldRate, solo guardamos snapshot (no inventamos USD)
      return l.copyWith(
        usdRateSnapshot: rate,
        usdRateSourceSnapshot: 'binance',
        usdRateUpdatedAtMsSnapshot: nowMs,
      );
    }).toList();

    widget.onApply(newLines);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    final isApi = _mode == _Mode.binanceApi;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recotizar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.margin, label: Text('Margen %')),
                  ButtonSegment(value: _Mode.binanceApi, label: Text('API')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ SOLO si es API, mostramos tasa + botón binance
          if (isApi)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tasa USD (Bs por \$1)',
                      hintText: 'Ej: 9.03',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _loading ? null : _fetchBinanceRate,
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download),
                  label: const Text('Binance'),
                ),
              ],
            ),

          if (isApi) const SizedBox(height: 12),

          // ✅ Margen siempre visible para FREE/PRO
          if (!isApi)
            TextField(
              controller: _marginCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Margen (%)',
                hintText: 'Ej: 5',
              ),
            ),

          const SizedBox(height: 16),

          // ✅ Mensajito claro
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isApi
                  ? (_isPro
                      ? 'API: recalcula Bs manteniendo USD implícito (si había snapshot).'
                      : 'API disponible solo en PRO. Cambia a Margen %.')
                  : 'Margen: ajusta precios Bs por porcentaje (FREE y PRO).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _apply,
              child: const Text('Aplicar recotización'),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
