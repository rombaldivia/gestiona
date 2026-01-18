import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';

class InventoryCloudService {
  InventoryCloudService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _itemsCol(String companyId) =>
      _db.collection('companies').doc(companyId).collection('inventory_items');

  CollectionReference<Map<String, dynamic>> _movesCol(String companyId) =>
      _db.collection('companies').doc(companyId).collection('stock_movements');

  Stream<List<InventoryItem>> watchItems(String companyId) {
    return _itemsCol(companyId).snapshots().map(
      (qs) => qs.docs
          .map((d) => InventoryItem.fromJson({...d.data(), 'id': d.id}))
          .toList(),
    );
  }

  Future<void> upsertItem({
    required String companyId,
    required String uid,
    required InventoryItem item,
  }) async {
    await _itemsCol(companyId).doc(item.id).set({
      ...item.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Future<void> deleteItem({
    required String companyId,
    required String itemId,
  }) async {
    await _itemsCol(companyId).doc(itemId).delete();
  }

  Future<void> addMovement({
    required String companyId,
    required String uid,
    required StockMovement m,
  }) async {
    await _movesCol(companyId).doc(m.id).set({
      ...m.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    }, SetOptions(merge: true));
  }
}
