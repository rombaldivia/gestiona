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

  Future<void> upsertItem({
    required String companyId,
    required String uid,
    required InventoryItem item,
  }) async {
    await _itemsCol(companyId).doc(item.id).set({
      'id': item.id,
      'name': item.name,
      'sku': item.sku,
      'unit': item.unit,
      'salePrice': item.salePrice,
      'cost': item.cost,
      'stock': item.stock,
      'minStock': item.minStock,
      'updatedAtMs': item.updatedAtMs,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
      'kind': item.kind.key,
      'pricingMode': item.pricingMode,
      'calcMargin': item.calcMargin,
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
      'id': m.id,
      'itemId': m.itemId,
      'type': m.type.name,
      'qty': m.qty,
      'note': m.note,
      'refType': m.refType,
      'refId': m.refId,
      'createdAtMs': m.createdAtMs,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    }, SetOptions(merge: true));
  }
}
