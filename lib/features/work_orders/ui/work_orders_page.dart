import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/module_permission_guard.dart';
import '../../../features/company/presentation/member_permissions_helpers.dart';
import '../../../features/company/presentation/member_permissions_providers.dart';

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
    final ctrl = ref.read(workOrdersControllerProvider.notifier);

    final member = ref.watch(currentMemberProvider).asData?.value;
    final canEdit =
        member == null || canEditModule(member.permissions, 'workOrders');

    return ModulePermissionGuard(
      moduleKey: 'workOrders',
      moduleLabel: 'Órdenes de trabajo',
      child: Scaffold(
        appBar: AppBar(title: const Text('Órdenes de trabajo')),
        floatingActionButton: canEdit
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WorkOrderEditorPage(order: ctrl.newOrder()),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nueva OT'),
              )
            : null,
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (state) => _Body(state: state, ctrl: ctrl, canEdit: canEdit),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.ctrl, required this.canEdit});
  final WorkOrdersState state;
  final WorkOrdersController ctrl;
  final bool canEdit;

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
              _Chip(
                label: 'Todas',
                selected: state.filterStatus == null,
                color: AppColors.primary,
                onTap: () => ctrl.setFilter(null),
              ),
              ...WorkOrderStatus.values.map(
                (s) => _Chip(
                  label: s.label,
                  selected: state.filterStatus == s,
                  color: s.color,
                  onTap: () => ctrl.setFilter(s),
                ),
              ),
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
                      Icon(
                        Icons.engineering_outlined,
                        size: 56,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
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
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) => _OrderCard(
                    order: orders[i],
                    ctrl: ctrl,
                    canEdit: canEdit,
                  ),
                ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.15),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected ? color : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        backgroundColor: Colors.transparent,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({
    required this.order,
    required this.ctrl,
    required this.canEdit,
  });

  final WorkOrder order;
  final WorkOrdersController ctrl;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.fromMillisecondsSinceEpoch(order.updatedAtMs);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: canEdit
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkOrderEditorPage(order: order),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'OT #${order.sequence}-${order.year}',
                      style: AppTextStyles.title.copyWith(fontSize: 15),
                    ),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
              if ((order.quoteTitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  order.quoteTitle!,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              if ((order.customerName ?? '').isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        order.customerName!,
                        style: AppTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (order.quoteSequence != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.request_quote_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'COT #${order.quoteSequence}-${order.year}',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ],
              if (order.steps.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: order.progress,
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(
                            order.status.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${order.steps.where((s) => s.completed).length}/${order.steps.length}',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ],
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final isLate =
                      order.deliveryAtMs != null &&
                      DateTime.fromMillisecondsSinceEpoch(
                        order.deliveryAtMs!,
                      ).isBefore(now) &&
                      order.status != WorkOrderStatus.done &&
                      order.status != WorkOrderStatus.delivered;
                  if (!isLate) return const SizedBox(height: 8);
                  final d = DateTime.fromMillisecondsSinceEpoch(
                    order.deliveryAtMs!,
                  );
                  final days = now.difference(d).inDays;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                days == 0
                                    ? 'Vence hoy'
                                    : 'Atrasada $days día${days != 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: canEdit
                                  ? () async {
                                      await _showRescheduleDialog(
                                        context,
                                        ctrl,
                                        order,
                                      );
                                    }
                                  : null,
                              child: const Text(
                                'Reprogramar',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              Row(
                children: [
                  if (order.members.isNotEmpty) ...[
                    Icon(
                      Icons.group_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${order.members.length} persona${order.members.length != 1 ? 's' : ''}',
                      style: AppTextStyles.label,
                    ),
                  ],
                  const Spacer(),
                  Text(dateStr, style: AppTextStyles.label),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (v) async {
                      if (v == 'reschedule') {
                        await _showRescheduleDialog(context, ctrl, order);
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar orden'),
                            content: Text(
                              '¿Eliminar OT #${order.sequence}-${order.year}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ctrl.delete(order.id);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      if (canEdit && order.deliveryAtMs != null)
                        const PopupMenuItem(
                          value: 'reschedule',
                          child: Text('Reprogramar entrega'),
                        ),
                      if (canEdit && order.deliveryAtMs != null)
                        const PopupMenuDivider(),
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> _showRescheduleDialog(
  BuildContext context,
  WorkOrdersController ctrl,
  WorkOrder order,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now().add(const Duration(days: 1)),
    firstDate: DateTime.now(),
    lastDate: DateTime(2035),
    helpText: 'Nueva fecha de entrega',
  );
  if (picked == null || !context.mounted) return;

  final day = picked.day.toString().padLeft(2, '0');
  final month = picked.month.toString().padLeft(2, '0');
  final dateStr = '$day/$month/${picked.year}';

  final msgCtrl = TextEditingController(
    text:
        'Estimado cliente, le informamos que su orden de trabajo '
        '${order.quoteTitle != null ? '"${order.quoteTitle}" ' : ''}'
        'ha sido reprogramada para el $dateStr. '
        'Disculpe los inconvenientes.',
  );

  final hasPhone = (order.customerPhone ?? '').trim().isNotEmpty;

  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reprogramar entrega'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nueva fecha: $dateStr',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: msgCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mensaje al cliente',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (!hasPhone) ...[
            const SizedBox(height: 8),
            const Text(
              '⚠️ Esta OT no tiene teléfono.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('Solo guardar'),
          onPressed: () => Navigator.pop(ctx, 'save'),
        ),
        if (hasPhone)
          FilledButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Guardar y enviar'),
            onPressed: () => Navigator.pop(ctx, 'send'),
          ),
      ],
    ),
  );

  if (action == null || action == 'cancel' || !context.mounted) return;

  final updated = order.copyWith(deliveryAtMs: picked.millisecondsSinceEpoch);

  await ctrl.upsert(updated);

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        action == 'send'
            ? 'Reprogramación guardada. Abriendo WhatsApp...'
            : 'Reprogramación guardada.',
      ),
    ),
  );

  if (action != 'send') return;

  if (!hasPhone) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo abrir WhatsApp porque la OT no tiene teléfono.',
        ),
      ),
    );
    return;
  }

  final digits = order.customerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El teléfono de la OT no tiene un formato válido.'),
      ),
    );
    return;
  }

  final uri = Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(msgCtrl.text.trim())}',
  );

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo abrir WhatsApp en este dispositivo.'),
      ),
    );
  }
}
