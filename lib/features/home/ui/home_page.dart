import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../company/data/company_offline_first_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../company/ui/edit_company_name_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.auth,
    required this.user,
    required this.onSyncPressed,
  });

  final AuthService auth;
  final User user;
  final Future<void> Function() onSyncPressed;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _companyId;
  String? _companyName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final company = CompanyScope.of(context);
    _companyId ??= company.companyId;
    _companyName ??= company.companyName;
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
  }

  Future<void> _editCompanyName() async {
    final currentName = _companyName ?? CompanyScope.of(context).companyName;

    final newName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditCompanyNamePage(initialName: currentName),
      ),
    );

    if (newName == null) return;
    if (!mounted) return;

    final ent = EntitlementsScope.of(context);

    try {
      final svc = CompanyOfflineFirstService();
      await svc.renameActiveCompanyOfflineFirst(newName: newName, ent: ent);

      if (!mounted) return;

      setState(() {
        _companyName = newName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre actualizado ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);
    final company = CompanyScope.of(context);

    final companyId = _companyId ?? company.companyId;
    final companyName = _companyName ?? company.companyName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestiona'),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.apartment, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Empresa activa', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(companyName),
                        const SizedBox(height: 6),
                        Text('ID: $companyId', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Chip(label: Text(ent.cloudSync ? 'Sync' : 'Local')),
                      const SizedBox(height: 8),
                      IconButton(
                        tooltip: 'Editar nombre',
                        icon: const Icon(Icons.edit),
                        onPressed: _editCompanyName,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plan', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(label: Text(ent.tier.asString.toUpperCase())),
                      const SizedBox(width: 8),
                      Chip(label: Text(ent.cloudSync ? 'Nube activada' : 'Solo local')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: ent.cloudSync
                          ? () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sincronizando...')),
                              );
                              try {
                                await widget.onSyncPressed();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sync OK ✅')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sync falló: $e')),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.cloud_sync),
                      label: Text(ent.cloudSync ? 'Sync ahora' : 'Sync (requiere Plus/Pro)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
