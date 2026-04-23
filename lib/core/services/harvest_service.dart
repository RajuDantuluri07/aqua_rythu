import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/harvest_model.dart';

class HarvestService {
  final supabase = Supabase.instance.client;

  /// Create a new harvest record
  Future<String> createHarvest({
    required String cropId,
    required double totalWeight,
    required double pricePerKg,
    DateTime? date,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await supabase
          .from('harvests')
          .insert({
            'crop_id': cropId,
            'total_weight': totalWeight,
            'price_per_kg': pricePerKg,
            'date': date?.toIso8601String().split('T')[0] ??
                DateTime.now().toIso8601String().split('T')[0],
          })
          .select()
          .single();

      AppLogger.info('Created harvest: ${response['id']}');
      return response['id'].toString();
    } catch (e) {
      AppLogger.error('Failed to create harvest: $e');
      rethrow;
    }
  }

  /// Get harvest records for a crop
  Future<List<Harvest>> getHarvests(String cropId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final result = await supabase
          .from('harvests')
          .select('*')
          .eq('crop_id', cropId)
          .order('date', ascending: false);

      return result.map((item) => Harvest.fromMap(item)).toList();
    } catch (e) {
      AppLogger.error('Failed to get harvests: $e');
      return [];
    }
  }

  /// Get the latest harvest for a crop
  Future<Harvest?> getLatestHarvest(String cropId) async {
    try {
      final harvests = await getHarvests(cropId);
      return harvests.isNotEmpty ? harvests.first : null;
    } catch (e) {
      AppLogger.error('Failed to get latest harvest: $e');
      return null;
    }
  }

  /// Update a harvest record
  Future<void> updateHarvest({
    required String harvestId,
    double? totalWeight,
    double? pricePerKg,
    DateTime? date,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final updateData = <String, dynamic>{};
      if (totalWeight != null) updateData['total_weight'] = totalWeight;
      if (pricePerKg != null) updateData['price_per_kg'] = pricePerKg;
      if (date != null) updateData['date'] = date.toIso8601String().split('T')[0];

      if (updateData.isEmpty) {
        AppLogger.warn('No data to update for harvest $harvestId');
        return;
      }

      await supabase
          .from('harvests')
          .update(updateData)
          .eq('id', harvestId);

      AppLogger.info('Updated harvest: $harvestId');
    } catch (e) {
      AppLogger.error('Failed to update harvest: $e');
      rethrow;
    }
  }

  /// Delete a harvest record
  Future<void> deleteHarvest(String harvestId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await supabase
          .from('harvests')
          .delete()
          .eq('id', harvestId);

      AppLogger.info('Deleted harvest: $harvestId');
    } catch (e) {
      AppLogger.error('Failed to delete harvest: $e');
      rethrow;
    }
  }

  /// Check if a crop has any harvest records
  Future<bool> hasHarvestRecords(String cropId) async {
    try {
      final result = await supabase
          .from('harvests')
          .select('id')
          .eq('crop_id', cropId)
          .limit(1);

      return (result as List?)?.isNotEmpty ?? false;
    } catch (e) {
      AppLogger.error('Failed to check harvest records: $e');
      return false;
    }
  }

  /// Get total harvest weight for a crop
  Future<double> getTotalHarvestWeight(String cropId) async {
    try {
      final result = await supabase
          .from('harvests')
          .select('total_weight')
          .eq('crop_id', cropId);

      double total = 0.0;
      for (final row in result) {
        total += (row['total_weight'] as num?)?.toDouble() ?? 0.0;
      }

      return total;
    } catch (e) {
      AppLogger.error('Failed to get total harvest weight: $e');
      return 0.0;
    }
  }

  /// Get average price per kg for a crop
  Future<double> getAveragePricePerKg(String cropId) async {
    try {
      final result = await supabase
          .from('harvests')
          .select('price_per_kg, total_weight')
          .eq('crop_id', cropId);

      if (result.isEmpty) return 0.0;

      double totalRevenue = 0.0;
      double totalWeight = 0.0;

      for (final row in result) {
        final weight = (row['total_weight'] as num?)?.toDouble() ?? 0.0;
        final price = (row['price_per_kg'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += weight * price;
        totalWeight += weight;
      }

      return totalWeight > 0 ? totalRevenue / totalWeight : 0.0;
    } catch (e) {
      AppLogger.error('Failed to get average price per kg: $e');
      return 0.0;
    }
  }
}
