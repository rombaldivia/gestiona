import 'package:flutter/material.dart';

import '../data/process_templates_local_store.dart';
import '../domain/process_requirement.dart';
import '../domain/process_template.dart';
import 'widgets/process_requirements_editor.dart';

class ProcessesPage extends StatefulWidget {
  const ProcessesPage({super.key});

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  final ProcessTemplatesLocalStore _store = ProcessTemplatesLocalStore();

  bool _loading = true;
  List<ProcessTemplate> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final items = await _store.loadAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<String?> _askName() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proceso'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Nombre (ej: Banner)'),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    return res?.trim().isEmpty == true ? null : res?.trim();
  }

  Future<void> _create() async {
    final name = await _askName();
    if (name == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final t = ProcessTemplate(
      id: 'PT-$now',
      name: name,
      steps: const [], // ✅ requerido por tu modelo, pero NO lo editamos
      requirements: const <ProcessRequirement>[],
      createdAtMs: now,
      updatedAtMs: now,
    );

    await _store.upsert(t);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _delete(ProcessTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proceso'),
        content: Text('¿Eliminar "${t.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _store.deleteById(t.id);
    if (!mounted) return;
    await _reload();
  }

  Future<void> _rename(ProcessTemplate t) async {
    final ctrl = TextEditingController(text: t.name);
    final res = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar proceso'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final name = res?.trim();
    if (name == null || name.isEmpty || name == t.name) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final next = t.copyWith(name: name, updatedAtMs: now);
    await _store.upsert(next);

    if (!mounted) return;
    await _reload();
  }

  Future<void> _edit(ProcessTemplate t) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;

        // ✅ copia mutable local
        var local = t;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> persist(List<ProcessRequirement> reqs) async {
              final now = DateTime.now().millisecondsSinceEpoch;

              // ✅ 1) actualiza local
              local = local.copyWith(requirements: reqs, updatedAtMs: now);

              // ✅ 2) REBUILD del sheet para que el editor vea items nuevos al instante
              setModalState(() {});

              // ✅ 3) guarda inmediato
              await _store.upsert(local);

              // ✅ 4) refresca lista padre sin re-entrar a la pantalla
              if (mounted) {
                setState(() {
                  _items = _items
                      .map((x) => x.id == local.id ? local : x)
                      .toList(growable: false);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          local.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'rename') {
                            Navigator.pop(ctx);
                            await _rename(t);
                          }
                          if (v == 'delete') {
                            Navigator.pop(ctx);
                            await _delete(t);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Renombrar'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ProcessRequirementsEditor(
                      // ✅ CLAVE: siempre le pasamos lo último
                      items: local.requirements,
                      // ✅ cada cambio refresca al instante
                      onChanged: (reqs) async => persist(reqs),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Los cambios se guardan automáticamente.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Procesos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Crea tu primer Proceso (ej: Banner).\nLuego añade requerimientos desde Inventario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = _items[i];
                final reqCount = t.requirements.length;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _edit(t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.account_tree_outlined,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$reqCount requerimientos (inventario)',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
