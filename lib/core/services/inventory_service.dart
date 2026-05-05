import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class InventoryService {
  final SupabaseClient supabase;

  InventoryService({SupabaseClient? client}) : supabase = client ?? Supabase.instance.client;

  // Add initial stock for multiple items (e.g. from app setup)
  Future<void> createInventoryItems(List<Map<String, dynamic>> items) async {
    try {
      if (items.isEmpty) {
        return;
      }
      for (final item in items) {
        if (!item.containsKey('name') || !item.containsKey('category')) {
          throw ArgumentError('Malformed inventory item: missing required fields');
        }
      }
      await supabase.from('inventory_items').insert(items);
      AppLogger.info('Created ${items.length} inventory items');
    } catch (e) {
      AppLogger.error('Failed to create inventory items: $e');
      rethrow;
    }
  }

  // Get inventory stock for a farm (farm-level items only: crop_id IS NULL)
  Future<List<Map<String, dynamic>>> getInventoryStock(String farmId) async {
    try {
      final result = await supabase
          .from('inventory_stock_view')
          .select('*')
          .eq('farm_id', farmId)
          .isFilter('crop_id', null)
          .order('category')
          .order('name');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get inventory stock: $e');
      rethrow;
    }
  }

  // Get per-pond feed usage breakdown for a feed item
  Future<List<Map<String, dynamic>>> getPondUsageBreakdown(
      String itemId) async {
    try {
      final result = await supabase
          .from('inventory_pond_usage_view')
          .select('*')
          .eq('item_id', itemId)
          .order('total_used', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get pond usage breakdown: $e');
      return [];
    }
  }

  // Verify inventory stock
  Future<void> verifyInventory(String itemId, double actualQuantity) async {
    try {
      await supabase.rpc('verify_inventory', params: {
        'p_item_id': itemId,
        'p_actual': actualQuantity,
      });
      AppLogger.info(
          'Verified inventory for item $itemId with actual quantity $actualQuantity');
    } catch (e) {
      AppLogger.error('Failed to verify inventory: $e');
      rethrow;
    }
  }

  // Get verification history for an item
  Future<List<Map<String, dynamic>>> getVerificationHistory(
      String itemId) async {
    try {
      final result = await supabase
          .from('inventory_verifications')
          .select('*')
          .eq('item_id', itemId)
          .order('verified_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get verification history: $e');
      return [];
    }
  }

  // Check if inventory is setup for a farm
  Future<bool> isInventorySetupForFarm(String farmId) async {
    try {
      final result = await supabase
          .from('inventory_items')
          .select('id')
          .eq('farm_id', farmId)
          .isFilter('crop_id', null);
      return (result as List?)?.isNotEmpty ?? false;
    } catch (e) {
      AppLogger.error('Failed to check inventory setup: $e');
      return false;
    }
  }

  // Get farm-level feed item
  Future<Map<String, dynamic>?> getFeedItemForFarm(String farmId) async {
    try {
      final result = await supabase
          .from('inventory_items')
          .select('*')
          .eq('farm_id', farmId)
          .eq('category', 'feed')
          .eq('is_auto_tracked', true)
          .isFilter('crop_id', null)
          .maybeSingle();
      return result;
    } catch (e) {
      AppLogger.error('Failed to get feed item for farm: $e');
      return null;
    }
  }

  // Add stock to inventory and record purchase.
  // Pass either (quantity + pricePerUnit) for raw, or (packs + costPerPack) for pack-based.
  Future<void> addStock({
    required String itemId,
    double? quantity,
    double? pricePerUnit,
    double? packs,
    double? costPerPack,
    DateTime? purchaseDate,
    String? supplierName,
    String? invoiceNumber,
    String? notes,
  }) async {
    try {
      await supabase.rpc('add_stock', params: {
        'p_item_id': itemId,
        'p_quantity': quantity,
        'p_price_per_unit': pricePerUnit,
        'p_purchase_date': purchaseDate?.toIso8601String(),
        'p_supplier_name': supplierName,
        'p_invoice_number': invoiceNumber,
        'p_notes': notes,
        'p_packs': packs,
        'p_cost_per_pack': costPerPack,
      });
      AppLogger.info('Added stock to $itemId (packs=$packs, qty=$quantity)');
    } catch (e) {
      AppLogger.error('Failed to add stock: $e');
      rethrow;
    }
  }

  // Fetch a single item from the stock view (with pack fields).
  Future<Map<String, dynamic>?> getStockItem(String itemId) async {
    try {
      final result = await supabase
          .from('inventory_stock_view')
          .select('*')
          .eq('id', itemId)
          .maybeSingle();
      return result;
    } catch (e) {
      AppLogger.error('Failed to get stock item: $e');
      return null;
    }
  }

  // Get purchase history for an item
  Future<List<Map<String, dynamic>>> getPurchaseHistory(String itemId) async {
    try {
      final result = await supabase
          .from('inventory_purchases')
          .select('*')
          .eq('item_id', itemId)
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get purchase history: $e');
      return [];
    }
  }

  // Get today's usage for a feed item
  Future<double> getTodayUsage(String itemId) async {
    try {
      final today = DateTime.now();
      final result = await supabase
          .from('inventory_consumption')
          .select('quantity_used')
          .eq('item_id', itemId)
          .eq('source', 'feed_auto')
          .gte('date', today.toIso8601String().split('T')[0]);

      double totalUsage = 0.0;
      for (final row in result) {
        totalUsage += (row['quantity_used'] as num?)?.toDouble() ?? 0.0;
      }
      return totalUsage;
    } catch (e) {
      AppLogger.error('Failed to get today usage: $e');
      return 0.0;
    }
  }

  // Check if stock is low (below threshold)
  Future<bool> isLowStock(String itemId, {double threshold = 20.0}) async {
    try {
      final result = await supabase
          .from('inventory_stock_view')
          .select('expected_stock')
          .eq('id', itemId)
          .single();

      final stock = (result['expected_stock'] as num?)?.toDouble() ?? 0.0;
      return stock <= threshold;
    } catch (e) {
      AppLogger.error('Failed to check low stock: $e');
      return false;
    }
  }

  // Get last purchase for an item
  Future<Map<String, dynamic>?> getLastPurchase(String itemId) async {
    try {
      final result = await supabase
          .from('inventory_purchases')
          .select('*')
          .eq('item_id', itemId)
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return result;
    } catch (e) {
      AppLogger.error('Failed to get last purchase: $e');
      return null;
    }
  }

  // Adjust stock manually with reason
  Future<void> adjustStock({
    required String itemId,
    required double newQuantity,
    required String reason,
    String adjustmentType = 'correction',
  }) async {
    try {
      await supabase.rpc('adjust_stock', params: {
        'p_item_id': itemId,
        'p_new_quantity': newQuantity,
        'p_reason': reason,
        'p_adjustment_type': adjustmentType,
      });
      AppLogger.info(
          'Adjusted stock for item $itemId to $newQuantity ($reason)');
    } catch (e) {
      AppLogger.error('Failed to adjust stock: $e');
      rethrow;
    }
  }

  // Get adjustment history for an item
  Future<List<Map<String, dynamic>>> getAdjustmentHistory(String itemId) async {
    try {
      final result = await supabase
          .from('inventory_adjustments')
          .select('*')
          .eq('item_id', itemId)
          .order('adjusted_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get adjustment history: $e');
      return [];
    }
  }

  // Update inventory item name and/or unit
  Future<void> updateInventoryItem(
    String itemId, {
    String? name,
    String? unit,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (unit != null) updates['unit'] = unit;
      if (updates.isEmpty) return;
      await supabase.from('inventory_items').update(updates).eq('id', itemId);
      AppLogger.info('Updated inventory item $itemId');
    } catch (e) {
      AppLogger.error('Failed to update inventory item: $e');
      rethrow;
    }
  }

  // Delete an inventory item and all related records
  Future<void> deleteInventoryItem(String itemId) async {
    try {
      await supabase.from('inventory_items').delete().eq('id', itemId);
      AppLogger.info('Deleted inventory item $itemId');
    } catch (e) {
      AppLogger.error('Failed to delete inventory item: $e');
      rethrow;
    }
  }

  // Calculate daily feed cost
  Future<double> calculateDailyFeedCost(String itemId) async {
    try {
      // Get today's usage
      final todayUsage = await getTodayUsage(itemId);

      // Get latest purchase price
      final lastPurchase = await getLastPurchase(itemId);
      final pricePerUnit = lastPurchase?['price_per_unit'] as double? ?? 0.0;

      return todayUsage * pricePerUnit;
    } catch (e) {
      AppLogger.error('Failed to calculate daily feed cost: $e');
      return 0.0;
    }
  }

  // Get last action for an item
  Future<Map<String, dynamic>?> getLastAction(String itemId) async {
    try {
      final result = await supabase
          .from('inventory_stock_view')
          .select('last_action_type, last_action_date, last_action_details')
          .eq('id', itemId)
          .maybeSingle();
      return result;
    } catch (e) {
      AppLogger.error('Failed to get last action: $e');
      return null;
    }
  }

  // Get stock mismatch information
  Future<Map<String, dynamic>?> getStockMismatch(String itemId) async {
    try {
      final result = await supabase
          .from('inventory_stock_view')
          .select('expected_stock, last_verified_quantity, stock_difference')
          .eq('id', itemId)
          .maybeSingle();
      return result;
    } catch (e) {
      AppLogger.error('Failed to get stock mismatch: $e');
      return null;
    }
  }

  // Validate unit consistency
  Future<bool> validateUnitConsistency(String itemId, String feedUnit) async {
    try {
      final result = await supabase
          .from('inventory_items')
          .select('unit')
          .eq('id', itemId)
          .single();

      final inventoryUnit = result['unit'] as String? ?? '';

      // Normalize units for comparison
      final normalizedInvUnit = inventoryUnit.toLowerCase().trim();
      final normalizedFeedUnit = feedUnit.toLowerCase().trim();

      // Check if units are compatible
      if (normalizedInvUnit == normalizedFeedUnit) return true;

      // Check common equivalents
      final compatibleUnits = {
        'kg': ['kg', 'kilogram', 'kilograms'],
        'g': ['g', 'gram', 'grams'],
        'l': ['l', 'liter', 'liters'],
        'ml': ['ml', 'milliliter', 'milliliters'],
        'pcs': ['pcs', 'pieces', 'units'],
      };

      for (final baseUnit in compatibleUnits.keys) {
        final invCompatible =
            compatibleUnits[baseUnit]!.contains(normalizedInvUnit);
        final feedCompatible =
            compatibleUnits[baseUnit]!.contains(normalizedFeedUnit);
        if (invCompatible && feedCompatible) return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Failed to validate unit consistency: $e');
      return false; // Fail closed - block operations on validation errors
    }
  }
}
