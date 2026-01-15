// Modelo mínimo de InventoryItem.
// Ajusta campos según tu implementación existente.
class InventoryItem {
  final String id;
  final String name;
  final int qty;
  final Map<String, dynamic>? extra;

  InventoryItem({
    required this.id,
    required this.name,
    required this.qty,
    this.extra,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'qty': qty,
        if (extra != null) ...extra!,
      };

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    final extra = Map<String, dynamic>.from(map);
    extra.remove('id');
    extra.remove('name');
    extra.remove('qty');

    return InventoryItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      extra: extra.isEmpty ? null : extra,
    );
  }
}
