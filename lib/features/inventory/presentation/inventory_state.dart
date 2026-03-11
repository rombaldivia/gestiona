import '../domain/inventory_item.dart';

class InventoryState {
  const InventoryState({required this.items, this.query = ''});

  final List<InventoryItem> items;
  final String query;

  List<InventoryItem> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;

    return items.where((it) {
      final name = it.name.toLowerCase();
      final sku = (it.sku ?? '').toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();
  }

  InventoryState copyWith({List<InventoryItem>? items, String? query}) {
    return InventoryState(
      items: items ?? this.items,
      query: query ?? this.query,
    );
  }
}
