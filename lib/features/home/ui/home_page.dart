import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../../inventory/ui/inventory_page.dart';
import '../../quotes/ui/quotes_tabs_page.dart';
import '../../work_orders/ui/work_orders_page.dart';

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

  Future<void> _signOut() async => auth.signOut();

  void _todo(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label (próximamente)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ent     = EntitlementsScope.of(context);
    final company = CompanyScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          company.companyName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: () => _todo(context, 'Notificaciones'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'edit_company') {
                await onEditCompanyName();
              } else if (v == 'sync') {
                if (!ent.cloudSync) {
                  _todo(context, 'Sync (requiere Pro)');
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Sincronizando...')),
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
              } else if (v == 'logout') {
                await _signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit_company', child: Text('Editar empresa')),
              PopupMenuItem(
                value: 'sync',
                enabled: ent.cloudSync,
                child: Text(ent.cloudSync ? 'Sync ahora' : 'Sync (Pro)'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Modo de sync
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ent.cloudSync
                        ? AppColors.success
                        : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ent.cloudSync ? 'Sincronización activa' : 'Modo local',
                  style: AppTextStyles.label,
                ),
                const Spacer(),
                Text(
                  _todayString(),
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Grid de módulos
          Row(
            children: [
              Expanded(
                child: _ModuleCard(
                  color: AppColors.quotes,
                  icon: Icons.request_quote_outlined,
                  title: 'Cotizaciones',
                  subtitle: 'Presupuestos y ventas',
                  buttonText: 'Abrir',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const QuotesTabsPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModuleCard(
                  color: AppColors.workOrders,
                  icon: Icons.engineering_outlined,
                  title: 'Órdenes de trabajo',
                  subtitle: 'Producción',
                  buttonText: 'Abrir',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WorkOrdersPage()),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _ModuleCard(
                  color: AppColors.inventory,
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventario',
                  subtitle: 'Stock y movimientos',
                  buttonText: 'Abrir',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InventoryPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModuleCard(
                  color: AppColors.billing,
                  icon: Icons.receipt_long_outlined,
                  title: 'Facturación',
                  subtitle: 'Cobros e impuestos',
                  buttonText: 'Abrir',
                  onPressed: () => _todo(context, 'Facturación'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Actividad reciente
          Text('Actividad reciente',
              style: AppTextStyles.title.copyWith(fontSize: 15)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: const Column(
              children: [
                _ActivityItem(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  title: 'COT-1023 aprobada',
                  subtitle: '09:30 · Cotizaciones',
                ),
                Divider(height: 1),
                _ActivityItem(
                  icon: Icons.build_circle_outlined,
                  color: AppColors.workOrders,
                  title: 'OT-231 en producción',
                  subtitle: '09:50 · Órdenes de trabajo',
                ),
                Divider(height: 1),
                _ActivityItem(
                  icon: Icons.payments_outlined,
                  color: AppColors.billing,
                  title: 'FAC-2010 pagada',
                  subtitle: '10:15 · Facturación',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _todayString() {
    final now = DateTime.now();
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${now.day} ${months[now.month]}';
  }
}

// ── Tarjeta de módulo ─────────────────────────────────────────────────────────
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
  
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: AppTextStyles.title.copyWith(
                    fontSize: 13, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.label.copyWith(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(buttonText,
                  style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ítem de actividad ─────────────────────────────────────────────────────────
class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(subtitle, style: AppTextStyles.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
