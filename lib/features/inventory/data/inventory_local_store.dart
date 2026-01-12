import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';

/// Local store simple (SharedPreferences) para MVP.
///
/// - Está pensado para listas pequeñas/medianas.
/// - Si luego crece, lo ideal es migrar a una BD local (Drift/Isar/Hive)
///   manteniendo la misma interfaz.
class InventoryLocalStore {
  static String _kItems(String uid, String companyId) =>
      'inv.items.$uid.$companyId';
  static String _kMovements(String uid, String companyId) =>
      'inv.moves.$uid.$companyId';

  Future<List<InventoryItem>> listItems({
    required String uid,
    required String companyId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kItems(uid, companyId));
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(InventoryItem.fromJson).toList();
  }

  Future<void> saveItems({
    required String uid,
    required String companyId,
    required List<InventoryItem> items,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kItems(uid, companyId),
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<StockMovement>> listMovements({
    required String uid,
    required String companyId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kMovements(uid, companyId));
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(StockMovement.fromJson).toList();
  }

  Future<void> saveMovements({
    required String uid,
    required String companyId,
    required List<StockMovement> movements,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _kMovements(uid, companyId),
      jsonEncode(movements.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearAllForCompany({
    required String uid,
    required String companyId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kItems(uid, companyId));
    await sp.remove(_kMovements(uid, companyId));
  }
}
