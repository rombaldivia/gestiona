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

final entitlementsProvider = StreamProvider.family<Entitlements, User>((ref, user) {
  const forcePro = bool.fromEnvironment('FORCE_PRO', defaultValue: false);

  if (forcePro) {
    final e = Entitlements.forTier(PlanTier.pro);
    debugPrint('✅ entitlementsProvider FORCE_PRO=$forcePro uid=${user.uid} tier=${e.tier} cloudSync=${e.cloudSync}');
    return Stream.value(e);
  }

  // Fire-and-forget: garantiza doc base sin bloquear UI.
  UserBootstrapper.ensureUserDoc(user);

  final repo = ref.watch(entitlementsRepositoryProvider);
  return repo.watchFor(user).map((e) {
    debugPrint('ℹ️ entitlementsProvider FORCE_PRO=$forcePro uid=${user.uid} tier=${e.tier} cloudSync=${e.cloudSync}');
    return e;
  });
});
