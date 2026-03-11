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
    this.pricingMode,
    this.calcMargin = false,

    // PRO: tasa por item
    this.costCurrency = 'bob', // 'bob' | 'usd'
    num? costUsd,
    num? usdRate,
    this.usdRateUpdatedAtMs,
    this.usdRateSource = 'bo.dolarapi/binance',

    // PRO: protector
    this.protectMargin = false,
    num? protectedUsdRateAtSave,
  }) : salePrice = salePrice?.toDouble(),
       cost = cost?.toDouble(),
       stock = stock.toDouble(),
       minStock = minStock?.toDouble(),
       costUsd = costUsd?.toDouble(),
       usdRate = usdRate?.toDouble(),
       protectedUsdRateAtSave = protectedUsdRateAtSave?.toDouble();

  final String id;
  final String name;
  final String? sku;
  final String? unit;
  final double? salePrice;
  final double? cost; // Bs (convertido si venía de USD)
  final double stock;
  final double? minStock;
  final int updatedAtMs;

  final bool deleted;
  final bool dirty;

  final InventoryItemKind kind;
  final String? pricingMode;
  final bool calcMargin;

  // USD per item
  final String costCurrency;
  final double? costUsd;
  final double? usdRate;
  final int? usdRateUpdatedAtMs;
  final String usdRateSource;

  // Protector: mantener margen frente a cambio de dólar
  final bool protectMargin;
  final double? protectedUsdRateAtSave;

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

    String? costCurrency,
    num? costUsd,
    num? usdRate,
    int? usdRateUpdatedAtMs,
    String? usdRateSource,

    bool? protectMargin,
    num? protectedUsdRateAtSave,
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

      costCurrency: costCurrency ?? this.costCurrency,
      costUsd: costUsd ?? this.costUsd,
      usdRate: usdRate ?? this.usdRate,
      usdRateUpdatedAtMs: usdRateUpdatedAtMs ?? this.usdRateUpdatedAtMs,
      usdRateSource: usdRateSource ?? this.usdRateSource,

      protectMargin: protectMargin ?? this.protectMargin,
      protectedUsdRateAtSave:
          protectedUsdRateAtSave ?? this.protectedUsdRateAtSave,
    );
  }

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

      'costCurrency': costCurrency,
      'costUsd': costUsd,
      'usdRate': usdRate,
      'usdRateUpdatedAtMs': usdRateUpdatedAtMs,
      'usdRateSource': usdRateSource,

      'protectMargin': protectMargin,
      'protectedUsdRateAtSave': protectedUsdRateAtSave,
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

      costCurrency: (map['costCurrency'] as String?) ?? 'bob',
      costUsd: d(map['costUsd']),
      usdRate: d(map['usdRate']),
      usdRateUpdatedAtMs: map['usdRateUpdatedAtMs'] as int?,
      usdRateSource: (map['usdRateSource'] as String?) ?? 'bo.dolarapi/binance',

      protectMargin: (map['protectMargin'] ?? false) as bool,
      protectedUsdRateAtSave: d(map['protectedUsdRateAtSave']),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory InventoryItem.fromJson(Map<String, dynamic> map) =>
      InventoryItem.fromMap(map);
}
