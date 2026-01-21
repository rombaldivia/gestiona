import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../company/presentation/company_providers.dart';
import '../../dollar/presentation/dollar_providers.dart';
import '../../subscription/domain/plan_tier.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';
import '../presentation/inventory_controller.dart';
import '../presentation/inventory_providers.dart';
import 'inventory_item_form_page.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = EntitlementsScope.of(context);
    final proCloud = ent.tier == PlanTier.pro && ent.cloudSync;

    final uid = FirebaseAuth.instance.currentUser?.uid;

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
                      const SnackBar(
                        content: Text('Sincronizando inventario...'),
                      ),
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
                                  item.kind == InventoryItemKind.servicio;
                              final low =
                                  item.minStock != null &&
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
                                          child: Icon(
                                            Icons.cloud_off,
                                            size: 18,
                                          ),
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
                                                'Stock: ${_fmt(item.stock.toDouble())} ${item.unit ?? ''}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: low
                                                      ? Colors.redAccent
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'restock') {
                                        // GRATIS: solo stock (reposicion / ajuste entrada)
                                        await _askRestockStockOnly(
                                          context,
                                          ctrl,
                                          ent,
                                          item,
                                        );
                                      } else if (v == 'purchase') {
                                        // PRO: stock + costo de adquisición con tasa dólar
                                        if (!proCloud || uid == null) return;
                                        await _askPurchaseStockAndCost(
                                          context: context,
                                          ref: ref,
                                          ctrl: ctrl,
                                          ent: ent,
                                          uid: uid,
                                          item: item,
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
                                                      initial: item,
                                                    ),
                                              ),
                                            );
                                        if (edited != null) {
                                          await ctrl.upsertItem(
                                            item: edited,
                                            ent: ent,
                                          );
                                        }
                                      } else if (v == 'del') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Eliminar ítem'),
                                            content: Text(
                                              '¿Eliminar "${item.name}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await ctrl.deleteItem(
                                            itemId: item.id,
                                            ent: ent,
                                          );
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

                                      // No-service: inventario normal
                                      return [
                                        const PopupMenuItem(
                                          value: 'restock',
                                          child: Text('Actualizar stock'),
                                        ),
                                        if (proCloud)
                                          const PopupMenuItem(
                                            value: 'purchase',
                                            child: Text(
                                              'Compra / reposición (PRO)',
                                            ),
                                          ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'out',
                                          child: Text('Salida (-)'),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Editar'),
                                        ),
                                        const PopupMenuItem(
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
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
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
            final qty = double.tryParse(qtyC.text.trim().replaceAll(',', '.'));
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
        ),
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

/// GRATIS: botón explícito "Actualizar stock" (equivale a entrada positiva, sin tocar costo).
Future<void> _askRestockStockOnly(
  BuildContext context,
  InventoryController ctrl,
  dynamic ent,
  InventoryItem item,
) async {
  final qtyC = TextEditingController();
  final noteC = TextEditingController();

  final res = await showDialog<(double, String?)>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Actualizar stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: qtyC,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad a agregar',
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
            final qty = double.tryParse(qtyC.text.trim().replaceAll(',', '.'));
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
        ),
      ],
    ),
  );

  if (res == null) return;
  final qty = res.$1;
  final note = res.$2;

  await ctrl.adjustStock(
    itemId: item.id,
    delta: qty,
    type: StockMovementType.inQty,
    note: note,
    ent: ent,
  );
}

enum _RateMode { savedBase, currentBinance }

enum _CostCurrency { bob, usd }

