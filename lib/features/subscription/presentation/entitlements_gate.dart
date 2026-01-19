import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entitlements.dart';
import 'entitlements_providers.dart';

typedef EntitlementsWidgetBuilder = Widget Function(
  BuildContext context,
  Entitlements entitlements,
  Widget child,
);

class EntitlementsGate extends ConsumerWidget {
  const EntitlementsGate({
    super.key,
    this.user,
    this.builder,
    required this.child,
  });

  /// Si alguna vez quieres forzar builder (como tu versión anterior),
  /// usa esta factory.
  factory EntitlementsGate.compat({
    Key? key,
    User? user,
    required Widget child,
    required EntitlementsWidgetBuilder builder,
  }) {
    return EntitlementsGate(
      key: key,
      user: user,
      builder: builder,
      child: child,
    );
  }

  final User? user;
  final Widget child;
  final EntitlementsWidgetBuilder? builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user ?? FirebaseAuth.instance.currentUser;
    if (u == null) return child;

    final entAsync = ref.watch(entitlementsProvider(u.uid));

    // Si no hay builder, solo “toca” el provider y devuelve el child.
    final b = builder;
    if (b == null) {
      return entAsync.when(
        data: (_) => child,
        loading: () => child,
        error: (err, st) => child,
      );
    }

    return entAsync.when(
      data: (e) => b(context, e, child),
      loading: () => child,
      error: (err, st) => child,
    );
  }
}
