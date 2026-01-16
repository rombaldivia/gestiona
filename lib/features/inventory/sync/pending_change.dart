import 'inventory_item.dart';

enum ChangeType { createOrUpdate, delete }

class PendingChange {
  /// id local de la operación (puede ser UUID o timestamp-based).
  final String id;

  /// tipo de cambio
  final ChangeType type;

  /// item involucrado (para deletes puedes pasar solo id en el item)
  final InventoryItem item;

  /// softDelete sugerido para deletes (true por defecto)
  final bool? softDelete;

  /// metadata adicional opcional (ej. operationId, attemptCount)
  final Map<String, dynamic>? meta;

  PendingChange({
    required this.id,
    required this.type,
    required this.item,
    this.softDelete,
    this.meta,
  });
}
