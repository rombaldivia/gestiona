import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/activity/activity_provider.dart';

import '../../../core/di/providers.dart' show authStateProvider;
import '../../company/presentation/company_providers.dart';
import '../../subscription/domain/entitlements.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../data/inventory_offline_first_service.dart';
import '../domain/inventory_item.dart';
import '../domain/stock_movement.dart';
import 'inventory_state.dart';

// ✅ Servicio mínimo para asegurar el doc company
import '../../company/data/company_cloud_service.dart';

class InventoryController extends AsyncNotifier<InventoryState> {
  final _service = InventoryOfflineFirstService();
  final _companyCloud = CompanyCloudService();

  String? _companyId;
  StreamSubscription<List<InventoryItem>>? _cloudSub;

  bool _ensuredCompanyOnCloud = false;

  // Extrae name si existe, sin romper compilación aunque tu modelo Company no tenga .name
  String? _tryCompanyName(dynamic company) {
    try {
      final n = company.name;
      if (n is String && n.trim().isNotEmpty) return n.trim();
    } catch (_) {}
    return null;
  }

  @override
  Future<InventoryState> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) {
      _companyId = null;
      _cloudSub?.cancel();
      _ensuredCompanyOnCloud = false;
      return const InventoryState(items: []);
    }

    final company = await ref.watch(companyControllerProvider.future);
    final cid = company.companyId;

    if (cid == null) {
      _companyId = null;
      _cloudSub?.cancel();
      _ensuredCompanyOnCloud = false;
      return const InventoryState(items: []);
    }

    _companyId = cid;

    // ✅ FIX: entitlementsProvider espera String (uid), no User
    final ent = await ref.watch(entitlementsProvider(user.uid).future);

    // ✅ CLAVE: si hay cloudSync, aseguramos el doc de company (sin depender de "company sync")
    if (ent.cloudSync && !_ensuredCompanyOnCloud) {
      try {
        await _companyCloud.ensureCompanyDocExists(
          companyId: cid,
          companyName: _tryCompanyName(company),
        );
      } catch (_) {
        // no revientes la UI si falla (offline, etc.)
      }
      _ensuredCompanyOnCloud = true;
    }

    // ✅ IMPORTACIÓN AUTOMÁTICA (si tu offline-first lo soporta)
    if (ent.cloudSync) {
      _cloudSub?.cancel();
      _cloudSub = _service.watchCloudItems(companyId: cid).listen((
        cloudItems,
      ) async {
        await _service.applyCloudToLocal(
          companyId: cid,
          cloudItems: cloudItems,
        );

        final local = await _service.listItems(companyId: cid);
        final q = state.asData?.value.query ?? '';
        state = AsyncData(InventoryState(items: local, query: q));
      });

      ref.onDispose(() => _cloudSub?.cancel());
    } else {
      _cloudSub?.cancel();
    }

    final items = await _service.listItems(companyId: cid);
    return InventoryState(items: items);
  }

  void _ensureCompany() {
    if (_companyId == null) {
      throw StateError('No hay empresa activa seleccionada.');
    }
  }

  Future<Entitlements> _getFreshEntitlements() async {
    final user = await ref.read(authStateProvider.future);
    if (user == null) throw StateError('No hay usuario autenticado.');
    // ✅ FIX: uid
    return ref.read(entitlementsProvider(user.uid).future);
  }

  Future<void> _ensureCompanyDocIfNeeded(Entitlements ent) async {
    if (!ent.cloudSync) return;
    _ensureCompany();

    if (_ensuredCompanyOnCloud) return;

    try {
      final company = await ref.read(companyControllerProvider.future);
      await _companyCloud.ensureCompanyDocExists(
        companyId: _companyId!,
        companyName: _tryCompanyName(company),
      );
      _ensuredCompanyOnCloud = true;
    } catch (_) {
      // ignore
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


  String _inventoryItemChangeDetail(
    InventoryItem? oldItem,
    InventoryItem newItem, {
    required bool isNew,
  }) {
    if (isNew) return 'Creado';
    if (oldItem == null) return 'Actualizado';

    String norm(String? v) => (v ?? '').trim();

    if (norm(oldItem.name) != norm(newItem.name)) {
      return 'Nombre: ${newItem.name}';
    }
    if (norm(oldItem.sku) != norm(newItem.sku)) {
      return 'SKU: ${norm(newItem.sku).isEmpty ? '-' : norm(newItem.sku)}';
    }
    if (norm(oldItem.unit) != norm(newItem.unit)) {
      return 'Unidad: ${norm(newItem.unit).isEmpty ? '-' : norm(newItem.unit)}';
    }
    if ((oldItem.salePrice ?? 0) != (newItem.salePrice ?? 0)) {
      return 'Precio venta: ${newItem.salePrice?.toStringAsFixed(2) ?? '-'}';
    }
    if ((oldItem.cost ?? 0) != (newItem.cost ?? 0)) {
      return 'Costo: ${newItem.cost?.toStringAsFixed(2) ?? '-'}';
    }
    if (oldItem.stock != newItem.stock) {
      return 'Stock: ${newItem.stock.toStringAsFixed(0)}';
    }
    if ((oldItem.minStock ?? 0) != (newItem.minStock ?? 0)) {
      return 'Stock mínimo: ${newItem.minStock?.toStringAsFixed(0) ?? '-'}';
    }
    if (oldItem.kind != newItem.kind) {
      return 'Tipo: ${newItem.kind.label}';
    }
    return 'Actualizado';
  }

  Future<void> upsertItem({
    required InventoryItem item,
    required Entitlements ent,
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(freshEnt);

    final oldItem = state.asData?.value.items.where((e) => e.id == item.id).firstOrNull;
    final existing = oldItem != null;

    ref.read(activityProvider.notifier).log(ActivityEvent.make(
      module: ActivityModule.inventory,
      verb: existing ? ActivityVerb.updated : ActivityVerb.created,
      label: item.name,
      detail: _inventoryItemChangeDetail(oldItem, item, isNew: !existing),
      entityId: item.id,
    )).ignore();

    await _service.upsertItemOfflineFirst(
      companyId: _companyId!,
      item: item,
      ent: freshEnt,
    );

    await reload();
  }

  Future<void> deleteItem({
    required String itemId,
    required Entitlements ent,
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(freshEnt);

    final item = state.asData?.value.items.where((e) => e.id == itemId).firstOrNull;
    if (item != null) {
      ref.read(activityProvider.notifier).log(ActivityEvent.make(
        module: ActivityModule.inventory,
        verb: ActivityVerb.deleted,
        label: item.name,
        detail: 'Eliminado',
        entityId: item.id,
      )).ignore();
    }

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
    required Entitlements ent,
  }) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(freshEnt);

    final movement = StockMovement(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      itemId: itemId,
      type: type,
      qty: delta.abs(),
      note: note,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );

    final allItems = await _service.listItems(companyId: _companyId!);
    final itemName = allItems.where((i) => i.id == itemId).firstOrNull?.name ?? itemId;
    ref.read(activityProvider.notifier).log(ActivityEvent.make(
      module: ActivityModule.inventory,
      verb:   delta > 0 ? ActivityVerb.stockIn : ActivityVerb.stockOut,
      label:  itemName,
      detail: [(delta > 0 ? 'Entrada' : 'Salida'), '${delta.abs().toStringAsFixed(0)} unidades'].join(' · '),
      entityId: itemId,
    )).ignore();
    await _service.adjustStockOfflineFirst(
      companyId: _companyId!,
      itemId: itemId,
      delta: delta,
      movement: movement,
      ent: freshEnt,
    );

    await reload();
  }

  Future<int> sync({required Entitlements ent}) async {
    _ensureCompany();
    final freshEnt = await _getFreshEntitlements();
    await _ensureCompanyDocIfNeeded(freshEnt);

    final n = await _service.syncPending(companyId: _companyId!, ent: freshEnt);

    await reload();
    return n;
  }
}
