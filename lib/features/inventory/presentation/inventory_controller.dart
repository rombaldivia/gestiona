import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../data/inventory_offline_first_service.dart';
import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';
import 'inventory_state.dart';

class InventoryController extends AsyncNotifier<InventoryState> {
  final _service = InventoryOfflineFirstService();
  String? _companyId;

  @override
  Future<InventoryState> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      _companyId = null;
      return const InventoryState(items: []);
    }

    final company = await ref.watch(companyControllerProvider.future);
    final cid = company.companyId;
    if (cid == null) {
      _companyId = null;
      return const InventoryState(items: []);
    }
    _companyId = cid;

    final items = await _service.listItems(companyId: cid);
    return InventoryState(items: items);
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

  void _ensureCompany() {
    if (_companyId == null) {
      throw StateError('No hay empresa activa seleccionada.');
    }
  }

  Future<Entitlements> _getFreshEntitlements() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }
    final ent = await ref.read(entitlementsProvider(user).future);
    // ignore: avoid_print
    print('🧾 controller fresh ent: uid=${user.uid} tier=${ent.tier} cloudSync=${ent.cloudSync}');
    return ent;
  }

  Future<void> upsertItem({
    required InventoryItem item,
    required Entitlements ent, // compat UI
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();

    await _service.upsertItemOfflineFirst(
      companyId: _companyId!,
      item: item,
      ent: freshEnt,
    );
    await reload();
  }

  Future<void> deleteItem({
    required String itemId,
    required Entitlements ent, // compat UI
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();

    await _service.deleteItemOfflineFirst(
      companyId: _companyId!,
      itemId: itemId,
      ent: freshEnt,
    );
    await reload();
  }

  Future<void> adjustStock({
    required String itemId,
    required double delta,
    required StockMovementType type,
    String? note,
    required Entitlements ent, // compat UI
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();

    // ✅ Tu modelo usa qty (positiva), createdAtMs (epoch ms) y requiere id
    final movement = StockMovement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      itemId: itemId,
      type: type,
      qty: delta.abs(),
      note: note,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );

    await _service.adjustStockOfflineFirst(
      companyId: _companyId!,
      itemId: itemId,
      delta: delta,
      movement: movement,
      ent: freshEnt,
    );
    await reload();
  }

  Future<int> sync({
    required Entitlements ent, // compat UI
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();

    // ignore: avoid_print
    print('🔄 controller sync requested: companyId=$_companyId tier=${freshEnt.tier} cloudSync=${freshEnt.cloudSync}');
    return 0;
  }
}
