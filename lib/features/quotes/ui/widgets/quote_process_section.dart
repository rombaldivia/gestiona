import 'package:flutter/material.dart';

import '../../domain/quote_step.dart';
import 'quote_process_editor.dart';

class QuoteProcessSection extends StatelessWidget {
  const QuoteProcessSection({
    super.key,
    required this.steps,
    required this.onChanged,
  });

  final List<QuoteProcessStep> steps;
  final ValueChanged<List<QuoteProcessStep>> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = steps.where((s) => s.status == QuoteStepStatus.done).length;
    final total = steps.length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(Icons.account_tree_outlined, color: scheme.primary),
        title: const Text(
          'Procesos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          total == 0
              ? 'Define el flujo de trabajo para esta cotización'
              : 'Progreso: $done/$total',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        children: [QuoteProcessEditor(steps: steps, onChanged: onChanged)],
      ),
    );
  }
}
