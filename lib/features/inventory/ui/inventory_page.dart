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

    // ✅ PRO real (para features locales como SKU + margen)
    final isPro = ent.tier == PlanTier.pro;

    // ✅ PRO + CloudSync (para features que realmente dependan de cloud/dólar/sync)
    final proCloud = isPro && ent.cloudSync;

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
                                  onTap: () async {
                                    final edited = await Navigator.push<InventoryItem>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InventoryItemFormPage(
                                          initial: item,
                                          proCloud: isPro,
                                        ),
                                      ),
                                    );
                                    if (edited != null) {
                                      await ctrl.upsertItem(item: edited, ent: ent);
                                    }
                                  },
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
                                        await _askRestockStockOnly(
                                          context,
                                          ctrl,
                                          ent,
                                          item,
                                        );
                                      } else if (v == 'purchase') {
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
                                                      proCloud:
                                                          isPro, // ✅ SOLO PRO (SKU + margen)
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
            MaterialPageRoute(
              builder: (_) => InventoryItemFormPage(
                proCloud: isPro, // ✅ SOLO PRO (SKU + margen)
              ),
            ),
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

Future<void> _askPurchaseStockAndCost({
  required BuildContext context,
  required WidgetRef ref,
  required InventoryController ctrl,
  required dynamic ent,
  required String uid,
  required InventoryItem item,
}) async {
  final qtyC = TextEditingController();
  final costC = TextEditingController();
  final noteC = TextEditingController();

  var rateMode = _RateMode.savedBase;
  var currency = _CostCurrency.bob;

  double? fetchedRate;

  final res = await showDialog<(double, double, String?, double?, _CostCurrency)>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Compra / reposición'),
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
                labelText: 'Cantidad',
                suffixText: item.unit,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_CostCurrency>(
                    initialValue: currency,
                    decoration: const InputDecoration(
                      labelText: 'Moneda costo',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _CostCurrency.bob,
                        child: Text('Bs'),
                      ),
                      DropdownMenuItem(
                        value: _CostCurrency.usd,
                        child: Text('USD'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => currency = v ?? _CostCurrency.bob),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: costC,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: currency == _CostCurrency.usd
                          ? 'Costo unitario (USD)'
                          : 'Costo unitario (Bs)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (currency == _CostCurrency.usd) ...[
              DropdownButtonFormField<_RateMode>(
                initialValue: rateMode,
                decoration: const InputDecoration(labelText: 'Tasa USD→Bs'),
                items: const [
                  DropdownMenuItem(
                    value: _RateMode.savedBase,
                    child: Text('Usar tasa base guardada'),
                  ),
                  DropdownMenuItem(
                    value: _RateMode.currentBinance,
                    child: Text('Traer tasa actual (Binance)'),
                  ),
                ],
                onChanged: (v) async {
                  final m = v ?? _RateMode.savedBase;
                  setState(() => rateMode = m);
                  if (m == _RateMode.currentBinance) {
                    try {
                      final repo = ref.read(dollarRepositoryProvider);
                      final r = await repo.fetchLastRate();
                      setState(() => fetchedRate = r);
                    } catch (_) {
                      setState(() => fetchedRate = null);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              if (rateMode == _RateMode.currentBinance)
                Text(
                  fetchedRate == null
                      ? 'No se pudo traer la tasa actual.'
                      : 'Tasa actual: ${fetchedRate!.toStringAsFixed(2)} Bs/USD',
                ),
            ],
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
              final qty = double.tryParse(
                qtyC.text.trim().replaceAll(',', '.'),
              );
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cantidad inválida.')),
                );
                return;
              }

              final unitCost = double.tryParse(
                costC.text.trim().replaceAll(',', '.'),
              );
              if (unitCost == null || unitCost <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Costo inválido.')),
                );
                return;
              }

              double? rate;
              if (currency == _CostCurrency.usd) {
                if (rateMode == _RateMode.currentBinance) {
                  rate = fetchedRate;
                } else {
                  final baseState = ref.read(dollarProtectionProvider(uid));
                  rate = baseState.maybeWhen(
                    data: (d) => d.baseRate,
                    orElse: () => null,
                  );
                }

                if (rate == null || rate <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No hay tasa USD válida.')),
                  );
                  return;
                }
              }

              final note = noteC.text.trim();
              Navigator.pop(context, (
                qty,
                unitCost,
                note.isEmpty ? null : note,
                rate,
                currency,
              ));
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    ),
  );

  if (res == null) return;

  final qty = res.$1;
  final unitCost = res.$2;
  final note = res.$3;
  final rate = res.$4;
  final curr = res.$5;

  final costBob = (curr == _CostCurrency.usd && rate != null)
      ? (unitCost * rate)
      : unitCost;

  await ctrl.adjustStock(
    itemId: item.id,
    delta: qty,
    type: StockMovementType.inQty,
    note: note,
    ent: ent,
  );

  final updated = item.copyWith(
    cost: costBob,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    dirty: true,
  );

  await ctrl.upsertItem(item: updated, ent: ent);
}
