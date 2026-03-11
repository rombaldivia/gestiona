import 'package:flutter/material.dart';

import '../../domain/quote_line.dart';

class QuoteLineTile extends StatelessWidget {
  const QuoteLineTile({
    super.key,
    required this.line,
    required this.onRemove,
    required this.onEditQty,
  });

  final QuoteLine line;
  final VoidCallback? onRemove;
  final ValueChanged<double> onEditQty;

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.nameSnapshot,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'x${line.qty.toStringAsFixed(0)}  •  Bs ${_fmt(line.unitPriceBobSnapshot)} c/u',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if ((line.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    line.note!.trim(),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                'Bs ${_fmt(line.lineTotalBob)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Menos',
                    onPressed: () => onEditQty((line.qty - 1).clamp(1, 9999)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Más',
                    onPressed: () => onEditQty((line.qty + 1).clamp(1, 9999)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
