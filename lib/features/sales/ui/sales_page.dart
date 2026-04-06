import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/module_permission_guard.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/sale.dart';
import '../domain/sale_status.dart';
import '../presentation/sales_controller.dart';
import 'sale_editor_page.dart';

class SalesPage extends ConsumerWidget {
  const SalesPage({super.key});

  Future<void> _newSale(BuildContext context, WidgetRef ref) async {
    final draft = await ref.read(salesControllerProvider.notifier).newDraft();
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SaleEditorPage(sale: draft)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(salesControllerProvider);

    return asyncState.when(
      loading: () => ModulePermissionGuard(
        moduleKey: 'sales',
        moduleLabel: 'Ventas',
        child: Scaffold(
          appBar: AppBar(title: const Text('Ventas')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => ModulePermissionGuard(
        moduleKey: 'sales',
        moduleLabel: 'Ventas',
        child: Scaffold(
          appBar: AppBar(title: const Text('Ventas')),
          body: Center(child: Text('Error: $e')),
        ),
      ),
      data: (state) {
        final sales = state.visible;

        return ModulePermissionGuard(
          moduleKey: 'sales',
          moduleLabel: 'Ventas',
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Ventas'),
              actions: [
                IconButton(
                  tooltip: 'Nueva venta',
                  onPressed: () => _newSale(context, ref),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _newSale(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nueva venta'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                TextField(
                  onChanged: ref
                      .read(salesControllerProvider.notifier)
                      .setQuery,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por cliente, NIT/CI o número...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: state.filterStatus == null,
                      onTap: () => ref
                          .read(salesControllerProvider.notifier)
                          .setFilter(null),
                    ),
                    for (final status in SaleStatus.values)
                      _FilterChip(
                        label: status.label,
                        selected: state.filterStatus == status,
                        onTap: () => ref
                            .read(salesControllerProvider.notifier)
                            .setFilter(status),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (sales.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.point_of_sale_rounded, size: 44),
                        const SizedBox(height: 10),
                        Text(
                          'Todavía no hay ventas',
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crea tu primera venta desde aquí.',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _newSale(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva venta'),
                        ),
                      ],
                    ),
                  )
                else
                  ...sales.map(
                    (sale) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SaleCard(sale: sale),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SaleCard extends ConsumerWidget {
  const _SaleCard({required this.sale});

  final Sale sale;

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SaleEditorPage(sale: sale)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sale.numberLabel,
                    style: AppTextStyles.title.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sale.customerNameOrBusinessName?.trim().isNotEmpty == true
                        ? sale.customerNameOrBusinessName!
                        : 'Cliente sin nombre',
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                          if ((sale.documentType?.label ?? '').isNotEmpty)
                            sale.documentType!.label,
                          if ((sale.documentNumber ?? '').trim().isNotEmpty)
                            sale.documentNumber!.trim(),
                        ].join(' · ').isEmpty
                        ? 'Sin documento'
                        : [
                            if ((sale.documentType?.label ?? '').isNotEmpty)
                              sale.documentType!.label,
                            if ((sale.documentNumber ?? '').trim().isNotEmpty)
                              sale.documentNumber!.trim(),
                          ].join(' · '),
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status: sale.status),
                const SizedBox(height: 8),
                Text(
                  'Bs ${_fmt(sale.totalBob)}',
                  style: AppTextStyles.title.copyWith(fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SaleStatus.draft => AppColors.warning,
      SaleStatus.completed => AppColors.success,
      SaleStatus.cancelled => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.label.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
    );
  }
}
