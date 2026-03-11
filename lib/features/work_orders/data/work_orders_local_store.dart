import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/work_order.dart';

final workOrdersLocalStoreProvider = Provider<WorkOrdersLocalStore>(
  (_) => WorkOrdersLocalStore(),
);

class WorkOrdersLocalStore {
  static const _kBase = 'work_orders_v1';

  String _key(String uid, String companyId) => '$_kBase::$uid::$companyId';

  String _resolveKey(String? uid, String? companyId) {
    final u = uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final c = companyId ?? 'default';
    return _key(u, c);
  }

  Future<List<WorkOrder>> loadAll({String? uid, String? companyId}) async {
    final sp  = await SharedPreferences.getInstance();
    final raw = sp.getString(_resolveKey(uid, companyId));
    if (raw == null || raw.trim().isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(WorkOrder.fromJson).toList();
  }

  Future<void> upsert(
    WorkOrder wo, {
    String? uid,
    String? companyId,
  }) async {
    final all  = await loadAll(uid: uid, companyId: companyId);
    final next = [...all];
    final i    = next.indexWhere((e) => e.id == wo.id);
    if (i >= 0) {
      next[i] = wo;
    } else {
      next.add(wo);
    }
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> deleteById(
    String id, {
    String? uid,
    String? companyId,
  }) async {
    final all  = await loadAll(uid: uid, companyId: companyId);
    final next = all.where((wo) => wo.id != id).toList();
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> _saveAll(
    List<WorkOrder> orders, {
    String? uid,
    String? companyId,
  }) async {
    final sp  = await SharedPreferences.getInstance();
    final raw = jsonEncode(orders.map((wo) => wo.toJson()).toList());
    await sp.setString(_resolveKey(uid, companyId), raw);
  }
}
