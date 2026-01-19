import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/entitlements.dart';
import '../domain/plan_tier.dart';

class EntitlementsRepository {
  EntitlementsRepository({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Watch por UID (más estable para Riverpod family<String>)
  Stream<Entitlements> watchUid(String uid) {
    final controller = StreamController<Entitlements>.broadcast();

    PlanTier? docTier;
    PlanTier? claimsTier;

    void emit() {
      final tier = claimsTier ?? docTier ?? PlanTier.free;
      controller.add(Entitlements.forTier(tier));
    }

    final docRef = _db.collection('users').doc(uid);

    // 1) Prefetch rápido para no emitir "free" falso al inicio
    () async {
      try {
        final snap = await docRef.get();
        final data = snap.data();
        docTier = PlanTier.fromString(data?['plan'] as String?);
      } catch (_) {}
      emit();
    }();

    // 2) Snapshots del doc
    final docSub = docRef.snapshots().listen((snap) {
      final data = snap.data();
      docTier = PlanTier.fromString(data?['plan'] as String?);
      emit();
    }, onError: controller.addError);

    // 3) Claims (si las usas). Si no tienes custom claims, esto quedará null y no molesta.
    final tokenSub = _auth.idTokenChanges().listen((u) async {
      if (u == null) return;
      if (u.uid != uid) return;
      try {
        claimsTier = await _tierFromClaims(u);
      } catch (_) {}
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await docSub.cancel();
      await tokenSub.cancel();
      await controller.close();
    };

    return controller.stream.distinct((a, b) => a.tier == b.tier);
  }

  Future<PlanTier?> _tierFromClaims(User user) async {
    // forceRefresh true evita token viejo en algunas situaciones
    final res = await user.getIdTokenResult(true);
    final claims = res.claims;
    if (claims == null) return null;

    final plan = claims['plan'];
    if (plan is String) return PlanTier.fromString(plan);

    return null;
  }
}
