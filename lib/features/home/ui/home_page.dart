import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/data/auth_service.dart';
import '../../subscription/presentation/entitlements_scope.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.auth,
    required this.companyId,
  });

  final AuthService auth;
  final String companyId;

  Future<void> _signOut() async {
    // Intentamos usar AuthService si tiene método signOut/logout
    // y si no, fallback a FirebaseAuth.
    try {
      final dyn = auth as dynamic;
      try {
        await dyn.signOut();
        return;
      } catch (_) {}
      try {
        await dyn.logout();
        return;
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
  }

  String _friendlyCompanyName() {
    if (companyId == 'local-default') return 'Empresa local';
    if (companyId == 'default') return 'Empresa';
    return 'Empresa ($companyId)';
  }

  @override
  Widget build(BuildContext context) {
    final ent = EntitlementsScope.of(context);
    final user = FirebaseAuth.instance.currentUser;

    final companyName = _friendlyCompanyName();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestiona'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola${(user?.email?.isNotEmpty ?? false) ? ', ${user!.email}' : ''}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Todo listo para trabajar.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Card: Empresa activa
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.business_center_outlined, size: 26),
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
                          Text(companyName),
                          const SizedBox(height: 6),
                          Text(
                            'ID: $companyId',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(ent.cloudSync ? 'Sync' : 'Local'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Card: Plan
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
                        Chip(
                          label: Text(ent.tier.asString.toUpperCase()),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(ent.cloudSync ? 'Nube activada' : 'Solo local'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Empresas: ${ent.maxCompanies == 999999 ? 'ilimitadas' : ent.maxCompanies}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ent.cloudSync
                          ? 'Tus datos pueden sincronizarse entre dispositivos.'
                          : 'Estás en modo local. Plus habilita nube y multi-dispositivo.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),

            // CTA Upgrade (solo Free)
            if (!ent.cloudSync) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Activá la nube',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Sincronizá y respaldá tus datos con Plus.',
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Plus / Pro'),
                              content: const Text(
                                'Todavía no están activados los pagos.\n'
                                'Cuando estén listos, esto habilitará sincronización y multi-dispositivo.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text('Ver planes'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            Text(
              'Acciones rápidas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),

            // Grid de acciones
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionCard(
                  title: 'Cotizaciones',
                  subtitle: 'Crear y enviar',
                  icon: Icons.request_quote_outlined,
                  onTap: () => _soon(context),
                ),
                _ActionCard(
                  title: 'Ventas',
                  subtitle: 'Registrar venta',
                  icon: Icons.point_of_sale_outlined,
                  onTap: () => _soon(context),
                ),
                _ActionCard(
                  title: 'Inventario',
                  subtitle: 'Stock y compras',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => _soon(context),
                ),
                _ActionCard(
                  title: 'Producción',
                  subtitle: 'Órdenes y estado',
                  icon: Icons.precision_manufacturing_outlined,
                  onTap: () => _soon(context),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Estado simple
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sesión iniciada ✅',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Próximamente 🙂')),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
