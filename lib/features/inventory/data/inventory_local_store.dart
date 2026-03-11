import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';

class InventoryLocalStore {
  static const _kItems = 'inventory_items';
  static const _kMovs = 'inventory_movements';

  String _key(String base, {required String uid, required String companyId}) {
    return '$base::$uid::$companyId';
  }

  Future<List<InventoryItem>> listItems({
    required String uid,
    required String companyId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_kItems, uid: uid, companyId: companyId));
    if (raw == null || raw.trim().isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((m) => InventoryItem.fromJson(m)).toList();
  }

  Future<void> saveItems({
    required String uid,
    required String companyId,
    required List<InventoryItem> items,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await sp.setString(_key(_kItems, uid: uid, companyId: companyId), encoded);
  }

  Future<List<StockMovement>> listMovements({
    required String uid,
    required String companyId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_kMovs, uid: uid, companyId: companyId));
    if (raw == null || raw.trim().isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((m) => StockMovement.fromJson(m)).toList();
  }

  Future<void> saveMovements({
    required String uid,
    required String companyId,
    required List<StockMovement> movements,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(movements.map((e) => e.toJson()).toList());
    await sp.setString(_key(_kMovs, uid: uid, companyId: companyId), encoded);
  }
}
