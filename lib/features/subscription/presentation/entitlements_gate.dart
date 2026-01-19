import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entitlements.dart';
import 'entitlements_providers.dart';

class EntitlementsGate extends ConsumerWidget {
  /// ✅ NUEVO: modo "builder"
  const EntitlementsGate({
    super.key,
    required this.builder,
    this.loading,
    this.user, // compat (no se usa si builder está)
    this.child, // compat (no se usa si builder está)
  });

  /// (Compat) antes quizá se pasaba el User, pero ahora se usa uid internamente.
  final User? user;

  /// (Compat) antes quizá se pasaba child directo.
  final Widget? child;

  /// ✅ NUEVO recomendado
  final Widget Function(BuildContext context, Entitlements entitlements) builder;

  final Widget? loading;

  /// ✅ Constructor compat: permite EntitlementsGate(user: ..., child: ...)
  factory EntitlementsGate.compat({
    Key? key,
    required User user,
    required Widget child,
    Widget? loading,
  }) {
    return EntitlementsGate(
      key: key,
      user: user,
      child: child,
      loading: loading,
      builder: (context, entitlements) => child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si nos pasaron user explícito, lo usamos; si no, usamos el currentUser
    final u = user ?? FirebaseAuth.instance.currentUser;
    final uid = u?.uid;

    if (uid == null) {
      return loading ??
          const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final entAsync = ref.watch(entitlementsProvider(uid));
    return entAsync.when(
      data: (e) => builder(context, e),
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (err, st) =>
          loading ?? const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
