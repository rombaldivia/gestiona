import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entitlements_repository.dart';
import '../data/user_bootstrapper.dart';
import '../domain/entitlements.dart';
import '../domain/plan_tier.dart';

final entitlementsRepositoryProvider = Provider<EntitlementsRepository>((ref) {
  return EntitlementsRepository();
});

// Provider por UID (String)
final entitlementsProvider = StreamProvider.family<Entitlements, String>((ref, uid) {
  const forcePro = bool.fromEnvironment('FORCE_PRO', defaultValue: false);

  if (forcePro) {
    final e = Entitlements.forTier(PlanTier.pro);
    debugPrint(
      '✅ entitlementsProvider FORCE_PRO=$forcePro uid=$uid tier=${e.tier} cloudSync=${e.cloudSync}',
    );
    return Stream.value(e);
  }

  // Fire-and-forget: si el user actual coincide con uid, asegura doc base
  final u = FirebaseAuth.instance.currentUser;
  if (u != null && u.uid == uid) {
    UserBootstrapper.ensureUserDoc(u);
  }

  final repo = ref.watch(entitlementsRepositoryProvider);
  return repo.watchUid(uid).map((e) {
    debugPrint(
      'ℹ️ entitlementsProvider FORCE_PRO=$forcePro uid=$uid tier=${e.tier} cloudSync=${e.cloudSync}',
    );
    return e;
  });
});
