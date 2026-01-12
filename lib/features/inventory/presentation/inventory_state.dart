import '../domain/inventory_item.dart';

class InventoryState {
  const InventoryState({
    required this.items,
    this.query = '',
    this.lastSyncCount,
  });

  final List<InventoryItem> items;
  final String query;
  final int? lastSyncCount;

  List<InventoryItem> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) {
      final hay = '${e.name} ${e.sku ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  InventoryState copyWith({
    List<InventoryItem>? items,
    String? query,
    int? lastSyncCount,
  }) {
    return InventoryState(
      items: items ?? this.items,
      query: query ?? this.query,
      lastSyncCount: lastSyncCount ?? this.lastSyncCount,
    );
  }
}
