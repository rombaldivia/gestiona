import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entitlements_repository.dart';
import '../data/user_bootstrapper.dart';
import '../domain/entitlements.dart';

final entitlementsRepositoryProvider = Provider<EntitlementsRepository>((ref) {
  return EntitlementsRepository();
});

/// Entitlements por usuario.
///
/// Nota: también asegura (best-effort) que exista el documento `/users/{uid}`.
final entitlementsProvider = StreamProvider.family<Entitlements, User>((ref, user) {
  // Fire-and-forget: garantiza doc base sin bloquear UI.
  UserBootstrapper.ensureUserDoc(user);

  final repo = ref.watch(entitlementsRepositoryProvider);
  return repo.watchFor(user);
});
