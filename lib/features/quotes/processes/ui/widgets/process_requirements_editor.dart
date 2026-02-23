import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../inventory/domain/inventory_item.dart';
import '../../../../inventory/presentation/inventory_providers.dart';
import '../../domain/process_requirement.dart';

class ProcessRequirementsEditor extends ConsumerStatefulWidget {
  const ProcessRequirementsEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<ProcessRequirement> items;
  final ValueChanged<List<ProcessRequirement>> onChanged;

  @override
  ConsumerState<ProcessRequirementsEditor> createState() =>
      _ProcessRequirementsEditorState();
}

class _ProcessRequirementsEditorState
    extends ConsumerState<ProcessRequirementsEditor> {
  InventoryItem? _picked;
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double _toQty(String s) {
    final v = s.replaceAll(',', '.').trim();
    return double.tryParse(v) ?? 1.0;
  }

  void _add() {
    final inv = _picked;
    if (inv == null) return;

    final qty = _toQty(_qtyCtrl.text);
    if (qty <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final r = ProcessRequirement(
      reqId: 'REQ-$now',
      kind: 'material', // ✅ fijo (solo inventario)
      inventoryItemId: inv.id,
      nameSnapshot: inv.name,
      unitSnapshot: (inv.unit ?? ''),
      qty: qty,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAtMs: now,
      updatedAtMs: now,
    );

    widget.onChanged([...widget.items, r]);

    setState(() {
      _picked = null;
      _qtyCtrl.text = '1';
      _noteCtrl.text = '';
    });
  }

  Future<void> _editQtyNote(BuildContext context, ProcessRequirement r) async {
    final qtyCtrl = TextEditingController(text: r.qty.toString());
    final noteCtrl = TextEditingController(text: r.note ?? '');

    final res = await showDialog<ProcessRequirement?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar requerimiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.nameSnapshot,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final q = _toQty(qtyCtrl.text);
              if (q <= 0) return;

              final now = DateTime.now().millisecondsSinceEpoch;
              Navigator.pop(
                ctx,
                r.copyWith(
                  qty: q,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  updatedAtMs: now,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (res == null) return;

    final next = widget.items.map((x) => x.reqId == r.reqId ? res : x).toList();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final invItems = ref.watch(inventoryItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requerimientos (Inventario)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),

        // Selector inventario + cantidad + nota
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _picked?.id,
                decoration: const InputDecoration(
                  labelText: 'Item de inventario',
                ),
                items: invItems
                    .map(
                      (i) => DropdownMenuItem(
                        value: i.id,
                        child: Text(
                          i.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  setState(() {
                    _picked = invItems.where((x) => x.id == id).firstOrNull;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cant.'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: 'Nota (opcional)'),
        ),
        const SizedBox(height: 10),

        // ✅ Solo un botón: añadir
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Añadir'),
          ),
        ),

        const SizedBox(height: 14),

        // Lista actual
        if (widget.items.isEmpty)
          Text(
            'Sin requerimientos todavía.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = widget.items[i];

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: scheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.nameSnapshot,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.qty} ${r.unitSnapshot}'.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          if ((r.note ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              r.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _editQtyNote(context, r),
                          icon: const Icon(Icons.edit, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => widget.onChanged(
                            widget.items
                                .where((x) => x.reqId != r.reqId)
                                .toList(),
                          ),
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
