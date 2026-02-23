class QuoteLine {
  QuoteLine({
    required this.lineId,
    required this.kind, // "inventory" | "manual"
    this.inventoryItemId,
    required this.nameSnapshot,
    this.skuSnapshot,
    this.unitSnapshot,
    required this.qty,
    required this.unitPriceBobSnapshot,
    this.costBobSnapshot,
    this.usdRateSnapshot,
    this.usdRateSourceSnapshot,
    this.usdRateUpdatedAtMsSnapshot,
    this.note,
  });

  final String lineId;
  final String kind;
  final String? inventoryItemId;

  final String nameSnapshot;
  final String? skuSnapshot;
  final String? unitSnapshot;

  final double qty;
  final double unitPriceBobSnapshot;
  final double? costBobSnapshot;

  final double? usdRateSnapshot;
  final String? usdRateSourceSnapshot;
  final int? usdRateUpdatedAtMsSnapshot;

  final String? note;

  double get lineTotalBob => qty * unitPriceBobSnapshot;

  QuoteLine copyWith({
    String? lineId,
    String? kind,
    String? inventoryItemId,
    String? nameSnapshot,
    String? skuSnapshot,
    String? unitSnapshot,
    double? qty,
    double? unitPriceBobSnapshot,
    double? costBobSnapshot,
    double? usdRateSnapshot,
    String? usdRateSourceSnapshot,
    int? usdRateUpdatedAtMsSnapshot,
    String? note,
  }) {
    return QuoteLine(
      lineId: lineId ?? this.lineId,
      kind: kind ?? this.kind,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      skuSnapshot: skuSnapshot ?? this.skuSnapshot,
      unitSnapshot: unitSnapshot ?? this.unitSnapshot,
      qty: qty ?? this.qty,
      unitPriceBobSnapshot: unitPriceBobSnapshot ?? this.unitPriceBobSnapshot,
      costBobSnapshot: costBobSnapshot ?? this.costBobSnapshot,
      usdRateSnapshot: usdRateSnapshot ?? this.usdRateSnapshot,
      usdRateSourceSnapshot: usdRateSourceSnapshot ?? this.usdRateSourceSnapshot,
      usdRateUpdatedAtMsSnapshot:
          usdRateUpdatedAtMsSnapshot ?? this.usdRateUpdatedAtMsSnapshot,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'lineId': lineId,
        'kind': kind,
        'inventoryItemId': inventoryItemId,
        'nameSnapshot': nameSnapshot,
        'skuSnapshot': skuSnapshot,
        'unitSnapshot': unitSnapshot,
        'qty': qty,
        'unitPriceBobSnapshot': unitPriceBobSnapshot,
        'costBobSnapshot': costBobSnapshot,
        'usdRateSnapshot': usdRateSnapshot,
        'usdRateSourceSnapshot': usdRateSourceSnapshot,
        'usdRateUpdatedAtMsSnapshot': usdRateUpdatedAtMsSnapshot,
        'note': note,
      };

  factory QuoteLine.fromJson(Map<String, dynamic> m) {
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
    int? i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

    return QuoteLine(
      lineId: (m['lineId'] ?? '').toString(),
      kind: (m['kind'] ?? 'inventory').toString(),
      inventoryItemId: m['inventoryItemId']?.toString(),
      nameSnapshot: (m['nameSnapshot'] ?? '').toString(),
      skuSnapshot: m['skuSnapshot']?.toString(),
      unitSnapshot: m['unitSnapshot']?.toString(),
      qty: d(m['qty']) ?? 1.0,
      unitPriceBobSnapshot: d(m['unitPriceBobSnapshot']) ?? 0.0,
      costBobSnapshot: d(m['costBobSnapshot']),
      usdRateSnapshot: d(m['usdRateSnapshot']),
      usdRateSourceSnapshot: m['usdRateSourceSnapshot']?.toString(),
      usdRateUpdatedAtMsSnapshot: i(m['usdRateUpdatedAtMsSnapshot']),
      note: m['note']?.toString(),
    );
  }
}
