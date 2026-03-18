import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum ActivityModule { quote, workOrder, inventory }
enum ActivityVerb { created, updated, deleted, stockIn, stockOut }

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.module,
    required this.verb,
    required this.label,
    required this.detail,
    required this.createdAtMs,
  });

  final String id;
  final ActivityModule module;
  final ActivityVerb verb;
  final String label;
  final String detail;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module.name,
        'verb': verb.name,
        'label': label,
        'detail': detail,
        'createdAtMs': createdAtMs,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> m) => ActivityEvent(
        id: m['id'] as String,
        module: ActivityModule.values.byName(m['module'] as String),
        verb: ActivityVerb.values.byName(m['verb'] as String),
        label: _sanitizeText(m['label'] as String),
        detail: _sanitizeText(m['detail'] as String),
        createdAtMs: m['createdAtMs'] as int,
      );

  static String _sanitizeText(String value) {
    return value
        .replaceAll(r'\${q.sequence}', '')
        .replaceAll(r'\${q.year}', '')
        .replaceAll(r'\${wo.sequence}', '')
        .replaceAll(r'\${wo.year}', '')
        .replaceAll('COT #-', 'COT #')
        .replaceAll('OT #-', 'OT #')
        .trim();
  }

  static ActivityEvent make({
    required ActivityModule module,
    required ActivityVerb verb,
    required String label,
    required String detail,
  }) =>
      ActivityEvent(
        id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
        module: module,
        verb: verb,
        label: _sanitizeText(label),
        detail: _sanitizeText(detail),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

class ActivityStore {
  static const _key = 'gestiona_activity_v1';
  static const _maxLen = 50;

  Future<List<ActivityEvent>> loadAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ActivityEvent.fromJson)
          .toList();

      await sp.setString(
        _key,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );

      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ActivityEvent event) async {
    final all = await loadAll();
    final next = [event, ...all].take(_maxLen).toList();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
