import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../subscription/domain/entitlements.dart';
import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';
import 'inventory_cloud_service.dart';
import 'inventory_local_store.dart';

class InventoryOfflineFirstService {
  InventoryOfflineFirstService({
    FirebaseAuth? auth,
    InventoryLocalStore? local,
    InventoryCloudService? cloud,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _local = local ?? InventoryLocalStore(),
       _cloud = cloud ?? InventoryCloudService();

  final FirebaseAuth _auth;
  final InventoryLocalStore _local;
  final InventoryCloudService _cloud;

  Future<List<InventoryItem>> listItems({required String companyId}) async {
    final u = _auth.currentUser;
    if (u == null) return [];
    return _local.listItems(uid: u.uid, companyId: companyId);
  }

  Future<List<StockMovement>> listMovements({required String companyId}) async {
    final u = _auth.currentUser;
    if (u == null) return [];
    return _local.listMovements(uid: u.uid, companyId: companyId);
  }

  Stream<List<InventoryItem>> watchCloudItems({required String companyId}) {
    return _cloud.watchItems(companyId);
  }

  /// Aplica cloud -> local (no pisa items locales "dirty")
  Future<void> applyCloudToLocal({
    required String companyId,
    required List<InventoryItem> cloudItems,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final uid = u.uid;

    final local = await _local.listItems(uid: uid, companyId: companyId);
    final map = {for (final it in local) it.id: it};

    for (final cloud in cloudItems) {
      final existing = map[cloud.id];
      if (existing == null || !existing.dirty) {
        map[cloud.id] = cloud.copyWith(dirty: false);
      }
    }

    await _local.saveItems(
      uid: uid,
      companyId: companyId,
      items: map.values.toList(),
    );
  }

  Future<void> upsertItemOfflineFirst({
    required String companyId,
    required InventoryItem item,
    required Entitlements ent,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No hay usuario autenticado.');
    final uid = u.uid;

    final items = await _local.listItems(uid: uid, companyId: companyId);
    final idx = items.indexWhere((e) => e.id == item.id);
    final dirtyItem = item.copyWith(dirty: true);

    if (idx >= 0) {
      items[idx] = dirtyItem;
    } else {
      items.add(dirtyItem);
    }

    await _local.saveItems(uid: uid, companyId: companyId, items: items);

    if (!ent.cloudSync) return;

    await _cloud.upsertItem(companyId: companyId, uid: uid, item: dirtyItem);
    await _markItemClean(companyId: companyId, itemId: dirtyItem.id);
  }

  Future<void> deleteItemOfflineFirst({
    required String companyId,
    required String itemId,
    required Entitlements ent,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No hay usuario autenticado.');
    final uid = u.uid;

    final items = await _local.listItems(uid: uid, companyId: companyId);
    items.removeWhere((e) => e.id == itemId);
    await _local.saveItems(uid: uid, companyId: companyId, items: items);

    if (!ent.cloudSync) return;
    await _cloud.deleteItem(companyId: companyId, itemId: itemId);
  }

  Future<void> adjustStockOfflineFirst({
    required String companyId,
    required String itemId,
    required double delta,
    required StockMovement movement,
    required Entitlements ent,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No hay usuario autenticado.');
    final uid = u.uid;

    final items = await _local.listItems(uid: uid, companyId: companyId);
    final idx = items.indexWhere((e) => e.id == itemId);
    if (idx < 0) throw StateError('Item no existe.');

    final current = items[idx];
    if (current.kind == InventoryItemKind.servicio) {
      throw StateError('Un servicio no maneja stock.');
    }

    final updated = current.copyWith(
      stock: (((current.stock + delta)) as num).toInt(),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );

    items[idx] = updated;
    await _local.saveItems(uid: uid, companyId: companyId, items: items);

    final moves = await _local.listMovements(uid: uid, companyId: companyId);
    moves.add(movement.copyWith(dirty: true));
    await _local.saveMovements(
      uid: uid,
      companyId: companyId,
      movements: moves,
    );

    if (!ent.cloudSync) return;

    await _cloud.upsertItem(companyId: companyId, uid: uid, item: updated);
    await _cloud.addMovement(companyId: companyId, uid: uid, m: movement);
    await _markItemClean(companyId: companyId, itemId: itemId);
    await _markMovementClean(companyId: companyId, movementId: movement.id);
  }

  Future<int> syncPending({
    required String companyId,
    required Entitlements ent,
  }) async {
    if (!ent.cloudSync) return 0;
    final u = _auth.currentUser;
    if (u == null) return 0;
    final uid = u.uid;

    int synced = 0;
    final items = await _local.listItems(uid: uid, companyId: companyId);
    final moves = await _local.listMovements(uid: uid, companyId: companyId);

    for (final it in items.where((e) => e.dirty)) {
      await _cloud.upsertItem(companyId: companyId, uid: uid, item: it);
      await _markItemClean(companyId: companyId, itemId: it.id);
      synced++;
    }

    for (final mv in moves.where((e) => e.dirty)) {
      await _cloud.addMovement(companyId: companyId, uid: uid, m: mv);
      await _markMovementClean(companyId: companyId, movementId: mv.id);
      synced++;
    }

    return synced;
  }

  Future<void> _markItemClean({
    required String companyId,
    required String itemId,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final uid = u.uid;

    final items = await _local.listItems(uid: uid, companyId: companyId);
    final idx = items.indexWhere((e) => e.id == itemId);
    if (idx < 0) return;

    items[idx] = items[idx].copyWith(dirty: false);
    await _local.saveItems(uid: uid, companyId: companyId, items: items);
  }

  Future<void> _markMovementClean({
    required String companyId,
    required String movementId,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    final uid = u.uid;

    final moves = await _local.listMovements(uid: uid, companyId: companyId);
    final idx = moves.indexWhere((e) => e.id == movementId);
    if (idx < 0) return;

    moves[idx] = moves[idx].copyWith(dirty: false);
    await _local.saveMovements(
      uid: uid,
      companyId: companyId,
      movements: moves,
    );
  }
}
