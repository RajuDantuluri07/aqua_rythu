import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class InventoryService {
  final supabase = Supabase.instance.client;

  // Create inventory items
  Future<void> createInventoryItems(List<Map<String, dynamic>> items) async {
    try {
      await supabase.from('inventory_items').insert(items);
      AppLogger.info('Created ${items.length} inventory items');
    } catch (e) {
      AppLogger.error('Failed to create inventory items: $e');
      rethrow;
    }
  }

  // Get inventory stock for a specific crop/farm
  Future<List<Map<String, dynamic>>> getInventoryStock(
      String? cropId, String? farmId) async {
    try {
      var query = supabase.from('inventory_stock_view').select('*');

      if (cropId != null) {
        query = query.eq('crop_id', cropId);
      }
      if (farmId != null) {
        query = query.eq('farm_id', farmId);
      }

      final result = await query.order('category');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      AppLogger.error('Failed to get inventory stock: $e');
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

  // Check if inventory is setup for a crop
  Future<bool> isInventorySetupForCrop(String cropId) async {
    try {
      final result = await supabase
          .from('inventory_items')
          .select('id')
          .eq('crop_id', cropId);
      return (result as List?)?.isNotEmpty ?? false;
    } catch (e) {
      AppLogger.error('Failed to check inventory setup: $e');
      return false;
    }
  }

  // Get feed item for a crop
  Future<Map<String, dynamic>?> getFeedItemForCrop(String cropId) async {
    try {
      final result = await supabase
          .from('inventory_items')
          .select('*')
          .eq('crop_id', cropId)
          .eq('category', 'feed')
          .eq('is_auto_tracked', true)
          .maybeSingle();
      return result as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.error('Failed to get feed item for crop: $e');
      return null;
    }
  }
}
