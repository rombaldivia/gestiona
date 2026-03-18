import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../company/presentation/company_scope.dart';
import '../../subscription/presentation/entitlements_scope.dart';
import '../../inventory/ui/inventory_page.dart';
import '../../quotes/domain/quote_status.dart';
import '../../quotes/presentation/quotes_controller.dart';
import '../../quotes/ui/quotes_tabs_page.dart';
import '../../work_orders/presentation/work_orders_controller.dart';
import '../../work_orders/ui/work_orders_page.dart';
import '../../gemini/ui/gemini_chat_page.dart';
import '../../../core/activity/activity_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent     = EntitlementsScope.of(context);
    final company = CompanyScope.of(context);

    // Datos reales
    final quotes = ref.watch(quotesControllerProvider).value?.quotes ?? [];
    final orders = ref.watch(workOrdersControllerProvider).value?.orders ?? [];

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
                      event:  recentActivity[i],
                      isLast: i == recentActivity.length - 1,
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
  const _ActivityEventItem({required this.event, this.isLast = false});
  final ActivityEvent event;
  final bool isLast;

  Color get _color {
    switch (event.module) {
      case ActivityModule.quote:     return AppColors.quotes;
      case ActivityModule.workOrder: return AppColors.workOrders;
      case ActivityModule.inventory: return AppColors.inventory;
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
          case ActivityVerb.stockIn:  return Icons.arrow_downward_rounded;
          case ActivityVerb.stockOut: return Icons.arrow_upward_rounded;
          case ActivityVerb.deleted:  return Icons.delete_outline;
          default:                    return Icons.inventory_2_outlined;
        }
    }
  }

  String get _verbLabel {
    switch (event.verb) {
      case ActivityVerb.created:  return 'creado';
      case ActivityVerb.updated:  return 'actualizado';
      case ActivityVerb.deleted:  return 'eliminado';
      case ActivityVerb.stockIn:  return 'entrada';
      case ActivityVerb.stockOut: return 'salida';
    }
  }

  String _fmtTime(int ms) {
    final d    = DateTime.fromMillisecondsSinceEpoch(ms);
    final now  = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1)  return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'hace ${diff.inHours}h';
    if (diff.inDays == 1)    return 'ayer';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(_icon, color: color, size: 18),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.label,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (event.detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            event.detail,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _fmtTime(event.createdAtMs),
                          style: AppTextStyles.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _verbLabel,
                      style: AppTextStyles.label.copyWith(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
// ── Ítem de actividad ─────────────────────────────────────────────────────────
