import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/quote.dart';

final quotesLocalStoreProvider = Provider<QuotesLocalStore>((ref) {
  return QuotesLocalStore();
});

class QuotesLocalStore {
  static const _kKey = 'quotes_v1';

  Future<List<Quote>> loadAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((m) => Quote.fromJson(m)).toList();
  }

  Future<void> upsert(Quote q) async {
    final all = await loadAll();
    final next = [...all];
    final i = next.indexWhere((e) => e.id == q.id);
    if (i >= 0) {
      next[i] = q;
    } else {
      next.add(q);
    }
    await _saveAll(next);
  }

  Future<void> deleteById(String id) async {
    final all = await loadAll();
    final next = all.where((q) => q.id != id).toList();
    await _saveAll(next);
  }

  Future<void> _saveAll(List<Quote> quotes) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(quotes.map((q) => q.toJson()).toList());
    await sp.setString(_kKey, raw);
  }
}
