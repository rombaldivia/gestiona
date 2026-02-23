import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/process_template.dart';

class ProcessTemplatesLocalStore {
  static const _kKey = 'quotes.process_templates.v1';

  Future<List<ProcessTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const <ProcessTemplate>[];

    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list
          .map(
            (e) => ProcessTemplate.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      // si está corrupto, no crashear
      return const <ProcessTemplate>[];
    }
  }

  Future<void> upsert(ProcessTemplate t) async {
    final items = await loadAll();
    final next = [t, ...items.where((x) => x.id != t.id)];
    await _saveAll(next);
  }

  Future<void> deleteById(String id) async {
    final items = await loadAll();
    final next = items.where((x) => x.id != id).toList();
    await _saveAll(next);
  }

  Future<void> _saveAll(List<ProcessTemplate> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_kKey, raw);
  }
}
