import 'package:flutter/material.dart';

import '../../domain/quote_line.dart';

class QuoteLineTile extends StatelessWidget {
  const QuoteLineTile({
    super.key,
    required this.line,
    required this.onEditQty,
    required this.onRemove,
  });

  final QuoteLine line;
  final VoidCallback? onEditQty;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasUsd = (line.usdRateSnapshot ?? 0) > 0;

    return Card(
      elevation: 0,
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                line.nameSnapshot,
                style: const TextStyle(fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasUsd)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
                child: const Text(
                  'USD🔒',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${line.qty.toStringAsFixed(2)} x Bs ${line.unitPriceBobSnapshot.toStringAsFixed(2)}'
          '${line.skuSnapshot == null ? '' : ' • SKU ${line.skuSnapshot}'}',
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bs ${line.lineTotalBob.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEditQty != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEditQty,
                  ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onRemove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
