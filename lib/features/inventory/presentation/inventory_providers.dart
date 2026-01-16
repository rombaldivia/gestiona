import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_controller.dart';
import 'inventory_state.dart';

final inventoryControllerProvider =
    AsyncNotifierProvider<InventoryController, InventoryState>(
      InventoryController.new,
    );
