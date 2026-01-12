import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_service.dart';
import '../../home/ui/home_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import 'company_providers.dart';
import 'company_scope.dart';

class CompanyGate extends ConsumerWidget {
  const CompanyGate({super.key, required this.auth, required this.user});

  final AuthService auth;
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCompany = ref.watch(companyControllerProvider);

    return asyncCompany.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error cargando empresa: $e'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(companyControllerProvider.notifier).reload(),
                  child: const Text('Reintentar'),
                )
              ],
            ),
          ),
        ),
      ),
      data: (company) {
        final ent = EntitlementsScope.of(context);
        final ctrl = ref.read(companyControllerProvider.notifier);

        Future<void> editCompanyName() async {
          final current = company.companyName ?? '';
          final controller = TextEditingController(text: current);

          final newName = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Editar nombre de empresa'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Hermenca',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final v = controller.text.trim();
                    Navigator.pop(context, v.isEmpty ? null : v);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );

          if (newName == null) return;

          await ctrl.renameActiveCompany(newName: newName, ent: ent);
        }

        if (!company.hasCompany) {
          return _CreateCompanyInline(
            onCreate: (name) => ctrl.createCompany(name: name, ent: ent),
          );
        }

        return CompanyScope(
          companyId: company.companyId!,
          companyName: company.companyName!,
          child: HomePage(
            auth: auth,
            user: user,
            onSyncPressed: () => ctrl.syncNow(ent: ent),
            onEditCompanyName: editCompanyName,
          ),
        );
      },
    );
  }
}

class _CreateCompanyInline extends StatefulWidget {
  const _CreateCompanyInline({required this.onCreate});

  final Future<void> Function(String name) onCreate;

  @override
  State<_CreateCompanyInline> createState() => _CreateCompanyInlineState();
}

class _CreateCompanyInlineState extends State<_CreateCompanyInline> {
  final _c = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _c.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await widget.onCreate(name);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear empresa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _c,
              decoration: const InputDecoration(
                labelText: 'Nombre de la empresa',
                hintText: 'Ej: Hermenca',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Creando...' : 'Crear'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
