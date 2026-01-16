Uso rápido:

1) Implementa InventoryLocalStore en tu store local existente o crea un wrapper que
   adapte tu store actual a esta interfaz (listPendingChanges, markSynced, addPendingChange, markFailed).

2) Importa y usa InventorySyncManager desde donde hagas sync (por ejemplo, HomePage onSyncPressed):

import 'package:tu_paquete/features/inventory/sync/inventory_sync_manager.dart';
import 'package:tu_paquete/features/inventory/sync/inventory_local_store.dart';

final localStore = MiInventoryLocalStoreImpl(...); // tu implementación que cumpla la interfaz
final syncManager = InventorySyncManager(local: localStore);

await syncManager.syncPending(companyId);

3) Ejemplo UI (HomePage) - en onSyncPressed:
try {
  await syncManager.syncPending(companyId);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sincronización OK ✅')));
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync falló: $e')));
}

4) Firestore rules recomendadas:
- Protege /companies/{companyId}/inventory/{itemId} para que solo miembros de la company puedan leer/escribir.
- Revisa tu colección company_members y adapta la regla.

5) Tests:
- Usa fake_cloud_firestore para testear InventoryCloudService.
- Implementa un InventoryLocalStore en memoria para tests de integración.

Adapta nombres de imports 'package:tu_paquete/...' según el nombre real de tu package (pubspec.yaml).
