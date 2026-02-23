import 'package:flutter/material.dart';

import '../../domain/quote_step.dart';

class QuoteProcessEditor extends StatelessWidget {
  const QuoteProcessEditor({
    super.key,
    required this.steps,
    required this.onChanged,
  });

  final List<QuoteProcessStep> steps;
  final ValueChanged<List<QuoteProcessStep>> onChanged;

  Future<void> _addStep(BuildContext context) async {
    final ctrl = TextEditingController();
    final title = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo paso'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej: Diagramación'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    final t = (title ?? '').trim();
    if (t.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final step = QuoteProcessStep(
      stepId: 'S-$now',
      title: t,
      status: QuoteStepStatus.todo,
      createdAtMs: now,
      updatedAtMs: now,
    );

    onChanged([...steps, step]);
  }

  void _deleteStep(String id) {
    onChanged(steps.where((s) => s.stepId != id).toList());
  }

  void _setStatus(QuoteProcessStep s, QuoteStepStatus st) {
    final now = DateTime.now().millisecondsSinceEpoch;
    onChanged(
      steps
          .map(
            (x) => x.stepId == s.stepId
                ? x.copyWith(status: st, updatedAtMs: now)
                : x,
          )
          .toList(),
    );
  }

  Future<void> _editNote(BuildContext context, QuoteProcessStep s) async {
    final c = TextEditingController(text: s.note ?? '');
    final txt = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nota: ${s.title}'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Opcional…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (txt == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    onChanged(
      steps
          .map(
            (x) => x.stepId == s.stepId
                ? x.copyWith(note: txt.isEmpty ? null : txt, updatedAtMs: now)
                : x,
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = steps.where((s) => s.status == QuoteStepStatus.done).length;
    final total = steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Progreso: $done/$total',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => _addStep(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar paso'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (steps.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt_outlined,
                  color: scheme.primary.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Agrega pasos como: Diagramación → Impresión → Corte → Entrega.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      s.status == QuoteStepStatus.done
                          ? Icons.check_circle
                          : s.status == QuoteStepStatus.blocked
                          ? Icons.block
                          : s.status == QuoteStepStatus.doing
                          ? Icons.timelapse
                          : Icons.radio_button_unchecked,
                      color: s.status == QuoteStepStatus.done
                          ? Colors.green
                          : s.status == QuoteStepStatus.blocked
                          ? Colors.red
                          : scheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if ((s.note ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              s.note!,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              DropdownButton<QuoteStepStatus>(
                                value: s.status,
                                underline: const SizedBox.shrink(),
                                items: QuoteStepStatus.values
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) _setStatus(s, v);
                                },
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: () => _editNote(context, s),
                                icon: const Icon(Icons.edit_note, size: 18),
                                label: const Text('Nota'),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteStep(s.stepId),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: scheme.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
