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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _local = local ?? InventoryLocalStore(),
        _cloud = cloud ?? InventoryCloudService();

  final FirebaseAuth _auth;
  final InventoryLocalStore _local;
  final InventoryCloudService _cloud;

  Future<List<InventoryItem>> listItems({
    required String companyId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return _local.listItems(uid: user.uid, companyId: companyId);
  }

  Future<List<StockMovement>> listMovements({
    required String companyId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return _local.listMovements(uid: user.uid, companyId: companyId);
  }

  Future<void> upsertItemOfflineFirst({
    required String companyId,
    required InventoryItem item,
    required Entitlements ent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    final uid = user.uid;

    // 🔎 LOG CLAVE
    // ignore: avoid_print
    print('🧩 upsertItemOfflineFirst uid=$uid companyId=$companyId tier=${ent.tier} cloudSync=${ent.cloudSync}');

    final items = await _local.listItems(uid: uid, companyId: companyId);
    final idx = items.indexWhere((e) => e.id == item.id);

    final dirtyItem = item.copyWith(dirty: true);

    if (idx >= 0) {
      items[idx] = dirtyItem;
    } else {
      items.add(dirtyItem);
    }

    await _local.saveItems(uid: uid, companyId: companyId, items: items);

    if (!ent.cloudSync) {
      // ignore: avoid_print
      print('⛔ cloudSync=false, NO se sube a Firestore (plan FREE).');
      return;
    }

    try {
      await _cloud.upsertItem(companyId: companyId, uid: uid, item: dirtyItem);
      await _markItemClean(companyId: companyId, itemId: dirtyItem.id);
      // ignore: avoid_print
      print('✅ Item subido a Firestore OK');
    } catch (e, st) {
      // ignore: avoid_print
      print('🔥 Inventory sync error (upsert): $e');
      // ignore: avoid_print
      print(st);
    }
  }

  Future<void> deleteItemOfflineFirst({
    required String companyId,
    required String itemId,
    required Entitlements ent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    final uid = user.uid;

    final items = await _local.listItems(uid: uid, companyId: companyId);
    items.removeWhere((e) => e.id == itemId);
    await _local.saveItems(uid: uid, companyId: companyId, items: items);

    if (!ent.cloudSync) return;

    try {
      await _cloud.deleteItem(companyId: companyId, itemId: itemId);
    } catch (e, st) {
      // ignore: avoid_print
      print('🔥 Inventory sync error (delete): $e');
      // ignore: avoid_print
      print(st);
    }
  }

  Future<void> adjustStockOfflineFirst({
    required String companyId,
    required String itemId,
    required double delta,
    required StockMovement movement,
    required Entitlements ent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    final uid = user.uid;

    // ignore: avoid_print
    print('🧩 adjustStockOfflineFirst uid=$uid companyId=$companyId tier=${ent.tier} cloudSync=${ent.cloudSync}');

    final items = await _local.listItems(uid: uid, companyId: companyId);
    final idx = items.indexWhere((e) => e.id == itemId);
    if (idx < 0) throw StateError('Item no existe.');

    final current = items[idx];
    if (current.kind == InventoryItemKind.service) {
      throw StateError('Un servicio no maneja stock.');
    }

    final updated = current.copyWith(
      stock: (current.stock + delta),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );

    items[idx] = updated;
    await _local.saveItems(uid: uid, companyId: companyId, items: items);

    final moves = await _local.listMovements(uid: uid, companyId: companyId);
    moves.add(movement.copyWith(dirty: true));
    await _local.saveMovements(uid: uid, companyId: companyId, movements: moves);

    if (!ent.cloudSync) return;

    try {
      await _cloud.upsertItem(companyId: companyId, uid: uid, item: updated);
      await _cloud.addMovement(companyId: companyId, uid: uid, m: movement);
      await _markItemClean(companyId: companyId, itemId: itemId);
      await _markMovementClean(companyId: companyId, movementId: movement.id);
      // ignore: avoid_print
      print('✅ Stock + movimiento subidos a Firestore OK');
    } catch (e, st) {
      // ignore: avoid_print
      print('🔥 Inventory sync error (adjust): $e');
      // ignore: avoid_print
      print(st);
    }
  }

  Future<int> syncPending({
    required String companyId,
    required Entitlements ent,
  }) async {
    if (!ent.cloudSync) return 0;
    final user = _auth.currentUser;
    if (user == null) return 0;
    final uid = user.uid;

    // ignore: avoid_print
    print('🧩 syncPending uid=$uid companyId=$companyId tier=${ent.tier} cloudSync=${ent.cloudSync}');

    int synced = 0;
    final items = await _local.listItems(uid: uid, companyId: companyId);
    final moves = await _local.listMovements(uid: uid, companyId: companyId);

    for (final it in items.where((e) => e.dirty)) {
      try {
        await _cloud.upsertItem(companyId: companyId, uid: uid, item: it);
        await _markItemClean(companyId: companyId, itemId: it.id);
        synced++;
      } catch (e, st) {
        // ignore: avoid_print
        print('🔥 Inventory syncPending item error: $e');
        // ignore: avoid_print
        print(st);
      }
    }

    for (final mv in moves.where((e) => e.dirty)) {
      try {
        await _cloud.addMovement(companyId: companyId, uid: uid, m: mv);
        await _markMovementClean(companyId: companyId, movementId: mv.id);
        synced++;
      } catch (e, st) {
        // ignore: avoid_print
        print('🔥 Inventory syncPending movement error: $e');
        // ignore: avoid_print
        print(st);
      }
    }

    return synced;
  }

  Future<void> _markItemClean({
    required String companyId,
    required String itemId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

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
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final moves = await _local.listMovements(uid: uid, companyId: companyId);
    final idx = moves.indexWhere((e) => e.id == movementId);
    if (idx < 0) return;

    moves[idx] = moves[idx].copyWith(dirty: false);
    await _local.saveMovements(uid: uid, companyId: companyId, movements: moves);
  }
}
