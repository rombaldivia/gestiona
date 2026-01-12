import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../company/presentation/company_providers.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';
import '../presentation/inventory_providers.dart';
import '../presentation/inventory_controller.dart';
import 'inventory_item_form_page.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = EntitlementsScope.of(context);

    final companyAsync = ref.watch(companyControllerProvider);
    final invAsync = ref.watch(inventoryControllerProvider);
    final ctrl = ref.read(inventoryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: ent.cloudSync ? 'Sync' : 'Sync (Plus/Pro)',
            onPressed: ent.cloudSync
                ? () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Sincronizando inventario...')),
                    );
                    try {
                      final n = await ctrl.sync(ent: ent);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Sync OK ✅ ($n cambios)')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Sync falló: $e')),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error empresa: $e')),
        data: (company) {
          if (company.companyId == null) {
            return const Center(
              child: Text(
                'No hay empresa activa.\nCrea o selecciona una empresa primero.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return invAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error inventario: $e')),
            data: (s) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      onChanged: ctrl.setQuery,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Buscar ítem',
                        hintText: 'Nombre o SKU',
                      ),
                    ),
                  ),
                  Expanded(
                    child: s.filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Sin ítems todavía.\n\nCrea el primero con "+".',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: s.filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = s.filtered[i];
                              final isService =
                                  item.kind == InventoryItemKind.service;
                              final low = item.minStock != null &&
                                  item.stock <= item.minStock!;

                              return Card(
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _KindChip(kind: item.kind),
                                      if (item.dirty)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child:
                                              Icon(Icons.cloud_off, size: 18),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SKU: ${item.sku?.trim().isNotEmpty == true ? item.sku : '-'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        if (isService) ...[
                                          Text(
                                            item.pricingMode == 'hourly'
                                                ? 'Tarifa/hora: ${_fmtMoney(item.salePrice)}'
                                                : 'Precio: ${_fmtMoney(item.salePrice)}',
                                          ),
                                        ] else ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Precio: ${_fmtMoney(item.salePrice)}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                'Stock: ${_fmt(item.stock)} ${item.unit ?? ''}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: low
                                                      ? Colors.redAccent
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'in') {
                                        await _askAdjust(
                                          context,
                                          ctrl,
                                          ent,
                                          item,
                                          isIn: true,
                                        );
                                      } else if (v == 'out') {
                                        await _askAdjust(
                                          context,
                                          ctrl,
                                          ent,
                                          item,
                                          isIn: false,
                                        );
                                      } else if (v == 'edit') {
                                        final edited =
                                            await Navigator.push<InventoryItem>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                InventoryItemFormPage(
                                                    initial: item),
                                          ),
                                        );
                                        if (edited != null) {
                                          await ctrl.upsertItem(
                                              item: edited, ent: ent);
                                        }
                                      } else if (v == 'del') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Eliminar ítem'),
                                            content: Text(
                                                '¿Eliminar "${item.name}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context,
                                                        false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, true),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await ctrl.deleteItem(
                                              itemId: item.id, ent: ent);
                                        }
                                      }
                                    },
                                    itemBuilder: (_) {
                                      if (isService) {
                                        return const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar'),
                                          ),
                                          PopupMenuItem(
                                            value: 'del',
                                            child: Text('Eliminar'),
                                          ),
                                        ];
                                      }
                                      return const [
                                        PopupMenuItem(
                                          value: 'in',
                                          child: Text('Entrada (+)'),
                                        ),
                                        PopupMenuItem(
                                          value: 'out',
                                          child: Text('Salida (-)'),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Editar'),
                                        ),
                                        PopupMenuItem(
                                          value: 'del',
                                          child: Text('Eliminar'),
                                        ),
                                      ];
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<InventoryItem>(
            context,
            MaterialPageRoute(builder: (_) => const InventoryItemFormPage()),
          );
          if (created != null) {
            await ctrl.upsertItem(item: created, ent: ent);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Ítem'),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});

  final InventoryItemKind kind;

  @override
  Widget build(BuildContext context) {
    final text = kind.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

String _fmt(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String _fmtMoney(double? v) {
  if (v == null) return '-';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

Future<void> _askAdjust(
  BuildContext context,
  InventoryController ctrl,
  dynamic ent,
  InventoryItem item, {
  required bool isIn,
}) async {
  final qtyC = TextEditingController();
  final noteC = TextEditingController();

  final res = await showDialog<(double, String?)>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(isIn ? 'Entrada de stock' : 'Salida de stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: qtyC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: item.unit,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteC,
            decoration: const InputDecoration(labelText: 'Nota (opcional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final qty =
                double.tryParse(qtyC.text.trim().replaceAll(',', '.'));
            if (qty == null || qty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cantidad inválida.')),
              );
              return;
            }
            final note = noteC.text.trim();
            Navigator.pop(context, (qty, note.isEmpty ? null : note));
          },
          child: const Text('Aplicar'),
        )
      ],
    ),
  );

  if (res == null) return;
  final qty = res.$1;
  final note = res.$2;
  final delta = isIn ? qty : -qty;
  final type = isIn ? StockMovementType.inQty : StockMovementType.outQty;

  await ctrl.adjustStock(
    itemId: item.id,
    delta: delta,
    type: type,
    note: note,
    ent: ent,
  );
}
