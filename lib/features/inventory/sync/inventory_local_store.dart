// Interfaz mínima que debe ofrecer tu store local para que el sync funcione.
// Si ya tienes una implementación (InventoryLocalStore) adapta su API a esta interfaz
// o implementa un wrapper que cumpla con estos métodos.
import 'pending_change.dart';

abstract class InventoryLocalStore {
  /// Devuelve la lista de cambios pendientes para la companyId.
  Future<List<PendingChange>> listPendingChanges(String companyId);

  /// Marca las operaciones (por id local de operación) como sincronizadas.
  Future<void> markSynced(List<String> pendingChangeIds);

  /// Añade una operación pendiente al store local (útil si quieres encolar cambios).
  Future<void> addPendingChange(PendingChange change);

  /// (Opcional) marca falladas para reintentos o inspección.
  Future<void> markFailed(List<String> pendingChangeIds, String reason);
}
