import 'package:flutter/material.dart';

import '../../data/process_templates_local_store.dart';
import '../../domain/process_template.dart';

class PickProcessTemplateDialog extends StatefulWidget {
  const PickProcessTemplateDialog({super.key});

  @override
  State<PickProcessTemplateDialog> createState() =>
      _PickProcessTemplateDialogState();
}

class _PickProcessTemplateDialogState extends State<PickProcessTemplateDialog> {
  final _store = ProcessTemplatesLocalStore();
  late Future<List<ProcessTemplate>> _f;

  @override
  void initState() {
    super.initState();
    _f = _store.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elegir proceso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<ProcessTemplate>>(
                  future: _f,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data ?? const <ProcessTemplate>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No tienes procesos guardados.',
                          style: TextStyle(color: scheme.outline),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = items[i];
                        return ListTile(
                          title: Text(
                            t.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${t.requirements.length} ítems',
                            style: TextStyle(color: scheme.outline),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, t),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
