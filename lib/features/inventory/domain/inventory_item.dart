enum InventoryItemKind { service, insumo, articulo }

extension InventoryItemKindX on InventoryItemKind {
  String get key => switch (this) {
    InventoryItemKind.service => 'service',
    InventoryItemKind.insumo => 'insumo',
    InventoryItemKind.articulo => 'articulo',
  };

  String get label => switch (this) {
    InventoryItemKind.service => 'Servicio',
    InventoryItemKind.insumo => 'Insumo',
    InventoryItemKind.articulo => 'Artículo',
  };

  static InventoryItemKind fromKey(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'service':
        return InventoryItemKind.service;
      case 'insumo':
        return InventoryItemKind.insumo;
      case 'articulo':
      default:
        return InventoryItemKind.articulo;
    }
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    this.sku,
    this.unit,
    this.salePrice,
    this.cost,
    required this.stock,
    this.minStock,
    required this.updatedAtMs,
    this.dirty = true,
    this.kind = InventoryItemKind.articulo,
    this.pricingMode,
    this.calcMargin = false,
  });

  final String id;
  final String name;
  final String? sku;
  final String? unit;

  /// Reutilizado según tipo:
  /// - Artículo: precio de venta
  /// - Insumo: precio por uso/presencia (si lo cobras)
  /// - Servicio: precio fijo o tarifa/hora según pricingMode
  final double? salePrice;

  final double? cost;

  /// Solo aplica para Insumo/Artículo (Servicio siempre debería ser 0).
  final double stock;

  final double? minStock;
  final int updatedAtMs;
  final bool dirty;

  /// Categoría del ítem
  final InventoryItemKind kind;

  /// Solo para Servicio: 'fixed' o 'hourly'
  final String? pricingMode;

  /// Si está ON, el formulario puede auto-ajustar % margen ↔ precio (Insumo/Artículo)
  final bool calcMargin;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? unit,
    double? salePrice,
    double? cost,
    double? stock,
    double? minStock,
    int? updatedAtMs,
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
      dirty: dirty ?? this.dirty,
      kind: kind ?? this.kind,
      pricingMode: pricingMode ?? this.pricingMode,
      calcMargin: calcMargin ?? this.calcMargin,
    );
  }

  Map<String, dynamic> toJson() {
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
      'dirty': dirty,
      'kind': kind.key,
      'pricingMode': pricingMode,
      'calcMargin': calcMargin,
    };
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      sku: json['sku'] as String?,
      unit: json['unit'] as String?,
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      cost: (json['cost'] as num?)?.toDouble(),
      stock: ((json['stock'] as num?) ?? 0).toDouble(),
      minStock: (json['minStock'] as num?)?.toDouble(),
      updatedAtMs: (json['updatedAtMs'] as int?) ?? 0,
      dirty: (json['dirty'] as bool?) ?? false,
      kind: InventoryItemKindX.fromKey(json['kind'] as String?),
      pricingMode: json['pricingMode'] as String?,
      calcMargin: (json['calcMargin'] as bool?) ?? false,
    );
  }
}
