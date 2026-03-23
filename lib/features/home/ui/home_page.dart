import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/activity/activity_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../gemini/ui/gemini_chat_page.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../inventory/ui/inventory_item_form_page.dart';
import '../../inventory/ui/inventory_page.dart';
import '../../quotes/domain/quote_status.dart';
import '../../quotes/presentation/quotes_controller.dart';
import '../../quotes/ui/quote_editor_page.dart';
import '../../quotes/ui/quotes_tabs_page.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../../work_orders/presentation/work_orders_controller.dart';
import '../../work_orders/ui/work_order_editor_page.dart';
import '../../work_orders/ui/work_orders_page.dart';
import '../../sales/ui/sales_page.dart';
import '../../sales/ui/sale_editor_page.dart';
import '../../sales/presentation/sales_controller.dart';

class HomePage extends ConsumerWidget {
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

  void _openActivityTarget(
    BuildContext context,
    ActivityEvent event, {
    required List<dynamic> quotes,
    required List<dynamic> orders,
    required List<dynamic> items,
    required bool proCloud,
  }) {
    final entityId = (event.entityId ?? '').trim();
    if (entityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este evento es antiguo y no tiene acceso directo.'),
        ),
      );
      return;
    }

    switch (event.module) {
      case ActivityModule.quote:
        dynamic q;
        for (final e in quotes) {
          if (e.id == entityId) {
            q = e;
            break;
          }
        }
        if (q != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => QuoteEditorPage(quote: q)),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la cotización exacta.'),
          ),
        );
        return;

      case ActivityModule.workOrder:
        dynamic wo;
        for (final e in orders) {
          if (e.id == entityId) {
            wo = e;
            break;
          }
        }
        if (wo != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WorkOrderEditorPage(order: wo)),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró la orden de trabajo exacta.'),
          ),
        );
        return;

      case ActivityModule.inventory:
        dynamic item;
        for (final e in items) {
          if (e.id == entityId) {
            item = e;
            break;
          }
        }
        if (item != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InventoryItemFormPage(
                initial: item,
                proCloud: proCloud,
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró el artículo exacto de inventario.'),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent     = EntitlementsScope.of(context);
    final company = CompanyScope.of(context);

    // Datos reales
    final quotes = ref.watch(quotesControllerProvider).value?.quotes ?? [];
    final orders = ref.watch(workOrdersControllerProvider).value?.orders ?? [];
    final items  = ref.watch(inventoryItemsProvider);

    final events = ref.watch(activityProvider).value ?? [];

// TEMP: limpiar actividad vieja con labels rotos
// ref.read(activityProvider.notifier).clear().ignore();

    final recentActivity = events.take(8).toList();

    // Resumen de cotizaciones
    final qDraft    = quotes.where((q) => q.status == QuoteStatus.draft).length;
    final qSent     = quotes.where((q) => q.status == QuoteStatus.sent).length;
    final qAccepted = quotes.where((q) => q.status == QuoteStatus.accepted).length;

    // OTs pendientes/en progreso
    final oActive = orders.where((o) =>
        o.status.name == 'pending' || o.status.name == 'inProgress').length;
    final oLate   = orders.where((o) {
      if (o.deliveryAtMs == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(o.deliveryAtMs!)
          .isBefore(DateTime.now()) &&
          o.status.name != 'done' && o.status.name != 'delivered';
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(company.companyName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'edit_company') {
                await onEditCompanyName();
              } else if (v == 'sync') {
                if (!ent.cloudSync) { _todo(context, 'Sync (requiere Pro)'); return; }
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(const SnackBar(content: Text('Sincronizando...')));
                try {
                  await onSyncPressed();
                  messenger.showSnackBar(const SnackBar(content: Text('Sync OK ✅')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Sync falló: $e')));
                }
              } else if (v == 'logout') {
                await _signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit_company', child: Text('Editar empresa')),
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

      extendBody: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GeminiChatPage()),
        ),
        backgroundColor: const Color(0xFF1565C0),
        icon:  const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Asistente IA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [

          // ── Barra de estado ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
              child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ent.cloudSync ? AppColors.success : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 8),
              Text(ent.cloudSync ? 'Sincronización activa' : 'Modo local',
                  style: AppTextStyles.label),
              const Spacer(),
              Text(_todayString(), style: AppTextStyles.label),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Resumen rápido ────────────────────────────────────────────────
          Row(children: [
            _SummaryChip(label: '$qDraft borradores',   color: AppColors.textSecondary),
            const SizedBox(width: 8),
            _SummaryChip(label: '$qSent enviadas',      color: AppColors.quotes),
            const SizedBox(width: 8),
            _SummaryChip(label: '$qAccepted aceptadas', color: AppColors.success),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _SummaryChip(label: '$oActive OTs activas',  color: AppColors.workOrders),
            if (oLate > 0) ...[
              const SizedBox(width: 8),
              _SummaryChip(label: '$oLate atrasadas', color: Colors.redAccent),
            ],
          ]),

          const SizedBox(height: 16),

          _FeaturedSalesCard(
            onNewSale: () async {
              final draft = await ref.read(salesControllerProvider.notifier).newDraft();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SaleEditorPage(sale: draft)),
              );
            },
            onViewSales: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SalesPage()),
              );
            },
          ),

          const SizedBox(height: 18),

          // ── Grid de módulos ───────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _ModuleCard(
                color: AppColors.quotes,
                icon: Icons.request_quote_outlined,
                title: 'Cotizaciones',
                subtitle: '${quotes.length} total',
                buttonText: 'Abrir',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuotesTabsPage())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleCard(
                color: AppColors.workOrders,
                icon: Icons.engineering_outlined,
                title: 'Órdenes de trabajo',
                subtitle: '$oActive activas',
                buttonText: 'Abrir',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorkOrdersPage())),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: _ModuleCard(
                color: AppColors.inventory,
                icon: Icons.inventory_2_outlined,
                title: 'Inventario',
                subtitle: 'Stock y movimientos',
                buttonText: 'Abrir',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InventoryPage())),
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
          ]),

          const SizedBox(height: 20),

          // ── Actividad reciente ────────────────────────────────────────────
          Text('Actividad reciente',
              style: AppTextStyles.title.copyWith(fontSize: 15)),
          const SizedBox(height: 10),

          if (recentActivity.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text('Sin actividad todavía', style: AppTextStyles.label),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < recentActivity.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _ActivityEventItem(
                      event: recentActivity[i],
                      isLast: i == recentActivity.length - 1,
                      onTap: () => _openActivityTarget(
                        context,
                        recentActivity[i],
                        quotes: quotes,
                        orders: orders,
                        items: items,
                        proCloud: ent.cloudSync,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _todayString() {
    final now = DateTime.now();
    const months = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${now.day} ${months[now.month]}';
  }
}

// ── Chip de resumen ───────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTextStyles.label.copyWith(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

// ── Card destacada de ventas ──────────────────────────────────────────────────
class _FeaturedSalesCard extends StatelessWidget {
  const _FeaturedSalesCard({
    required this.onNewSale,
    required this.onViewSales,
  });

  final VoidCallback onNewSale;
  final VoidCallback onViewSales;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ventas',
                      style: AppTextStyles.title.copyWith(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registra una venta directa en segundos',
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  'Gratis',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Ideal para mostrador, ventas rápidas y registro inmediato de productos o servicios.',
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SalesFeatureChip(
                icon: Icons.inventory_2_outlined,
                label: 'Actualiza stock',
              ),
              _SalesFeatureChip(
                icon: Icons.person_outline,
                label: 'Cliente opcional',
              ),
              _SalesFeatureChip(
                icon: Icons.flash_on_outlined,
                label: 'Flujo rápido',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onNewSale,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Nueva venta'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewSales,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ver ventas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesFeatureChip extends StatelessWidget {
  const _SalesFeatureChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de módulo ─────────────────────────────────────────────────────────
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.color, required this.icon, required this.title,
    required this.subtitle, required this.buttonText, required this.onPressed,
  });
  final Color color; final IconData icon;
  final String title, subtitle, buttonText;
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
                style: AppTextStyles.title.copyWith(fontSize: 13, color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.label.copyWith(
                    color: color.withValues(alpha: 0.65), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(buttonText,
                  style: AppTextStyles.label.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        ),
    );
  }
}


// ── Ítem de evento real ───────────────────────────────────────────────────────
class _ActivityEventItem extends StatelessWidget {
  const _ActivityEventItem({
    required this.event,
    this.isLast = false,
    this.onTap,
  });

  final ActivityEvent event;
  final bool isLast;
  final VoidCallback? onTap;

  Color get _moduleColor {
    switch (event.module) {
      case ActivityModule.quote:
        return AppColors.quotes;
      case ActivityModule.workOrder:
        return AppColors.workOrders;
      case ActivityModule.inventory:
        return AppColors.inventory;
    }
  }

  IconData get _icon {
    switch (event.module) {
      case ActivityModule.quote:
        return Icons.request_quote_outlined;
      case ActivityModule.workOrder:
        return Icons.engineering_outlined;
      case ActivityModule.inventory:
        switch (event.verb) {
          case ActivityVerb.stockIn:
            return Icons.arrow_downward_rounded;
          case ActivityVerb.stockOut:
            return Icons.arrow_upward_rounded;
          case ActivityVerb.deleted:
            return Icons.delete_outline;
          default:
            return Icons.inventory_2_outlined;
        }
    }
  }

  String get _verbLabel {
    switch (event.verb) {
      case ActivityVerb.created:
        return 'creado';
      case ActivityVerb.updated:
        return 'actualizado';
      case ActivityVerb.deleted:
        return 'eliminado';
      case ActivityVerb.stockIn:
        return 'entrada';
      case ActivityVerb.stockOut:
        return 'salida';
    }
  }

  String _fmtTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _moduleColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.md),
                    bottomLeft: Radius.circular(AppRadius.md),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(_icon, color: color, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    event.label,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    _verbLabel,
                                    style: AppTextStyles.label.copyWith(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (event.detail.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                event.detail,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              _fmtTime(event.createdAtMs),
                              style: AppTextStyles.label.copyWith(
                                color: color.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
