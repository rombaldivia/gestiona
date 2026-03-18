import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/activity/activity_provider.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../data/work_orders_offline_first_service.dart';
import '../domain/work_order.dart';
import '../domain/work_order_status.dart';
import 'work_orders_state.dart';

final workOrdersControllerProvider =
    AsyncNotifierProvider<WorkOrdersController, WorkOrdersState>(
      WorkOrdersController.new,
    );

class WorkOrdersController extends AsyncNotifier<WorkOrdersState> {
  final _service = WorkOrdersOfflineFirstService();

  String? _companyId;
  String? _uid;
  StreamSubscription<List<WorkOrder>>? _cloudSub;

  static const _empty = WorkOrdersState(orders: []);

  @override
  Future<WorkOrdersState> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return _empty;

    final company = await ref.watch(companyControllerProvider.future);
    final cid = company.companyId;
    if (cid == null) return _empty;

    _companyId = cid;
    _uid       = user.uid;

    // Cargar local primero
    final orders = await _service.listOrders(companyId: cid);

    // Escuchar cloud si tiene sync
    final ent = await ref.read(entitlementsProvider(user.uid).future);
    if (ent.cloudSync) {
      _cloudSub?.cancel();
      _cloudSub = _service.watchCloudOrders(companyId: cid).listen((cloudOrders) async {
        await _service.applyCloudToLocal(
          companyId:   cid,
          cloudOrders: cloudOrders,
        );
        final updated = await _service.listOrders(companyId: cid);
        final cur = state.asData?.value ?? _empty;
        state = AsyncData(cur.copyWith(orders: updated));
      });

      ref.onDispose(() => _cloudSub?.cancel());
    }

    return WorkOrdersState(orders: orders);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> upsert(WorkOrder wo) async {
    final existing = state.value?.orders.any((e) => e.id == wo.id) ?? false;
    ref.read(activityProvider.notifier).log(ActivityEvent.make(
      module: ActivityModule.workOrder,
      verb:   existing ? ActivityVerb.updated : ActivityVerb.created,
      label:  'OT #${wo.sequence}-${wo.year}',
      detail: wo.customerName ?? wo.status.label,
    )).ignore();
    final cid = _companyId;
    if (cid == null) return;

    final ent = await ref.read(entitlementsProvider(_uid ?? '').future);
    await _service.upsertOfflineFirst(
      companyId: cid,
      order:     wo,
      ent:       ent,
    );

    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(orders: await _loadAll()));
  }

  Future<void> delete(String id) async {
    final wo = state.value?.orders.where((e) => e.id == id).firstOrNull;
    if (wo != null) {
      ref.read(activityProvider.notifier).log(ActivityEvent.make(
        module: ActivityModule.workOrder,
        verb:   ActivityVerb.deleted,
        label:  'OT #${wo.sequence}-${wo.year}',
        detail: wo.customerName ?? 'eliminada',
      )).ignore();
    }
    final cid = _companyId;
    if (cid == null) return;

    final ent = await ref.read(entitlementsProvider(_uid ?? '').future);
    await _service.deleteOfflineFirst(
      companyId: cid,
      orderId:   id,
      ent:       ent,
    );

    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(orders: await _loadAll()));
  }

  Future<int> syncPending() async {
    final cid = _companyId;
    if (cid == null) return 0;
    final ent = await ref.read(entitlementsProvider(_uid ?? '').future);
    return _service.syncPending(companyId: cid, ent: ent);
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  WorkOrder newOrder({
    String? quoteId,
    int? quoteSequence,
    String? customerName,
    String? customerPhone,
  }) {
    final now  = DateTime.now();
    final all  = state.asData?.value.orders ?? [];
    final year = now.year;
    final seq  = all
            .where((o) => o.year == year)
            .fold(0, (max, o) => o.sequence > max ? o.sequence : max) +
        1;

    return WorkOrder(
      id:            _newId(),
      sequence:      seq,
      year:          year,
      createdAtMs:   now.millisecondsSinceEpoch,
      updatedAtMs:   now.millisecondsSinceEpoch,
      status:        WorkOrderStatus.pending,
      quoteId:       quoteId,
      quoteSequence: quoteSequence,
      customerName:  customerName,
      customerPhone: customerPhone,
      steps: [
        WorkOrderStep(id: _newId(), title: 'Preparación'),
        WorkOrderStep(id: _newId(), title: 'Producción'),
        WorkOrderStep(id: _newId(), title: 'Control de calidad'),
        WorkOrderStep(id: _newId(), title: 'Entrega'),
      ],
    );
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  void setFilter(WorkOrderStatus? s) {
    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(filterStatus: s, clearFilter: s == null));
  }

  void setQuery(String q) {
    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(query: q));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<WorkOrder>> _loadAll() =>
      _service.listOrders(companyId: _companyId ?? '');

  String _newId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (1000 + (DateTime.now().microsecond % 9000)).toRadixString(36);
}
