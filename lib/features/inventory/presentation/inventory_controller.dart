import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../../subscription/domain/entitlements.dart';
import '../data/inventory_offline_first_service.dart';
import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';
import 'inventory_state.dart';

class InventoryController extends AsyncNotifier<InventoryState> {
  final _service = InventoryOfflineFirstService();

  String? _companyId;

  @override
  Future<InventoryState> build() async {
    // Usuario autenticado
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      _companyId = null;
      return const InventoryState(items: []);
    }

    // Empresa activa
    final company = await ref.watch(companyControllerProvider.future);
    final cid = company.companyId;
    if (cid == null) {
      _companyId = null;
      return const InventoryState(items: []);
    }
    _companyId = cid;

    final items = await _service.listItems(companyId: cid);
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return InventoryState(items: items);
  }

  void _ensureCompany() {
    if (_companyId == null) {
      throw StateError('No hay empresa activa seleccionada.');
    }
  }

  void setQuery(String q) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(query: q));
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> upsertItem({
    required InventoryItem item,
    required Entitlements ent,
  }) async {
    _ensureCompany();
    await _service.upsertItemOfflineFirst(
      companyId: _companyId!,
      item: item,
      ent: ent,
    );
    await reload();
  }

  Future<void> deleteItem({
    required String itemId,
    required Entitlements ent,
  }) async {
    _ensureCompany();
    await _service.deleteItemOfflineFirst(
      companyId: _companyId!,
      itemId: itemId,
      ent: ent,
    );
    await reload();
  }

  Future<void> adjustStock({
    required String itemId,
    required double delta,
    required StockMovementType type,
    String? note,
    required Entitlements ent,
  }) async {
    _ensureCompany();

    final now = DateTime.now().millisecondsSinceEpoch;
    final movement = StockMovement(
      id: 'm_$now',
      itemId: itemId,
      type: type,
      qty: delta.abs(),
      note: note,
      refType: 'manual',
      refId: null,
      createdAtMs: now,
      dirty: true,
    );

    await _service.adjustStockOfflineFirst(
      companyId: _companyId!,
      itemId: itemId,
      delta: delta,
      movement: movement,
      ent: ent,
    );

    await reload();
  }

  Future<int> sync({required Entitlements ent}) async {
    _ensureCompany();
    final n = await _service.syncPending(companyId: _companyId!, ent: ent);

    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(lastSyncCount: n));
    }
    return n;
  }
}