/// PRO: Compra / reposición -> stock + costo de adquisición.
/// Permite elegir:
/// - usar tasa base guardada (savedBase)
/// - o traer tasa actual (currentBinance)
Future<void> _askPurchaseStockAndCost({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryController ctrl,
  required dynamic ent,
  required String uid,
  required InventoryItem item,
}) async {
  final qtyC = TextEditingController();
  final noteC = TextEditingController();
  final costC = TextEditingController();

  var rateMode = _RateMode.savedBase;
  var currency = _CostCurrency.usd;

  double? savedBaseRate;
  double? liveRate; // binance (solo si el usuario la pide)
  bool fetchingRate = false;

  double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<double?> getSavedBaseRate() async {
    final st = await ref.read(dollarProtectionProvider(uid).future);
    return st.baseRate;
  }

  Future<double?> getLiveRate() async {
    final repo = ref.read(dollarRepositoryProvider);
    final r = await repo.fetchLastRate();
    return r;
  }

  String rateLabel() {
    final v = (rateMode == _RateMode.savedBase) ? savedBaseRate : liveRate;
    if (v == null) return '—';
    return v.toStringAsFixed(2);
  }

  double? computeCostBob() {
    final qty = parseNum(qtyC.text);
    final unitCost = parseNum(costC.text);
    if (qty == null || qty <= 0) return null;
    if (unitCost == null || unitCost <= 0) return null;

    final rate = (rateMode == _RateMode.savedBase) ? savedBaseRate : liveRate;
    if (currency == _CostCurrency.usd) {
      if (rate == null || rate <= 0) return null;
      return unitCost * rate; // costo unitario en Bs
    }
    return unitCost; // ya está en Bs
  }

  final res = await showDialog<(double qty, double costBob, String? note)>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Compra / reposición (PRO)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: qtyC,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cantidad comprada',
                    suffixText: item.unit,
                  ),
                ),
                const SizedBox(height: 10),

                // Costo unitario (PRO)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Costo unitario',
                          suffixText: currency == _CostCurrency.usd
                              ? 'USD'
                              : 'Bs',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<_CostCurrency>(
                      value: currency,
                      items: const [
                        DropdownMenuItem(
                          value: _CostCurrency.usd,
                          child: Text('USD'),
                        ),
                        DropdownMenuItem(
                          value: _CostCurrency.bob,
                          child: Text('Bs'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => currency = v);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Tasa (si costo está en USD)
                if (currency == _CostCurrency.usd) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<_RateMode>(
                          value: rateMode,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: _RateMode.savedBase,
                              child: Text('Usar mi tasa base guardada'),
                            ),
                            DropdownMenuItem(
                              value: _RateMode.currentBinance,
                              child: Text('Usar tasa actual (Binance)'),
                            ),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;

                            setState(() => rateMode = v);

                            // Lazy-load de tasas
                            if (v == _RateMode.savedBase &&
                                savedBaseRate == null) {
                              setState(() => fetchingRate = true);
                              try {
                                savedBaseRate = await getSavedBaseRate();
                              } finally {
                                setState(() => fetchingRate = false);
                              }
                            }

                            if (v == _RateMode.currentBinance &&
                                liveRate == null) {
                              setState(() => fetchingRate = true);
                              try {
                                liveRate = await getLiveRate();
                              } finally {
                                setState(() => fetchingRate = false);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (fetchingRate)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          rateLabel(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Costo se guardará en Bs. (conversión automática)',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],

                const SizedBox(height: 10),
                TextField(
                  controller: noteC,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final qty = parseNum(qtyC.text);
                  if (qty == null || qty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Cantidad inválida.')),
                    );
                    return;
                  }

                  // Costo unitario en Bs
                  if (currency == _CostCurrency.usd) {
                    // asegúrate de tener tasa cargada
                    if (rateMode == _RateMode.savedBase &&
                        savedBaseRate == null) {
                      setState(() => fetchingRate = true);
                      try {
                        savedBaseRate = await getSavedBaseRate();
                      } finally {
                        setState(() => fetchingRate = false);
                      }
                    }
                    if (rateMode == _RateMode.currentBinance &&
                        liveRate == null) {
                      setState(() => fetchingRate = true);
                      try {
                        liveRate = await getLiveRate();
                      } finally {
                        setState(() => fetchingRate = false);
                      }
                    }
                  }
                  if (!ctx.mounted) return;

                  final costBob = computeCostBob();
                  if (costBob == null || costBob <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Costo inválido o falta tasa.'),
                      ),
                    );
                    return;
                  }

                  final note = noteC.text.trim();
                  Navigator.pop(ctx, (
                    qty,
                    costBob,
                    note.isEmpty ? null : note,
                  ));
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      );
    },
  );

  if (res == null) return;

  final qty = res.$1;
  final costUnitBob = res.$2;
  final note = res.$3;

  // 1) Ajustar stock (entrada)
  await ctrl.adjustStock(
    itemId: item.id,
    delta: qty,
    type: StockMovementType.inQty,
    note: note,
    ent: ent,
  );

  // 2) Guardar costo de adquisición (unitario en Bs)
  // (simple: set directo; si luego quieres costo ponderado, lo hacemos)
  final updated = item.copyWith(
    cost: costUnitBob,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    dirty: true,
  );

  await ctrl.upsertItem(item: updated, ent: ent);
}
