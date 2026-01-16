import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entitlements_scope.dart';
import 'entitlements_providers.dart';

class EntitlementsGate extends ConsumerWidget {
  const EntitlementsGate({super.key, required this.user, required this.child});

  final User user;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entAsync = ref.watch(entitlementsProvider(user));

    return entAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error cargando plan: $e'),
          ),
        ),
      ),
      data: (entitlements) {
        return EntitlementsScope(entitlements: entitlements, child: child);
      },
    );
  }
}
