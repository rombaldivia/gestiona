import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entitlements.dart';
import '../domain/plan_tier.dart';
import 'entitlements_providers.dart';
import 'entitlements_scope.dart';

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

    // ✅ Si no hay builder, IGUAL proveemos EntitlementsScope al resto de la app.
    final b = builder;
    if (b == null) {
      return entAsync.when(
        data: (e) => EntitlementsScope(entitlements: e, child: child),
        loading: () => EntitlementsScope(
          entitlements: Entitlements.forTier(PlanTier.free),
          child: child,
        ),
        error: (err, st) => EntitlementsScope(
          entitlements: Entitlements.forTier(PlanTier.free),
          child: child,
        ),
      );
    }

    // ✅ Si hay builder, también envolvemos con scope (por consistencia).
    return entAsync.when(
      data: (e) => EntitlementsScope(
        entitlements: e,
        child: b(context, e, child),
      ),
      loading: () => EntitlementsScope(
        entitlements: Entitlements.forTier(PlanTier.free),
        child: child,
      ),
      error: (err, st) => EntitlementsScope(
        entitlements: Entitlements.forTier(PlanTier.free),
        child: child,
      ),
    );
  }
}
