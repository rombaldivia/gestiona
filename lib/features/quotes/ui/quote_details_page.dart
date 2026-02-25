import 'package:flutter/material.dart';

import '../domain/quote.dart';
import 'widgets/quote_line_tile.dart';

class QuoteDetailsPage extends StatelessWidget {
  const QuoteDetailsPage({
    super.key,
    this.quote,
    this.quoteId,
  });

  /// ✅ Recomendado: pásale el Quote ya cargado
  final Quote? quote;

  /// Fallback (por compatibilidad con navegaciones viejas)
  final String? quoteId;

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final q = quote;

    if (q == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cotización')),
        body: Center(
          child: Text(
            quoteId == null
                ? 'No se proporcionó cotización.'
                : 'QuoteDetailsPage ahora espera Quote.\n(quoteId=$quoteId)\n\nActualiza la navegación para pasar el Quote.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('COT #${q.sequence}-${q.year}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (q.lines.isEmpty)
            const Text('Sin líneas.'),
          for (final l in q.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuoteLineTile(
                line: l,
                onRemove: null,
                // ✅ requerido por el widget actual
                onEditQty: (_) {},
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text('Bs ${_fmt(q.totalBob)}', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
