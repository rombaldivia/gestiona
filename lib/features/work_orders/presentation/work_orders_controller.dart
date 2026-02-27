import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../data/work_orders_local_store.dart';
import '../domain/work_order.dart';
import '../domain/work_order_status.dart';
import 'work_orders_state.dart';

final workOrdersControllerProvider =
    AsyncNotifierProvider<WorkOrdersController, WorkOrdersState>(
      WorkOrdersController.new,
    );

class WorkOrdersController extends AsyncNotifier<WorkOrdersState> {
  final _store = WorkOrdersLocalStore();

  String? _companyId;
  String? _uid;

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

    final orders = await _store.loadAll(uid: _uid, companyId: _companyId);
    return WorkOrdersState(orders: orders);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> upsert(WorkOrder wo) async {
    await _store.upsert(wo, uid: _uid, companyId: _companyId);
    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(orders: await _loadAll()));
  }

  Future<void> delete(String id) async {
    await _store.deleteById(id, uid: _uid, companyId: _companyId);
    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(orders: await _loadAll()));
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

  // ── Filtros y búsqueda ────────────────────────────────────────────────────

  void setFilter(WorkOrderStatus? s) {
    final cur = state.asData?.value ?? _empty;
    state = AsyncData(
      cur.copyWith(
        filterStatus: s,
        clearFilter: s == null,
      ),
    );
  }

  void setQuery(String q) {
    final cur = state.asData?.value ?? _empty;
    state = AsyncData(cur.copyWith(query: q));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<WorkOrder>> _loadAll() =>
      _store.loadAll(uid: _uid, companyId: _companyId);

  String _newId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (1000 + (DateTime.now().microsecond % 9000)).toRadixString(36);
}
