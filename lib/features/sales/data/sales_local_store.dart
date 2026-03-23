import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/sale.dart';

class SalesLocalStore {
  static const _kBase = 'sales_v1';

  String _key(String uid, String companyId) => '$_kBase::$uid::$companyId';

  String _resolveKey(String? uid, String? companyId) {
    final u = uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final c = companyId ?? 'default';
    return _key(u, c);
  }

  Future<List<Sale>> loadAll({String? uid, String? companyId}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_resolveKey(uid, companyId));
    if (raw == null || raw.trim().isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((m) => Sale.fromJson(m)).toList();
  }

  Future<void> upsert(Sale sale, {String? uid, String? companyId}) async {
    final all = await loadAll(uid: uid, companyId: companyId);
    final next = [...all];
    final i = next.indexWhere((e) => e.id == sale.id);
    if (i >= 0) {
      next[i] = sale;
    } else {
      next.add(sale);
    }
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> deleteById(String id, {String? uid, String? companyId}) async {
    final all = await loadAll(uid: uid, companyId: companyId);
    final next = all.where((e) => e.id != id).toList();
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> _saveAll(List<Sale> sales, {String? uid, String? companyId}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(sales.map((e) => e.toJson()).toList());
    await sp.setString(_resolveKey(uid, companyId), raw);
  }
}
