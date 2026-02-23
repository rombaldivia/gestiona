import 'package:flutter/material.dart';

import '../../../domain/quote_step.dart';

class ProcessStepsEditor extends StatefulWidget {
  const ProcessStepsEditor({
    super.key,
    required this.steps,
    required this.onChanged,
  });

  final List<QuoteProcessStep> steps;
  final ValueChanged<List<QuoteProcessStep>> onChanged;

  @override
  State<ProcessStepsEditor> createState() => _ProcessStepsEditorState();
}

class _ProcessStepsEditorState extends State<ProcessStepsEditor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final s = QuoteProcessStep(
      stepId: 'STEP-$now',
      title: title,
      status: QuoteStepStatus.todo, // fijo
      note: null,
      createdAtMs: now,
      updatedAtMs: now,
    );

    widget.onChanged([...widget.steps, s]);
    setState(() => _ctrl.text = '');
  }

  void _remove(String id) {
    widget.onChanged(widget.steps.where((x) => x.stepId != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_outlined, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Pasos (plantilla)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  labelText: 'Nuevo paso',
                  hintText: 'Ej: Diseño, Impresión, Corte, Entrega…',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.steps.isEmpty)
          Text(
            'Aún no hay pasos.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          ...widget.steps.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: () => _remove(s.stepId),
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
