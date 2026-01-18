import '../../subscription/domain/entitlements.dart';
import '../data/inventory_offline_first_service.dart';

class InventorySyncManager {
  InventorySyncManager({InventoryOfflineFirstService? service})
    : _service = service ?? InventoryOfflineFirstService();

  final InventoryOfflineFirstService _service;

  Future<int> sync({required String companyId, required Entitlements ent}) {
    return _service.syncPending(companyId: companyId, ent: ent);
  }
}
