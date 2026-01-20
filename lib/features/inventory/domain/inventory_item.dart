enum InventoryItemKind { articulo, insumo, servicio }

extension InventoryItemKindX on InventoryItemKind {
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

  String get asString {
    switch (this) {
      case InventoryItemKind.articulo:
        return 'articulo';
      case InventoryItemKind.insumo:
        return 'insumo';
      case InventoryItemKind.servicio:
        return 'servicio';
    }
  }

  static InventoryItemKind fromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'insumo':
        return InventoryItemKind.insumo;
      case 'servicio':
      case 'service':
        return InventoryItemKind.servicio;
      case 'articulo':
      case 'item':
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
    required this.salePrice,
    this.cost,
    required this.stock,
    this.minStock,
    required this.updatedAtMs,
    this.dirty = false,
    this.kind = InventoryItemKind.articulo,
    this.pricingMode,
    this.calcMargin = false,
    this.dollarProtected = false,
  });

  final String id;
  final String name;

  /// Feature PRO: SKU (si aplica)
  final String? sku;

  /// Unidad (u, kg, m...)
  final String? unit;

  /// Precio de venta (o precio del servicio)
  final double salePrice;

  /// Costo (insumo/artículo)
  final double? cost;

  /// Stock (insumo/artículo)
  final int stock;

  final double? minStock;

  /// Timestamp ms
  final int updatedAtMs;

  /// Marca para sync local-first
  final bool dirty;

  final InventoryItemKind kind;

  /// Para servicios: hourly/fixed
  final String? pricingMode;

  /// Feature PRO: calcular margen
  final bool calcMargin;

  /// Feature PRO: protector dólar (solo insumo/artículo)
  final bool dollarProtected;

  InventoryItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? unit,
    double? salePrice,
    double? cost,
    int? stock,
    double? minStock,
    int? updatedAtMs,
    bool? dirty,
    InventoryItemKind? kind,
    String? pricingMode,
    bool? calcMargin,
    bool? dollarProtected,
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
      dollarProtected: dollarProtected ?? this.dollarProtected,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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
      'kind': kind.asString,
      'pricingMode': pricingMode,
      'calcMargin': calcMargin,
      'dollarProtected': dollarProtected,
    };
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      sku: json['sku'] as String?,
      unit: json['unit'] as String?,
      salePrice: (_asDouble(json['salePrice']) ?? 0.0),
      cost: _asDouble(json['cost']),
      stock: _asInt(json['stock'], fallback: 0),
      minStock: _asDouble(json['minStock']),
      updatedAtMs: _asInt(json['updatedAtMs'], fallback: 0),
      dirty: (json['dirty'] as bool?) ?? false,
      kind: InventoryItemKindX.fromString(json['kind'] as String?),
      pricingMode: json['pricingMode'] as String?,
      calcMargin: (json['calcMargin'] as bool?) ?? false,
      dollarProtected: (json['dollarProtected'] as bool?) ?? false,
    );
  }
}
