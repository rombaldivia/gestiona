class ProcessRequirement {
  ProcessRequirement({
    required this.reqId,
    required this.kind, // "material" | "servicio" | "insumo" (texto libre)
    required this.inventoryItemId,
    required this.nameSnapshot,
    required this.unitSnapshot,
    required this.qty,
    this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String reqId;
  final String kind;
  final String inventoryItemId;

  /// snapshot para que el proceso sea estable aunque cambie el inventario
  final String nameSnapshot;
  final String unitSnapshot;

  final double qty;
  final String? note;

  final int createdAtMs;
  final int updatedAtMs;

  ProcessRequirement copyWith({
    String? reqId,
    String? kind,
    String? inventoryItemId,
    String? nameSnapshot,
    String? unitSnapshot,
    double? qty,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return ProcessRequirement(
      reqId: reqId ?? this.reqId,
      kind: kind ?? this.kind,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      unitSnapshot: unitSnapshot ?? this.unitSnapshot,
      qty: qty ?? this.qty,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'reqId': reqId,
    'kind': kind,
    'inventoryItemId': inventoryItemId,
    'nameSnapshot': nameSnapshot,
    'unitSnapshot': unitSnapshot,
    'qty': qty,
    'note': note,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
  };

  factory ProcessRequirement.fromJson(Map<String, dynamic> m) {
    int toIntSafe(dynamic v, int fallback) =>
        v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

    double toDoubleSafe(dynamic v, double fallback) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

    return ProcessRequirement(
      reqId: (m['reqId'] ?? '').toString(),
      kind: (m['kind'] ?? 'material').toString(),
      inventoryItemId: (m['inventoryItemId'] ?? '').toString(),
      nameSnapshot: (m['nameSnapshot'] ?? '').toString(),
      unitSnapshot: (m['unitSnapshot'] ?? '').toString(),
      qty: toDoubleSafe(m['qty'], 1.0),
      note: m['note']?.toString(),
      createdAtMs: toIntSafe(m['createdAtMs'], 0),
      updatedAtMs: toIntSafe(m['updatedAtMs'], 0),
    );
  }
}
