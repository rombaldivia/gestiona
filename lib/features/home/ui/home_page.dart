import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../subscription/presentation/entitlements_scope.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.auth,
    required this.user,
    required this.onSyncPressed,
    required this.onEditCompanyName,
  });

  final AuthService auth;
  final User user;
  final Future<void> Function() onSyncPressed;
  final Future<void> Function() onEditCompanyName;

  Future<void> _signOut() async {
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);
    final company = CompanyScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestiona'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
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
                        const Text(
                          'Empresa activa',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(company.companyName),
                        const SizedBox(height: 6),
                        Text(
                          'ID: ${company.companyId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Chip(label: Text(ent.cloudSync ? 'Sync' : 'Local')),
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
                  const Text(
                    'Plan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(label: Text(ent.tier.asString.toUpperCase())),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          ent.cloudSync ? 'Nube activada' : 'Solo local',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ✅ BOTÓN EDITAR NOMBRE
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onEditCompanyName,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar nombre de empresa'),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ BOTÓN SYNC REAL (sin usar context después del await)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: ent.cloudSync
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);

                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Sincronizando...'),
                                ),
                              );

                              try {
                                await onSyncPressed();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Sync OK ✅')),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Sync falló: $e')),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.cloud_sync),
                      label: Text(
                        ent.cloudSync
                            ? 'Sync ahora'
                            : 'Sync (requiere Plus/Pro)',
                      ),
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
