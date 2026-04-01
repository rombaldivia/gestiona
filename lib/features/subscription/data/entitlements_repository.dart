import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../company/data/company_local_store.dart';
import '../domain/entitlements.dart';
import '../domain/plan_tier.dart';

class EntitlementsRepository {
  EntitlementsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    CompanyLocalStore? localStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = db ?? FirebaseFirestore.instance,
       _local = localStore ?? CompanyLocalStore();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final CompanyLocalStore _local;

  Stream<Entitlements> watchFor(User user) => watchUid(user.uid);
  Stream<Entitlements> watchEffective(String uid) => watchUid(uid);

  Stream<Entitlements> watchUid(String uid) async* {
    final current = _auth.currentUser;

    if (current != null && current.uid == uid) {
      if (current.isAnonymous) {
        final local = await _local.getActiveCompany(uid: uid);
        if (local != null) {
          yield Entitlements.forTier(PlanTier.pro);
          return;
        }
      }

      try {
        final userSnap = await _db.collection('users').doc(uid).get();
        final userTier = PlanTier.fromString(
          userSnap.data()?['plan'] as String?,
        );
        if (userTier != PlanTier.free) {
          yield Entitlements.forTier(userTier);
          return;
        }
      } catch (_) {}
    }

    yield Entitlements.forTier(PlanTier.free);
  }
}
