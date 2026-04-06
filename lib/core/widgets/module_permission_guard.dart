import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/company/presentation/member_permissions_helpers.dart';
import '../../features/company/presentation/member_permissions_providers.dart';

class ModulePermissionGuard extends ConsumerStatefulWidget {
  const ModulePermissionGuard({
    super.key,
    required this.moduleKey,
    required this.child,
    this.requireEdit = false,
    this.moduleLabel,
  });

  final String moduleKey;
  final Widget child;
  final bool requireEdit;
  final String? moduleLabel;

  @override
  ConsumerState<ModulePermissionGuard> createState() =>
      _ModulePermissionGuardState();
}

class _ModulePermissionGuardState extends ConsumerState<ModulePermissionGuard> {
  bool _handled = false;

  void _kickOut(String message) {
    if (_handled || !mounted) return;
    _handled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(currentMemberProvider);

    return memberAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) {
        _kickOut('No se pudieron verificar tus permisos.');
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      data: (member) {
        // Owner no necesariamente tiene doc en members; si member es null,
        // no bloqueamos aquí. Las rules mandan.
        if (member == null) {
          return widget.child;
        }

        final canView = canViewModule(member.permissions, widget.moduleKey);
        final canEdit = canEditModule(member.permissions, widget.moduleKey);

        if (!canView) {
          _kickOut(
            'No tienes permisos para entrar a ${widget.moduleLabel ?? widget.moduleKey}.',
          );
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (widget.requireEdit && !canEdit) {
          _kickOut(
            'No tienes permisos de edición en ${widget.moduleLabel ?? widget.moduleKey}.',
          );
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _handled = false;
        return widget.child;
      },
    );
  }
}
