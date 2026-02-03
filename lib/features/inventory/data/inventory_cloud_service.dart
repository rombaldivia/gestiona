import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';

class InventoryCloudService {
  InventoryCloudService([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _itemsCol({
    required String companyId,
  }) {
    return _db.collection('companies').doc(companyId).collection('inventory_items');
  }

  CollectionReference<Map<String, dynamic>> _movCol({
    required String companyId,
  }) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('inventory_movements');
  }

  /// OJO: OfflineFirstService lo llama como _cloud.watchItems(companyId)
  /// (posicional, sin uid). Por compatibilidad, uid se ignora a este nivel.
  Stream<List<InventoryItem>> watchItems(String companyId) {
    return _itemsCol(companyId: companyId).snapshots().map((snap) {
      return snap.docs
          .map((d) => InventoryItem.fromJson({'id': d.id, ...d.data()}))
          .toList();
    });
  }

  Future<List<InventoryItem>> listItems({
    required String companyId,
    required String uid,
  }) async {
    final snap = await _itemsCol(companyId: companyId).get();
    return snap.docs
        .map((d) => InventoryItem.fromJson({'id': d.id, ...d.data()}))
        .toList();
  }

  Future<void> upsertItem({
    required String companyId,
    required String uid,
    required InventoryItem item,
  }) async {
    await _itemsCol(
      companyId: companyId,
    ).doc(item.id).set(item.toJson(), SetOptions(merge: true));
  }

  /// OfflineFirstService llama deleteItem(companyId:..., itemId:...) sin uid
  Future<void> deleteItem({
    required String companyId,
    required String itemId,
  }) async {
    await _itemsCol(companyId: companyId).doc(itemId).delete();
  }

  /// OfflineFirstService usa addMovement(..., m: movement)
  Future<void> addMovement({
    required String companyId,
    required String uid,
    required StockMovement m,
  }) async {
    await _movCol(companyId: companyId).add(m.toJson());
  }

  Future<List<StockMovement>> listMovements({
    required String companyId,
    required String uid,
  }) async {
    final snap = await _movCol(
      companyId: companyId,
    ).orderBy('createdAtMs', descending: true).get();

    return snap.docs
        .map((d) => StockMovement.fromJson({'id': d.id, ...d.data()}))
        .toList();
  }
}
