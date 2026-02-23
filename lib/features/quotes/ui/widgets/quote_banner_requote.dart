import 'package:flutter/material.dart';

class QuoteBannerRequote extends StatelessWidget {
  const QuoteBannerRequote({
    super.key,
    required this.diffText,
    required this.isPro,
    required this.onRequote,
  });

  final String diffText;
  final bool isPro;
  final VoidCallback onRequote;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cambios detectados: $diffText\n¿Deseas re-cotizar con inventario actual?',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isPro ? onRequote : null,
              child: Text(isPro ? 'Re-cotizar' : 'PRO'),
            ),
          ],
        ),
      ),
    );
  }
}
