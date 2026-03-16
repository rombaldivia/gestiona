import 'package:firebase_auth/firebase_auth.dart';

import '../../subscription/domain/entitlements.dart';
import '../domain/work_order.dart';
import 'work_orders_cloud_service.dart';
import 'work_orders_local_store.dart';

class WorkOrdersOfflineFirstService {
  WorkOrdersOfflineFirstService({
    FirebaseAuth? auth,
    WorkOrdersLocalStore? local,
    WorkOrdersCloudService? cloud,
  })  : _auth  = auth  ?? FirebaseAuth.instance,
        _local = local ?? WorkOrdersLocalStore(),
        _cloud = cloud ?? WorkOrdersCloudService();

  final FirebaseAuth          _auth;
  final WorkOrdersLocalStore  _local;
  final WorkOrdersCloudService _cloud;

  String? get _uid => _auth.currentUser?.uid;

  Future<List<WorkOrder>> listOrders({required String companyId}) async {
    final uid = _uid;
    if (uid == null) return [];
    return _local.loadAll(uid: uid, companyId: companyId);
  }

  Stream<List<WorkOrder>> watchCloudOrders({required String companyId}) =>
      _cloud.watchOrders(companyId: companyId);

  Future<void> applyCloudToLocal({
    required String companyId,
    required List<WorkOrder> cloudOrders,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final local = await _local.loadAll(uid: uid, companyId: companyId);
    final map   = {for (final o in local) o.id: o};

    for (final co in cloudOrders) {
      final lo = map[co.id];
      if (lo == null || co.updatedAtMs >= lo.updatedAtMs) {
        map[co.id] = co;
      }
    }

    await _saveAll(map.values.toList(), uid: uid, companyId: companyId);
  }

  Future<void> upsertOfflineFirst({
    required String companyId,
    required WorkOrder order,
    required Entitlements ent,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('No hay usuario autenticado.');

    await _local.upsert(order, uid: uid, companyId: companyId);

    if (!ent.cloudSync) return;

    await _cloud.upsertOrder(companyId: companyId, uid: uid, order: order);
  }

  Future<void> deleteOfflineFirst({
    required String companyId,
    required String orderId,
    required Entitlements ent,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('No hay usuario autenticado.');

    await _local.deleteById(orderId, uid: uid, companyId: companyId);

    if (!ent.cloudSync) return;

    await _cloud.deleteOrder(companyId: companyId, orderId: orderId);
  }

  Future<int> syncPending({
    required String companyId,
    required Entitlements ent,
  }) async {
    if (!ent.cloudSync) return 0;
    final uid = _uid;
    if (uid == null) return 0;

    final local = await _local.loadAll(uid: uid, companyId: companyId);
    int synced  = 0;

    for (final o in local) {
      try {
        await _cloud.upsertOrder(companyId: companyId, uid: uid, order: o);
        synced++;
      } catch (_) {}
    }
    return synced;
  }

  Future<void> _saveAll(
    List<WorkOrder> orders, {
    required String uid,
    required String companyId,
  }) async {
    for (final o in orders) {
      await _local.upsert(o, uid: uid, companyId: companyId);
    }
  }
}
