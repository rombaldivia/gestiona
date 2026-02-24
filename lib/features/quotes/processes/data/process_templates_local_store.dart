import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/process_template.dart';

class ProcessTemplatesLocalStore {
  static const _kBase = 'quotes.process_templates.v1';

  // FIX: La clave ahora incluye uid y companyId para que los templates
  // de proceso no sean compartidos entre distintos usuarios o empresas.
  // Antes era una clave global 'quotes.process_templates.v1'.
  String _key(String uid, String companyId) => '$_kBase::$uid::$companyId';

  String _resolveKey({String? uid, String? companyId}) {
    final u = uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final c = companyId ?? 'default';
    return _key(u, c);
  }

  Future<List<ProcessTemplate>> loadAll({
    String? uid,
    String? companyId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_resolveKey(uid: uid, companyId: companyId));
    if (raw == null || raw.trim().isEmpty) return const <ProcessTemplate>[];

    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list
          .map(
            (e) => ProcessTemplate.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const <ProcessTemplate>[];
    }
  }

  Future<void> upsert(
    ProcessTemplate t, {
    String? uid,
    String? companyId,
  }) async {
    final items = await loadAll(uid: uid, companyId: companyId);
    final next = [t, ...items.where((x) => x.id != t.id)];
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> deleteById(
    String id, {
    String? uid,
    String? companyId,
  }) async {
    final items = await loadAll(uid: uid, companyId: companyId);
    final next = items.where((x) => x.id != id).toList();
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> _saveAll(
    List<ProcessTemplate> items, {
    String? uid,
    String? companyId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_resolveKey(uid: uid, companyId: companyId), raw);
  }
}
