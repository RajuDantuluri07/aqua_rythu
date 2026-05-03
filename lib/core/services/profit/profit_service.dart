import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../expense_service.dart';
import '../inventory_service.dart';
import '../harvest_service.dart';
import '../../models/harvest_model.dart';

class ProfitService {
  final supabase = Supabase.instance.client;
  final ExpenseService _expenseService = ExpenseService();
  final InventoryService _inventoryService = InventoryService();
  final HarvestService _harvestService = HarvestService();

  /// Calculate daily feed cost — looks up farm-level feed item via pondId or farmId
  Future<double> getDailyFeedCost(String cropId, {String? farmId}) async {
    try {
      String? resolvedFarmId = farmId;
      if (resolvedFarmId == null) {
        final row = await supabase
            .from('ponds')
            .select('farm_id')
            .eq('id', cropId)
            .maybeSingle();
        resolvedFarmId = row?['farm_id'] as String?;
      }
      if (resolvedFarmId == null) {
        AppLogger.warn('Cannot resolve farm for cropId: $cropId');
        return 0.0;
      }

      final feedItem = await _inventoryService.getFeedItemForFarm(resolvedFarmId);
      if (feedItem == null) {
        AppLogger.warn('No feed item found for farm: $resolvedFarmId');
        return 0.0;
      }

      return await _inventoryService.calculateDailyFeedCost(feedItem['id']);
    } catch (e) {
      AppLogger.error('Failed to get daily feed cost: $e');
      return 0.0;
    }
  }

  /// Calculate total expenses (excluding feed) for a specific date range
  Future<double> getOtherExpenses({
    required String cropId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final totalExpenses = await _expenseService.getTotalExpenses(
        cropId: cropId,
        startDate: startDate,
        endDate: endDate,
      );

      // For now, we'll consider all expenses as "other" since feed cost comes from inventory
      // In the future, we could filter out feed category expenses if needed
      return totalExpenses;
    } catch (e) {
      AppLogger.error('Failed to get other expenses: $e');
      return 0.0;
    }
  }

  /// Calculate total cost (feed cost + other expenses)
  Future<Map<String, double>> getTotalCost({
    required String cropId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get feed cost from inventory
      final feedCost = await getDailyFeedCost(cropId);

      // Get other expenses
      final otherExpenses = await getOtherExpenses(
        cropId: cropId,
        startDate: startDate,
        endDate: endDate,
      );

      final totalCost = feedCost + otherExpenses;

      return {
        'feed_cost': feedCost,
        'other_cost': otherExpenses,
        'total_cost': totalCost,
      };
    } catch (e) {
      AppLogger.error('Failed to calculate total cost: $e');
      return {
        'feed_cost': 0.0,
        'other_cost': 0.0,
        'total_cost': 0.0,
      };
    }
  }

  /// Calculate profit based on harvest data
  Future<Map<String, double>> calculateProfit({
    required String cropId,
    required double harvestWeight,
    required double sellingPrice,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Calculate revenue
      final revenue = harvestWeight * sellingPrice;

      // Get total costs
      final costs = await getTotalCost(
        cropId: cropId,
        startDate: startDate,
        endDate: endDate,
      );

      // Calculate profit
      final profit = revenue - costs['total_cost']!;

      return {
        'revenue': revenue,
        'feed_cost': costs['feed_cost']!,
        'other_cost': costs['other_cost']!,
        'total_cost': costs['total_cost']!,
        'profit': profit,
      };
    } catch (e) {
      AppLogger.error('Failed to calculate profit: $e');
      return {
        'revenue': 0.0,
        'feed_cost': 0.0,
        'other_cost': 0.0,
        'total_cost': 0.0,
        'profit': 0.0,
      };
    }
  }

  /// Calculate estimated profit (before harvest)
  Future<ProfitCalculation> calculateEstimatedProfit({
    required String cropId,
    required double estimatedWeight,
    required double estimatedPricePerKg,
  }) async {
    try {
      // Get total costs
      final costs = await getTotalCost(cropId: cropId);

      // Calculate estimated revenue
      final estimatedRevenue = estimatedWeight * estimatedPricePerKg;

      return ProfitCalculation.estimated(
        feedCost: costs['feed_cost']!,
        otherCost: costs['other_cost']!,
        revenue: estimatedRevenue,
      );
    } catch (e) {
      AppLogger.error('Failed to calculate estimated profit: $e');
      return ProfitCalculation.estimated(
        feedCost: 0.0,
        otherCost: 0.0,
        revenue: 0.0,
      );
    }
  }

  /// Calculate final profit (after harvest)
  Future<ProfitCalculation> calculateFinalProfit(String cropId) async {
    try {
      // Get the latest harvest
      final harvest = await _harvestService.getLatestHarvest(cropId);
      if (harvest == null) {
        throw Exception('No harvest record found for crop: $cropId');
      }

      // Get total costs
      final costs = await getTotalCost(cropId: cropId);

      return ProfitCalculation.final_(
        feedCost: costs['feed_cost']!,
        otherCost: costs['other_cost']!,
        revenue: harvest.revenue,
      );
    } catch (e) {
      AppLogger.error('Failed to calculate final profit: $e');
      return ProfitCalculation.final_(
        feedCost: 0.0,
        otherCost: 0.0,
        revenue: 0.0,
      );
    }
  }

  /// Get profit summary for a crop (both estimated and final)
  Future<Map<String, dynamic>> getProfitSummary(String cropId) async {
    try {
      // Get today's costs
      final today = DateTime.now();
      final todayCosts = await getTotalCost(
        cropId: cropId,
        startDate: today,
        endDate: today,
      );

      // Get total costs for the crop cycle
      final totalCosts = await getTotalCost(cropId: cropId);

      // Check if there's a harvest record
      final hasHarvest = await _harvestService.hasHarvestRecords(cropId);

      ProfitCalculation? finalProfit;
      if (hasHarvest) {
        finalProfit = await calculateFinalProfit(cropId);
      }

      return {
        'today': todayCosts,
        'total': totalCosts,
        'has_harvest': hasHarvest,
        'final_profit': finalProfit?.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Failed to get profit summary: $e');
      return {
        'today': {
          'feed_cost': 0.0,
          'other_cost': 0.0,
          'total_cost': 0.0,
        },
        'total': {
          'feed_cost': 0.0,
          'other_cost': 0.0,
          'total_cost': 0.0,
        },
        'has_harvest': false,
        'final_profit': null,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }
}
