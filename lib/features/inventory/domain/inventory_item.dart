enum InventoryItemKind {
  articulo,
  insumo,
  servicio;

  String get label {
    switch (this) {
      case InventoryItemKind.articulo:
        return 'Artículo';
      case InventoryItemKind.insumo:
        return 'Insumo';
      case InventoryItemKind.servicio:
        return 'Servicio';
    }
  }

  static InventoryItemKind parse(String? v) {
    switch (v) {
      case 'articulo':
        return InventoryItemKind.articulo;
      case 'insumo':
        return InventoryItemKind.insumo;
      case 'servicio':
        return InventoryItemKind.servicio;

      // backward-compat por si en algún lado guardaste "service"
      case 'service':
        return InventoryItemKind.servicio;

      default:
        return InventoryItemKind.articulo;
    }
  }
}

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    this.sku,
    this.unit,
    num? salePrice,
    num? cost,
    required num stock,
    num? minStock,
    required this.updatedAtMs,
    this.deleted = false,
    this.dirty = false,
    this.kind = InventoryItemKind.articulo,

    /// Solo para servicio: 'fixed' o 'hourly'
    this.pricingMode,

    /// Solo para insumo/articulo: activa cálculo de margen en UI
    this.calcMargin = false,
  }) : salePrice = salePrice?.toDouble(),
       cost = cost?.toDouble(),
       stock = stock.toDouble(),
       minStock = minStock?.toDouble();

  final String id;
  final String name;
  final String? sku;

  /// unidad de stock/uso (u, kg, m, resma...)
  final String? unit;

  /// precio de venta / tarifa (para servicio también)
  final double? salePrice;

  /// costo (para insumo/articulo)
  final double? cost;

  /// stock actual (para servicio se usa 0)
  final double stock;

  /// stock mínimo (alerta)
  final double? minStock;

  final int updatedAtMs;

  final bool deleted;
  final bool dirty;

  final InventoryItemKind kind;

  final String? pricingMode;
  final bool calcMargin;

  bool get tracksStock => kind != InventoryItemKind.servicio;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? unit,
    num? salePrice,
    num? cost,
    num? stock,
    num? minStock,
    int? updatedAtMs,
    bool? deleted,
    bool? dirty,
    InventoryItemKind? kind,
    String? pricingMode,
    bool? calcMargin,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      salePrice: salePrice ?? this.salePrice,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      kind: kind ?? this.kind,
      pricingMode: pricingMode ?? this.pricingMode,
      calcMargin: calcMargin ?? this.calcMargin,
    );
  }

  /// Mantén compatibilidad con tu data-layer
  Map<String, dynamic> toJson() => toMap();
  factory InventoryItem.fromJson(Map<String, dynamic> map) =>
      InventoryItem.fromMap(map);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'unit': unit,
      'salePrice': salePrice,
      'cost': cost,
      'stock': stock,
      'minStock': minStock,
      'updatedAtMs': updatedAtMs,
      'deleted': deleted,
      'dirty': dirty,
      'kind': kind.name,
      'pricingMode': pricingMode,
      'calcMargin': calcMargin,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    double? d(dynamic v) => (v is num) ? v.toDouble() : null;

    final kindStr = (map['kind'] ?? map['type']) as String?;
    final kind = InventoryItemKind.parse(kindStr);

    return InventoryItem(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      sku: map['sku'] as String?,
      unit: map['unit'] as String?,
      salePrice: d(map['salePrice']),
      cost: d(map['cost']),
      stock: d(map['stock']) ?? 0,
      minStock: d(map['minStock']),
      updatedAtMs: (map['updatedAtMs'] ?? 0) as int,
      deleted: (map['deleted'] ?? false) as bool,
      dirty: (map['dirty'] ?? false) as bool,
      kind: kind,
      pricingMode: map['pricingMode'] as String?,
      calcMargin: (map['calcMargin'] ?? false) as bool,
    );
  }
}
