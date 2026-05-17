import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_item.dart';
import '../../core/services/inventory_service.dart';

final inventoryProvider =
    FutureProvider.family.autoDispose<List<InventoryItem>, String>(
  (ref, farmId) async {
    final rows = await InventoryService().getInventoryStock(farmId);
    return rows.map(InventoryItem.fromView).toList();
  },
);
