import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/work_order.dart';

class WorkOrdersCloudService {
  WorkOrdersCloudService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String companyId) =>
      _db.collection('companies').doc(companyId).collection('work_orders');

  Stream<List<WorkOrder>> watchOrders({required String companyId}) {
    return _col(companyId)
        .orderBy('updatedAtMs', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => WorkOrder.fromJson(d.data())).toList());
  }

  Future<void> upsertOrder({
    required String companyId,
    required String uid,
    required WorkOrder order,
  }) async {
    final data = order.toJson();
    data['updatedByUid'] = uid;
    await _col(companyId).doc(order.id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteOrder({
    required String companyId,
    required String orderId,
  }) async {
    await _col(companyId).doc(orderId).delete();
  }
}
