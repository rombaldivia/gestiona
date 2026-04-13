import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/module_permission_guard.dart';
import '../domain/work_order.dart';
import '../domain/work_order_status.dart';
import '../presentation/work_orders_controller.dart';

class WorkOrderEditorPage extends ConsumerStatefulWidget {
  const WorkOrderEditorPage({super.key, required this.order});
  final WorkOrder order;

  @override
  ConsumerState<WorkOrderEditorPage> createState() =>
      _WorkOrderEditorPageState();
}

class _WorkOrderEditorPageState extends ConsumerState<WorkOrderEditorPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;

  WorkOrderStatus _status = WorkOrderStatus.pending;
  late List<WorkOrderStep> _steps;
  late List<WorkOrderMember> _members;

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(
      text: widget.order.customerName ?? '',
    );
    _phoneCtrl = TextEditingController(text: widget.order.customerPhone ?? '');
    _notesCtrl = TextEditingController(text: widget.order.notes ?? '');
    _status = widget.order.status;
    _steps = List.from(widget.order.steps);
    _members = List.from(widget.order.members);
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  WorkOrder _build() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return widget.order.copyWith(
      customerName: _customerCtrl.text.trim().isEmpty
          ? null
          : _customerCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      status: _status,
      steps: _steps,
      members: _members,
      updatedAtMs: now,
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await ref.read(workOrdersControllerProvider.notifier).upsert(_build());
      if (!mounted) return;
      Navigator.pop(context);
    } finally {}
  }

  String _newId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond).toRadixString(36);

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ModulePermissionGuard(
      moduleKey: 'workOrders',
      moduleLabel: 'Órdenes de trabajo',
      requireEdit: true,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop) await _save();
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text('OT #${widget.order.sequence}-${widget.order.year}'),
          actions: [
            // Selector de estado
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<WorkOrderStatus>(
                value: _status,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(AppRadius.md),
                items: WorkOrderStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(s.label, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (s) {
                  if (s != null) setState(() => _status = s);
                },
              ),
            ),
          ],
        ),

        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Cliente ─────────────────────────────────────────────────────
              TextFormField(
                controller: _customerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),

              // Cotización origen
              if (widget.order.quoteSequence != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.request_quote_outlined,
                        size: 16,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.order.quoteTitle != null
                              ? '${widget.order.quoteTitle!} · COT #${widget.order.quoteSequence}-${widget.order.year}'
                              : 'COT #${widget.order.quoteSequence}-${widget.order.year}',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Fecha de entrega (si existe)
              if (widget.order.deliveryAtMs != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Entrega: ${_fmtDate(widget.order.deliveryAtMs!)}',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Etapas ──────────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Etapas',
                    style: AppTextStyles.title.copyWith(fontSize: 15),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final title = await _showAddDialog(
                        context,
                        'Nueva etapa',
                        'Título',
                      );
                      if (title != null && title.isNotEmpty) {
                        setState(
                          () => _steps.add(
                            WorkOrderStep(id: _newId(), title: title),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: _steps.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Sin etapas.', style: AppTextStyles.body),
                      )
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _steps.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final step = _steps.removeAt(oldIndex);
                            _steps.insert(newIndex, step);
                          });
                        },
                        itemBuilder: (_, i) {
                          final step = _steps[i];
                          return _StepTile(
                            key: ValueKey(step.id),
                            step: step,
                            members: _members,
                            onToggle: (v) => setState(() {
                              _steps[i] = step.copyWith(
                                completed: v,
                                completedAtMs: v
                                    ? DateTime.now().millisecondsSinceEpoch
                                    : null,
                              );
                            }),
                            onAssign: (name) => setState(() {
                              _steps[i] = step.copyWith(assignedTo: name);
                            }),
                            onRemove: () => setState(() => _steps.removeAt(i)),
                          );
                        },
                      ),
              ),

              // Barra de progreso
              if (_steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _steps.isEmpty
                              ? 0
                              : _steps.where((s) => s.completed).length /
                                    _steps.length,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(_status.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_steps.where((s) => s.completed).length}/${_steps.length} completadas',
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // ── Personas asignadas ───────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Personas',
                    style: AppTextStyles.title.copyWith(fontSize: 15),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final name = await _showAddDialog(
                        context,
                        'Agregar persona',
                        'Nombre',
                      );
                      if (name != null && name.isNotEmpty) {
                        setState(
                          () => _members.add(
                            WorkOrderMember(id: _newId(), name: name),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: _members.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Sin personas asignadas.',
                          style: AppTextStyles.body,
                        ),
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < _members.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: scheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                radius: 18,
                                child: Text(
                                  _members[i].name.isNotEmpty
                                      ? _members[i].name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                _members[i].name,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: _members[i].role != null
                                  ? Text(
                                      _members[i].role!,
                                      style: AppTextStyles.label,
                                    )
                                  : null,
                              trailing: GestureDetector(
                                onTap: () =>
                                    setState(() => _members.removeAt(i)),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),

              const SizedBox(height: 20),

              // ── Notas ────────────────────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas internas',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<String?> _showAddDialog(
    BuildContext context,
    String title,
    String hint,
  ) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

// ── Tile de etapa con asignación ──────────────────────────────────────────────
class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.step,
    required this.members,
    required this.onToggle,
    required this.onAssign,
    required this.onRemove,
  });

  final WorkOrderStep step;
  final List<WorkOrderMember> members;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String?> onAssign;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: step.completed
            ? AppColors.success.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: step.completed
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila principal: checkbox + título + drag + delete
          Row(
            children: [
              Checkbox(
                value: step.completed,
                activeColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (v) => onToggle(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTextStyles.body.copyWith(
                        color: step.completed
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        decoration: step.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    // Cantidad y unidad (viene de la cotización)
                    if (step.qty != null)
                      Text(
                        '${step.qty!.toStringAsFixed(step.qty == step.qty!.roundToDouble() ? 0 : 2)} ${step.unit ?? 'und'}',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.drag_handle, color: AppColors.textHint),
              GestureDetector(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.close, size: 16, color: AppColors.textHint),
                ),
              ),
            ],
          ),

          // Asignar persona
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: members.isEmpty
                ? Text(
                    'Agrega personas arriba para asignar',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: step.assignedTo,
                      hint: Row(
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Asignar a…',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      isExpanded: true,
                      isDense: true,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin asignar'),
                        ),
                        ...members.map(
                          (m) => DropdownMenuItem<String?>(
                            value: m.name,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: scheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Text(
                                    m.name.isNotEmpty
                                        ? m.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(m.name, style: AppTextStyles.label),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: onAssign,
                    ),
                  ),
          ),

          // Persona asignada visible
          if ((step.assignedTo ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    step.assignedTo!,
                    style: AppTextStyles.label.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
