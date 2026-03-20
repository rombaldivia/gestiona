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
    this.entityId,
  });

  final String id;
  final ActivityModule module;
  final ActivityVerb verb;
  final String label;
  final String detail;
  final int createdAtMs;
  final String? entityId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module.name,
        'verb': verb.name,
        'label': label,
        'detail': detail,
        'createdAtMs': createdAtMs,
        'entityId': entityId,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> m) => ActivityEvent(
        id: m['id'] as String,
        module: ActivityModule.values.byName(m['module'] as String),
        verb: ActivityVerb.values.byName(m['verb'] as String),
        label: m['label'] as String,
        detail: m['detail'] as String,
        createdAtMs: m['createdAtMs'] as int,
        entityId: m['entityId'] as String?,
      );

  static ActivityEvent make({
    required ActivityModule module,
    required ActivityVerb verb,
    required String label,
    required String detail,
    String? entityId,
  }) =>
      ActivityEvent(
        id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
        module: module,
        verb: verb,
        label: label,
        detail: detail,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        entityId: entityId,
      );
}

class ActivityStore {
  static const _key = 'gestiona_activity_v1';
  static const _max = 30;

  Future<List<ActivityEvent>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ActivityEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ActivityEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAll();
    final next = [event, ...current].take(_max).toList();
    await prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
