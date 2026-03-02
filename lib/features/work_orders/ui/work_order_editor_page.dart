import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/work_order.dart';
import '../domain/work_order_status.dart';
import '../presentation/work_orders_controller.dart';

class WorkOrderEditorPage extends ConsumerStatefulWidget {
  const WorkOrderEditorPage({super.key, required this.order});
  final WorkOrder order;

  @override
  ConsumerState<WorkOrderEditorPage> createState() => _WorkOrderEditorPageState();
}

class _WorkOrderEditorPageState extends ConsumerState<WorkOrderEditorPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _customerCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;

  WorkOrderStatus _status = WorkOrderStatus.pending;
  late List<WorkOrderStep> _steps;
  late List<WorkOrderMember> _members;

  @override
  void initState() {
    super.initState();
    _customerCtrl = TextEditingController(text: widget.order.customerName ?? '');
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

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  bool get _isDeliveryOverdue {
    final ms = widget.order.deliveryAtMs;
    if (ms == null) return false;
    return DateTime.now().millisecondsSinceEpoch > ms;
  }

  WorkOrder _buildBase() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return widget.order.copyWith(
      customerName:
          _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim(),
      customerPhone:
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      status: _status,
      steps: _steps,
      members: _members,
      updatedAtMs: now,
    );
  }

  Future<void> _reprogramDelivery() async {
    final oldMs = widget.order.deliveryAtMs;
    if (oldMs == null) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;


    if (!mounted) return; // ✅ async gap (vamos a usar context en dialog/snack)

    final newMs =
        DateTime(picked.year, picked.month, picked.day).millisecondsSinceEpoch;

    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reprogramar entrega'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motivo (se enviará al cliente)',
            hintText: 'Ej: retraso de insumos / mantenimiento / corte de luz…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un motivo para reprogramar.')),
      );
      return;
    }

    final woCtrl = ref.read(workOrdersControllerProvider.notifier);

    final updated = _buildBase().copyWith(
      previousDeliveryAtMs: oldMs,
      deliveryAtMs: newMs,
      deliveryRescheduledAtMs: DateTime.now().millisecondsSinceEpoch,
      rescheduleReason: reason,
    );

    await woCtrl.upsert(updated);


    if (!mounted) return;
    // WhatsApp no necesita context, pero igual cuidamos mounted para el snackbar
    final phone = (updated.customerPhone ?? '').replaceAll(' ', '');
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll('+', '');
      final msg = Uri.encodeComponent(
        'Hola ${updated.customerName ?? ''}. '
        'Te escribo por la OT #${updated.sequence}-${updated.year}. '
        'La entrega programada para ${_fmtDate(oldMs)} será reprogramada para ${_fmtDate(newMs)}. '
        'Motivo: $reason. '
        'Disculpa las molestias. ¿Te queda bien esa nueva fecha?',
      );
      final uri = Uri.parse('https://wa.me/$digits?text=$msg');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrega reprogramada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OT #${widget.order.sequence}-${widget.order.year}'),
        actions: [
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saving ? null : () async {
                    final nav = Navigator.of(context);
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _saving = true);
                    try {
                      await ref.read(workOrdersControllerProvider.notifier).upsert(_buildBase());
                      if (!mounted) return;
                      nav.pop();
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            if (widget.order.deliveryAtMs != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(children: [
                  const Icon(Icons.event_outlined, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entrega: ${_fmtDate(widget.order.deliveryAtMs!)}',
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _reprogramDelivery,
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: Text(_isDeliveryOverdue
                      ? 'Reprogramar (vencida)'
                      : 'Reprogramar entrega'),
                ),
              ),
              const SizedBox(height: 14),
            ],

            TextFormField(
              controller: _customerCtrl,
              decoration: const InputDecoration(labelText: 'Cliente'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<WorkOrderStatus>(
              initialValue: _status,
              items: WorkOrderStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
              decoration: const InputDecoration(labelText: 'Estado'),
            ),

            const SizedBox(height: 18),
            Text('Etapas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            ..._steps.map((s) => Card(
              child: ListTile(
                title: Text(s.title),
                leading: Checkbox(
                  value: s.completed,
                  onChanged: (v) {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    setState(() {
                      final idx = _steps.indexWhere((x) => x.id == s.id);
                      if (idx < 0) return;
                      _steps[idx] = s.copyWith(
                        completed: v ?? false,
                        completedAtMs: (v ?? false) ? now : null,
                      );
                    });
                  },
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
