import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DollarProtectionState {
  const DollarProtectionState({
    this.dollarMode,
    this.manualDollarRate,
    this.binanceDollarRate,
    this.lastFetchedDollarRate,
  });

  final String? dollarMode;
  final double? manualDollarRate;
  final double? binanceDollarRate;
  final double? lastFetchedDollarRate;

  double? get baseRate =>
      manualDollarRate ?? binanceDollarRate ?? lastFetchedDollarRate;

  factory DollarProtectionState.fromMap(Map<String, dynamic>? data) {
    double? asDouble(dynamic v) => v is num ? v.toDouble() : null;

    return DollarProtectionState(
      dollarMode: data?['dollarMode'] as String?,
      manualDollarRate: asDouble(data?['manualDollarRate']),
      binanceDollarRate: asDouble(data?['binanceDollarRate']),
      lastFetchedDollarRate: asDouble(data?['lastFetchedDollarRate']),
    );
  }
}

class DollarRepository {
  DollarRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return _db.collection('users').doc(uid);
  }

  bool _canUseUsersDoc(String uid) {
    final user = _auth.currentUser;
    return user != null && user.uid == uid && !user.isAnonymous;
  }

  Future<Map<String, dynamic>?> getUserDollarData(String uid) async {
    if (!_canUseUsersDoc(uid)) return null;
    final snap = await _userRef(uid).get();
    return snap.data();
  }

  Stream<DollarProtectionState> watchState(String uid) {
    if (!_canUseUsersDoc(uid)) {
      return Stream.value(const DollarProtectionState());
    }

    return _userRef(
      uid,
    ).snapshots().map((snap) => DollarProtectionState.fromMap(snap.data()));
  }

  Future<double?> fetchLastRate([String? uid]) async {
    final resolvedUid = uid ?? _auth.currentUser?.uid;
    if (resolvedUid == null) return null;

    final data = await getUserDollarData(resolvedUid);
    final value = data?['lastFetchedDollarRate'];
    return value is num ? value.toDouble() : null;
  }

  Future<void> setManualRate({required String uid, required num rate}) async {
    if (!_canUseUsersDoc(uid)) return;

    await _userRef(uid).set({
      'dollarMode': 'manual',
      'manualDollarRate': rate.toDouble(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setBinanceRate({required String uid, required num rate}) async {
    if (!_canUseUsersDoc(uid)) return;

    await _userRef(uid).set({
      'dollarMode': 'binance',
      'binanceDollarRate': rate.toDouble(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setLastFetchedRate({
    required String uid,
    required num rate,
  }) async {
    if (!_canUseUsersDoc(uid)) return;

    await _userRef(uid).set({
      'lastFetchedDollarRate': rate.toDouble(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDollarPreference({
    required String uid,
    required String mode,
  }) async {
    if (!_canUseUsersDoc(uid)) return;

    await _userRef(uid).set({
      'dollarMode': mode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearDollarData(String uid) async {
    if (!_canUseUsersDoc(uid)) return;

    await _userRef(uid).set({
      'dollarMode': FieldValue.delete(),
      'manualDollarRate': FieldValue.delete(),
      'binanceDollarRate': FieldValue.delete(),
      'lastFetchedDollarRate': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
