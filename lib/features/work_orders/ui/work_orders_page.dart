import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/work_order.dart';
import '../domain/work_order_status.dart';
import '../presentation/work_orders_controller.dart';
import '../presentation/work_orders_state.dart';
import 'work_order_editor_page.dart';

class WorkOrdersPage extends ConsumerWidget {
  const WorkOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrdersControllerProvider);
    final ctrl  = ref.read(workOrdersControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Órdenes de trabajo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkOrderEditorPage(order: ctrl.newOrder()),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva OT'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (state) => _Body(state: state, ctrl: ctrl),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.ctrl});
  final WorkOrdersState state;
  final WorkOrdersController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = state.visible;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: ctrl.setQuery,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por cliente o número…',
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: [
              _Chip(label: 'Todas', selected: state.filterStatus == null,
                  color: AppColors.primary, onTap: () => ctrl.setFilter(null)),
              ...WorkOrderStatus.values.map((s) => _Chip(
                    label: s.label, selected: state.filterStatus == s,
                    color: s.color, onTap: () => ctrl.setFilter(s),
                  )),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.engineering_outlined, size: 56,
                          color: AppColors.primary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        state.filterStatus == null && state.query.isEmpty
                            ? 'No hay órdenes.\nToca + para crear la primera.'
                            : 'Sin resultados.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _OrderCard(order: orders[i], ctrl: ctrl),
                ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected,
      required this.color, required this.onTap});
  final String label; final bool selected;
  final Color color;  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label), selected: selected,
        selectedColor: color.withValues(alpha: 0.15),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
        side: BorderSide(color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1),
        backgroundColor: Colors.transparent,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order, required this.ctrl});
  final WorkOrder order; final WorkOrdersController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date    = DateTime.fromMillisecondsSinceEpoch(order.updatedAtMs);
    final dateStr = '${date.day.toString().padLeft(2,'0')}/'
        '${date.month.toString().padLeft(2,'0')}/${date.year}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorkOrderEditorPage(order: order))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('OT #${order.sequence}-${order.year}',
                    style: AppTextStyles.title.copyWith(fontSize: 15))),
                _StatusBadge(status: order.status),
              ]),
              if ((order.quoteTitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(order.quoteTitle!,
                    style: AppTextStyles.body.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 6),
              if ((order.customerName ?? '').isNotEmpty)
                Row(children: [
                  Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Expanded(child: Text(order.customerName!, style: AppTextStyles.body,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              if (order.quoteSequence != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.request_quote_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text('COT #${order.quoteSequence}-${order.year}',
                      style: AppTextStyles.label),
                ]),
              ],
              if (order.steps.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: order.progress, minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(order.status.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${order.steps.where((s) => s.completed).length}/${order.steps.length}',
                    style: AppTextStyles.label,
                  ),
                ]),
              ],
              const SizedBox(height: 8),
              Row(children: [
                if (order.members.isNotEmpty) ...[
                  Icon(Icons.group_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${order.members.length} persona${order.members.length != 1 ? 's' : ''}',
                      style: AppTextStyles.label),
                ],
                const Spacer(),
                Text(dateStr, style: AppTextStyles.label),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar orden'),
                          content: Text('¿Eliminar OT #${order.sequence}-${order.year}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar')),
                          ],
                        ),
                      );
                      if (ok == true) await ctrl.delete(order.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete',
                        child: Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final WorkOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
