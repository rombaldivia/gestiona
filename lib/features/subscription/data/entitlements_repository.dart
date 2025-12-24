import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/entitlements.dart';
import '../domain/plan_tier.dart';

class EntitlementsRepository {
  EntitlementsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<Entitlements> watchFor(User user) {
    final controller = StreamController<Entitlements>.broadcast();

    PlanTier? docTier;
    PlanTier? claimsTier;

    void emit() {
      final tier = claimsTier ?? docTier ?? PlanTier.free;
      controller.add(Entitlements.forTier(tier));
    }

    final docRef = _db.collection('users').doc(user.uid);

    final docSub = docRef.snapshots().listen(
      (snap) {
        final data = snap.data();
        docTier = PlanTier.fromString(data?['plan'] as String?);
        emit();
      },
      onError: controller.addError,
    );

    final tokenSub = _auth.idTokenChanges().listen(
      (u) async {
        if (u == null) return;
        claimsTier = await _tierFromClaims(u);
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await docSub.cancel();
      await tokenSub.cancel();
      await controller.close();
    };

    () async {
      try {
        claimsTier = await _tierFromClaims(user);
      } catch (_) {}
      emit();
    }();

    return controller.stream.distinct((a, b) => a.tier == b.tier);
  }

  Future<PlanTier?> _tierFromClaims(User user) async {
    final res = await user.getIdTokenResult();
    final claims = res.claims;
    if (claims == null) return null;

    final plan = claims['plan'];
    if (plan is String) return PlanTier.fromString(plan);

    return null;
  }
}
