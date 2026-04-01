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

// Plan efectivo: si es miembro observa el plan del dueño,
// si es dueño observa el suyo propio.
final entitlementsProvider = StreamProvider.family<Entitlements, String>((
  ref,
  uid,
) {
  const forcePro = bool.fromEnvironment('FORCE_PRO', defaultValue: false);

  if (forcePro) {
    final e = Entitlements.forTier(PlanTier.pro);
    debugPrint(
      '✅ entitlementsProvider FORCE_PRO=$forcePro uid=$uid tier=${e.tier}',
    );
    return Stream.value(e);
  }

  // Asegura doc base del usuario
  final u = FirebaseAuth.instance.currentUser;
  debugPrint(
    'AUTH currentUser uid=${u?.uid} anon=${u?.isAnonymous} targetUid=$uid',
  );
  if (u != null && u.uid == uid) {
    UserBootstrapper().ensureUserDoc(u);
  }

  final repo = ref.watch(entitlementsRepositoryProvider);
  return repo.watchEffective(uid).map((e) {
    debugPrint(
      'ℹ️ entitlementsProvider uid=$uid tier=${e.tier} cloudSync=${e.cloudSync}',
    );
    return e;
  });
});
