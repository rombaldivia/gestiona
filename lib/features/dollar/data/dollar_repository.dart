import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class DollarRepository {
  DollarRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _apiUrl = 'https://bo.dolarapi.com/v1/dolares/binance';

  Stream<DollarProtectionState> watchState(String uid) {
    final ref = _db.collection('users').doc(uid);
    return ref.snapshots().map((snap) {
      final data = snap.data();
      return DollarProtectionState.fromUserDoc(data);
    });
  }

  Future<double> fetchLastRate() async {
    final res = await http.get(Uri.parse(_apiUrl));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final v = json['venta'];
    if (v is num) return v.toDouble();
    throw Exception('Respuesta inesperada: falta "venta"');
  }

  /// Activa protección dólar a nivel usuario guardando baseRate=lastRate.
  Future<void> enableAndSetBase(String uid) async {
    final last = await fetchLastRate();
    await _db.collection('users').doc(uid).set({
      'dollarProtection': {
        'enabled': true,
        'baseRate': last,
        'lastRate': last,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'provider': 'binance',
      }
    }, SetOptions(merge: true));
  }

  /// Apaga la protección dólar (no borra rates, solo enabled=false).
  Future<void> disable(String uid) async {
    await _db.collection('users').doc(uid).set({
      'dollarProtection': {'enabled': false}
    }, SetOptions(merge: true));
  }

  /// Actualiza lastRate (no cambia baseRate).
  Future<void> refreshLast(String uid) async {
    final last = await fetchLastRate();
    await _db.collection('users').doc(uid).set({
      'dollarProtection': {
        'lastRate': last,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'provider': 'binance',
      }
    }, SetOptions(merge: true));
  }

  static double? adjustAmount({
    required double baseAmount,
    required double? baseRate,
    required double? lastRate,
  }) {
    if (baseRate == null || lastRate == null) return null;
    if (baseRate <= 0) return null;
    final factor = lastRate / baseRate;
    return baseAmount * factor;
  }
}

class DollarProtectionState {
  const DollarProtectionState({
    required this.enabled,
    this.baseRate,
    this.lastRate,
  });

  final bool enabled;
  final double? baseRate;
  final double? lastRate;

  factory DollarProtectionState.fromUserDoc(Map<String, dynamic>? data) {
    final dp = (data?['dollarProtection'] as Map?)?.cast<String, dynamic>();
    if (dp == null) return const DollarProtectionState(enabled: false);
    return DollarProtectionState(
      enabled: (dp['enabled'] as bool?) ?? false,
      baseRate: (dp['baseRate'] as num?)?.toDouble(),
      lastRate: (dp['lastRate'] as num?)?.toDouble(),
    );
  }
}
