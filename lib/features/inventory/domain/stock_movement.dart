enum StockMovementType { inQty, outQty, adjust }

class StockMovement {
  const StockMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.qty,
    this.note,
    this.refType,
    this.refId,
    required this.createdAtMs,
    this.dirty = true,
  });

  final String id;
  final String itemId;
  final StockMovementType type;

  /// Cantidad positiva. Para salidas (outQty) se interpreta como decremento.
  final double qty;

  final String? note;

  /// manual | quote | work_order | invoice (cuando conectes)
  final String? refType;
  final String? refId;

  final int createdAtMs;
  final bool dirty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'type': type.name,
        'qty': qty,
        'note': note,
        'refType': refType,
        'refId': refId,
        'createdAtMs': createdAtMs,
        'dirty': dirty,
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? StockMovementType.adjust.name;
    final type = StockMovementType.values
        .cast<StockMovementType>()
        .firstWhere(
          (e) => e.name == typeStr,
          orElse: () => StockMovementType.adjust,
        );

    return StockMovement(
      id: (json['id'] as String?) ?? '',
      itemId: (json['itemId'] as String?) ?? '',
      type: type,
      qty: ((json['qty'] as num?) ?? 0).toDouble(),
      note: json['note'] as String?,
      refType: json['refType'] as String?,
      refId: json['refId'] as String?,
      createdAtMs: (json['createdAtMs'] as int?) ?? 0,
      dirty: (json['dirty'] as bool?) ?? false,
    );
  }
}
