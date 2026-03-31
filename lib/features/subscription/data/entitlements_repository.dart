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

  Stream<Entitlements> watchFor(User user) {
    return watchUid(user.uid);
  }

  // Compatibilidad con código viejo
  Stream<Entitlements> watchEffective(String uid) {
    return watchUid(uid);
  }

  Stream<Entitlements> watchUid(String uid) {
    final controller = StreamController<Entitlements>.broadcast();

    PlanTier? docTier;
    PlanTier? claimsTier;

    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? planSub;
    StreamSubscription<User?>? tokenSub;

    String? boundPlanUid;

    void emit() {
      final tier = docTier ?? claimsTier ?? PlanTier.free;
      controller.add(Entitlements.forTier(tier));
    }

    Future<void> bindPlanDoc(String sourceUid) async {
      if (boundPlanUid == sourceUid && planSub != null) return;
      boundPlanUid = sourceUid;

      await planSub?.cancel();
      planSub = _db.collection('users').doc(sourceUid).snapshots().listen((
        snap,
      ) {
        final data = snap.data();
        docTier = PlanTier.fromString(data?['plan'] as String?);
        emit();
      }, onError: controller.addError);
    }

    userSub = _db.collection('users').doc(uid).snapshots().listen((snap) async {
      final data = snap.data() ?? <String, dynamic>{};
      final activeCompanyOwnerUid =
          (data['activeCompanyOwnerUid'] as String? ?? '').trim();

      final sourceUid = activeCompanyOwnerUid.isNotEmpty
          ? activeCompanyOwnerUid
          : uid;

      await bindPlanDoc(sourceUid);
    }, onError: controller.addError);

    tokenSub = _auth.idTokenChanges().listen((u) async {
      if (u == null || u.uid != uid) return;
      try {
        claimsTier = await _tierFromClaims(u);
      } catch (_) {
        claimsTier = null;
      }
      emit();
    }, onError: controller.addError);

    () async {
      try {
        final current = _auth.currentUser;
        if (current != null && current.uid == uid) {
          claimsTier = await _tierFromClaims(current);
        }
      } catch (_) {
        claimsTier = null;
      }
      emit();
    }();

    controller.onCancel = () async {
      await userSub?.cancel();
      await planSub?.cancel();
      await tokenSub?.cancel();
      await controller.close();
    };

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
