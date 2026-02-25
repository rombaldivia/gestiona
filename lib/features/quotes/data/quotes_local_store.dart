import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/quote.dart';

final quotesLocalStoreProvider = Provider<QuotesLocalStore>((ref) {
  return QuotesLocalStore();
});

class QuotesLocalStore {
  static const _kBase = 'quotes_v1';

  // FIX: La clave ahora incluye uid y companyId para evitar que dos
  // usuarios o dos empresas compartan los mismos datos locales.
  // Antes era simplemente 'quotes_v1' (clave global compartida).
  String _key(String uid, String companyId) => '$_kBase::$uid::$companyId';

  String _resolveKey(String? uid, String? companyId) {
    final u = uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final c = companyId ?? 'default';
    return _key(u, c);
  }

  Future<List<Quote>> loadAll({String? uid, String? companyId}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_resolveKey(uid, companyId));
    if (raw == null || raw.trim().isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((m) => Quote.fromJson(m)).toList();
  }

  Future<void> upsert(Quote q, {String? uid, String? companyId}) async {
    final all = await loadAll(uid: uid, companyId: companyId);
    final next = [...all];
    final i = next.indexWhere((e) => e.id == q.id);
    if (i >= 0) {
      next[i] = q;
    } else {
      next.add(q);
    }
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> deleteById(
    String id, {
    String? uid,
    String? companyId,
  }) async {
    final all = await loadAll(uid: uid, companyId: companyId);
    final next = all.where((q) => q.id != id).toList();
    await _saveAll(next, uid: uid, companyId: companyId);
  }

  Future<void> saveAll(
    List<Quote> quotes, {
    String? uid,
    String? companyId,
  }) =>
      _saveAll(quotes, uid: uid, companyId: companyId);

  Future<void> _saveAll(
    List<Quote> quotes, {
    String? uid,
    String? companyId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(quotes.map((q) => q.toJson()).toList());
    await sp.setString(_resolveKey(uid, companyId), raw);
  }
}
