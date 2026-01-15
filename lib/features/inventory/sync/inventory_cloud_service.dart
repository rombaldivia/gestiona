import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'inventory_item.dart';
import 'pending_change.dart';

/// Servicio para escribir/leer inventario en Firestore.
/// Rutas recomendadas:
///   /companies/{companyId}/inventory/{itemId}
class InventoryCloudService {
  InventoryCloudService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _inventoryCol(String companyId) =>
      _db.collection('companies').doc(companyId).collection('inventory');

  /// Crea o actualiza un item en Firestore (merge).
  Future<void> createOrUpdateItem(String companyId, InventoryItem item) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Usuario no autenticado');

    final docRef = _inventoryCol(companyId).doc(item.id);
    final data = item.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = user.uid;

    await docRef.set(data, SetOptions(merge: true));
  }

  /// Borra un item. Por defecto realiza soft-delete (marca deleted=true).
  Future<void> deleteItem(String companyId, String itemId, {bool soft = true}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Usuario no autenticado');

    final docRef = _inventoryCol(companyId).doc(itemId);
    if (soft) {
      await docRef.set({
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      }, SetOptions(merge: true));
    } else {
      await docRef.delete();
    }
  }

  /// Aplica una lista de cambios usando WriteBatch. Chunk en 400 ops para margen.
  Future<void> applyBatchChanges(String companyId, List<PendingChange> changes) async {
    if (changes.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) throw StateError('Usuario no autenticado');

    for (var i = 0; i < changes.length; i += 400) {
      final chunk = changes.skip(i).take(400);
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();

      for (final change in chunk) {
        final docRef = _inventoryCol(companyId).doc(change.item.id);
        if (change.type == ChangeType.delete) {
          if (change.softDelete ?? true) {
            batch.set(docRef, {
              'deleted': true,
              'updatedAt': now,
              'updatedBy': user.uid,
            }, SetOptions(merge: true));
          } else {
            batch.delete(docRef);
          }
        } else {
          final data = change.item.toMap();
          data['updatedAt'] = now;
          data['updatedBy'] = user.uid;
          batch.set(docRef, data, SetOptions(merge: true));
        }
      }

      await batch.commit();
    }
  }

  /// Escucha en tiempo real la colección de inventory de la company.
  Stream<List<InventoryItem>> watchItems(String companyId) {
    return _inventoryCol(companyId).snapshots().map((snap) =>
        snap.docs.map((d) => InventoryItem.fromMap(d.data())).toList());
  }
}
