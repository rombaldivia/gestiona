import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../domain/quote_line.dart';

typedef IsProFn = bool Function();
typedef LinesGetter = List<QuoteLine> Function();
typedef LinesSetter = void Function(List<QuoteLine> next);

class QuoteRecotizeSheet {
  QuoteRecotizeSheet._();

  static const _binanceUrl = 'https://bo.dolarapi.com/v1/dolares/binance';

  static void open({
    required BuildContext context,
    required IsProFn isPro,
    required LinesGetter getLines,
    required LinesSetter setLines,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Recotizar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Recalcula toda la cotización rápidamente.'),
              const SizedBox(height: 16),

              // FREE
              ListTile(
                leading: const Icon(Icons.percent),
                title: const Text('Ajustar por porcentaje'),
                subtitle: const Text('Ej: +5% / -3% para todos los ítems'),
                onTap: () async {
                  Navigator.pop(context);
                  final pct = await _askPercent(context);
                  if (!context.mounted) return;
                  if (pct == null) return;
                  _applyPercent(
                    context: context,
                    pct: pct,
                    getLines: getLines,
                    setLines: setLines,
                  );
                },
              ),

              // PRO (API)
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('Recotizar por USD (Binance API) • PRO'),
                subtitle: const Text('Usa bo.dolarapi.com y actualiza snapshots'),
                onTap: () async {
                  Navigator.pop(context);

                  if (!isPro()) {
                    _showProDialog(context, 'Recotizar por USD');
                    return;
                  }

                  final r = await _fetchBinanceRate();
                  if (!context.mounted) return;

                  if (r == null) {
                    // Fallback: manual
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No se pudo obtener la tasa Binance. Ingresa manualmente.')),
                    );
                    final manual = await _askUsdRateManual(context);
                    if (!context.mounted) return;
                    if (manual == null) return;

                    _applyUsdRate(
                      context: context,
                      newRate: manual,
                      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
                      source: 'manual',
                      getLines: getLines,
                      setLines: setLines,
                    );
                    return;
                  }

                  // Confirmación rápida (opcional)
                  final ok = await _confirmBinance(context, r.rate, r.updatedAtIso);
                  if (!context.mounted) return;
                  if (!ok) return;

                  final updatedAtMs = DateTime.tryParse(r.updatedAtIso)?.millisecondsSinceEpoch
                      ?? DateTime.now().millisecondsSinceEpoch;

                  _applyUsdRate(
                    context: context,
                    newRate: r.rate,
                    updatedAtMs: updatedAtMs,
                    source: 'binance',
                    getLines: getLines,
                    setLines: setLines,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<double?> _askPercent(BuildContext context) async {
    final ctrl = TextEditingController(text: '5');
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajuste %'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Porcentaje (ej: 5 o -3)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  static Future<double?> _askUsdRateManual(BuildContext context) async {
    final ctrl = TextEditingController(text: '6.96');
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tasa USD manual'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Bs por 1 USD'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  static void _applyPercent({
    required BuildContext context,
    required double pct,
    required LinesGetter getLines,
    required LinesSetter setLines,
  }) {
    final factor = 1.0 + (pct / 100.0);
    final lines = getLines();

    final next = lines
        .map((l) => l.copyWith(unitPriceBobSnapshot: l.unitPriceBobSnapshot * factor))
        .toList(growable: false);

    setLines(next);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recotizado ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%')),
    );
  }

  static void _applyUsdRate({
    required BuildContext context,
    required double newRate,
    required int updatedAtMs,
    required String source,
    required LinesGetter getLines,
    required LinesSetter setLines,
  }) {
    final lines = getLines();

    int updated = 0;
    int skipped = 0;

    final next = lines.map((l) {
      final oldRate = l.usdRateSnapshot;

      // Si no hay tasa previa, no podemos hacer ratio; dejamos snapshot para futuras recotizaciones.
      if (oldRate == null || oldRate == 0) {
        skipped++;
        return l.copyWith(
          usdRateSnapshot: newRate,
          usdRateSourceSnapshot: source,
          usdRateUpdatedAtMsSnapshot: updatedAtMs,
        );
      }

      final newBob = l.unitPriceBobSnapshot * (newRate / oldRate);
      updated++;

      return l.copyWith(
        unitPriceBobSnapshot: newBob,
        usdRateSnapshot: newRate,
        usdRateSourceSnapshot: source,
        usdRateUpdatedAtMsSnapshot: updatedAtMs,
      );
    }).toList(growable: false);

    setLines(next);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recotizado USD ($source): $newRate • $updated actualizados • $skipped sin tasa previa'),
      ),
    );
  }

  static Future<_BinanceRate?> _fetchBinanceRate() async {
    try {
      final uri = Uri.parse(_binanceUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final m = jsonDecode(res.body) as Map<String, dynamic>;

      // Ej: { ..., "venta": 9.22, "fechaActualizacion": "2026-01-28T19:01:23.268Z" }
      final venta = m['venta'];
      final fecha = m['fechaActualizacion']?.toString();

      final rate = (venta is num) ? venta.toDouble() : double.tryParse(venta?.toString() ?? '');
      if (rate == null || rate <= 0) return null;
      if (fecha == null || fecha.isEmpty) return null;

      return _BinanceRate(rate: rate, updatedAtIso: fecha);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _confirmBinance(BuildContext context, double rate, String iso) async {
    return (await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar tasa Binance'),
        content: Text('Tasa: $rate Bs/USD\nActualización: $iso'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aplicar')),
        ],
      ),
    )) ??
        false;
  }

  static void _showProDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Función PRO'),
        content: Text('$feature es una función PRO.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
        ],
      ),
    );
  }
}

class _BinanceRate {
  final double rate;
  final String updatedAtIso;
  const _BinanceRate({required this.rate, required this.updatedAtIso});
}
