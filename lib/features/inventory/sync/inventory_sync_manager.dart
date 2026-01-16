import 'dart:async';

import 'inventory_cloud_service.dart';
import 'inventory_local_store.dart';
import 'pending_change.dart';

/// Sync manager que coordina local store y cloud service.
/// Usa la interfaz InventoryLocalStore para interactuar con tu almacenamiento local.
class InventorySyncManager {
  InventorySyncManager({required this.local, InventoryCloudService? cloud})
    : _cloud = cloud ?? InventoryCloudService();

  final InventoryLocalStore local;
  final InventoryCloudService _cloud;

  final Map<String, bool> _syncInProgress = {};

  /// Sincroniza cambios pendientes de la companyId hacia Firestore.
  /// - Lista cambios pendientes desde local.listPendingChanges
  /// - Aplica batch en cloud
  /// - Marca como sincronizados en local.markSynced
  Future<void> syncPending(String companyId) async {
    if (_syncInProgress[companyId] == true) return;
    _syncInProgress[companyId] = true;
    try {
      final List<PendingChange> pending = await local.listPendingChanges(
        companyId,
      );
      if (pending.isEmpty) return;

      // Aplica cambios en cloud
      await _cloud.applyBatchChanges(companyId, pending);

      // Marcar como sincronizados en local
      final ids = pending.map((p) => p.id).toList();
      await local.markSynced(ids);
    } catch (e) {
      // Aquí podrías implementar retries/exponential backoff o markFailed.
      // Ejemplo simple: intentar marcar como falladas para inspección.
      try {
        final List<PendingChange> pending = await local.listPendingChanges(
          companyId,
        );
        final ids = pending.map((p) => p.id).toList();
        await local.markFailed(ids, e.toString());
      } catch (_) {
        // ignore
      }
      rethrow;
    } finally {
      _syncInProgress[companyId] = false;
    }
  }

  /// Convenience: sincronizar y devolver resultado en bool.
  Future<bool> syncPendingSafe(String companyId) async {
    try {
      await syncPending(companyId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
