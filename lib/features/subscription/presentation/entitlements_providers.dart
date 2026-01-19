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

/// family por uid (String) para que nadie le pase un User por error.
final entitlementsProvider = StreamProvider.family<Entitlements, String>((ref, uid) {
  const forcePro = bool.fromEnvironment('FORCE_PRO', defaultValue: false);

  if (forcePro) {
    final e = Entitlements.forTier(PlanTier.pro);
    debugPrint('✅ entitlementsProvider FORCE_PRO=$forcePro uid=$uid tier=${e.tier} cloudSync=${e.cloudSync}');
    return Stream.value(e);
  }

  final current = FirebaseAuth.instance.currentUser;

  // Si aún no hay sesión, es free.
  if (current == null) {
    final e = Entitlements.forTier(PlanTier.free);
    debugPrint('ℹ️ entitlementsProvider (no user) uid=$uid tier=${e.tier} cloudSync=${e.cloudSync}');
    return Stream.value(e);
  }

  // Fire-and-forget: asegura doc base
  UserBootstrapper.ensureUserDoc(current);

  final repo = ref.watch(entitlementsRepositoryProvider);
  return repo.watchUid(uid).map((e) {
    debugPrint('ℹ️ entitlementsProvider FORCE_PRO=$forcePro uid=$uid tier=${e.tier} cloudSync=${e.cloudSync}');
    return e;
  });
});
