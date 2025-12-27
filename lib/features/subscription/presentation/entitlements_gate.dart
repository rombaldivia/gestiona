import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/entitlements_repository.dart';
import '../data/user_bootstrapper.dart';
import 'entitlements_scope.dart';

class EntitlementsGate extends StatefulWidget {
  const EntitlementsGate({super.key, required this.user, required this.child});

  final User user;
  final Widget child;

  @override
  State<EntitlementsGate> createState() => _EntitlementsGateState();
}

class _EntitlementsGateState extends State<EntitlementsGate> {
  late final EntitlementsRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = EntitlementsRepository();
    UserBootstrapper.ensureUserDoc(widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _repo.watchFor(widget.user),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting || !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return EntitlementsScope(entitlements: snap.data!, child: widget.child);
      },
    );
  }
}
