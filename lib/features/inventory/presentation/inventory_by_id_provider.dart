import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_item.dart';
import 'inventory_providers.dart';

/// ✅ Mapa por ID para lookups rápidos (procesos -> líneas)
/// Se apoya en lo que YA existe en tu repo (inventoryItemsProvider).
final inventoryByIdProvider = Provider<Map<String, InventoryItem>>((ref) {
  final items = ref.watch(inventoryItemsProvider);
  return {for (final it in items) it.id: it};
});
