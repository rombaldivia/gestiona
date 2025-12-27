import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CompanyLocalStore {
  static String _kActiveCompanyId(String uid) => 'company.active.id.$uid';
  static String _kActiveCompanyName(String uid) => 'company.active.name.$uid';
  static String _kPendingList(String uid) => 'company.pending.list.$uid';

  Future<void> setActiveCompany({
    required String uid,
    required String id,
    required String name,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kActiveCompanyId(uid), id);
    await sp.setString(_kActiveCompanyName(uid), name);
  }

  Future<(String, String)?> getActiveCompany({required String uid}) async {
    final sp = await SharedPreferences.getInstance();
    final id = sp.getString(_kActiveCompanyId(uid));
    final name = sp.getString(_kActiveCompanyName(uid));
    if (id == null || name == null) return null;
    return (id, name);
  }

  Future<void> clearAllForUser({required String uid}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kActiveCompanyId(uid));
    await sp.remove(_kActiveCompanyName(uid));
    await sp.remove(_kPendingList(uid));
  }

  Future<void> addPendingCompany({
    required String uid,
    required String id,
    required String name,
    required int createdAtMs,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPendingList(uid));
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    // evita duplicados por id
    final exists = list.any((e) => e['id'] == id);
    if (!exists) {
      list.add({'id': id, 'name': name, 'createdAtMs': createdAtMs});
    }
    await sp.setString(_kPendingList(uid), jsonEncode(list));
  }

  Future<void> removePendingCompany(String uid, String companyId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPendingList(uid));
    if (raw == null) return;

    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    list.removeWhere((e) => e['id'] == companyId);
    await sp.setString(_kPendingList(uid), jsonEncode(list));
  }

  Future<List<(String, String)>> listPendingCompanies({
    required String uid,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPendingList(uid));
    if (raw == null) return [];

    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) => (e['id'] as String, e['name'] as String)).toList();
  }
}
