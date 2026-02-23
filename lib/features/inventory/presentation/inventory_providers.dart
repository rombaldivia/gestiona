import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_item.dart';
import 'inventory_controller.dart';
import 'inventory_state.dart';

final inventoryControllerProvider =
    AsyncNotifierProvider<InventoryController, InventoryState>(
      InventoryController.new,
    );

/// ✅ Lista de items para UI (Procesos, Cotizaciones, etc.)
final inventoryItemsProvider = Provider<List<InventoryItem>>((ref) {
  final async = ref.watch(inventoryControllerProvider);
  return async.value?.items ?? const <InventoryItem>[];
});
