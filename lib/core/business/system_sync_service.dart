import '../services/expense_service.dart';
import '../services/feed/feed_service.dart';
import '../services/inventory_service.dart';
import '../utils/logger.dart';

/// Unified system synchronization service for AquaRythu
///
/// Defines the calculation flow: feed → cost → expense → inventory validation
/// Ensures data consistency across all three systems
class SystemSyncService {
  final ExpenseService _expenseService;
  final FeedService _feedService;
  final InventoryService _inventoryService;

  SystemSyncService({
    required ExpenseService expenseService,
    required FeedService feedService,
    required InventoryService inventoryService,
  })  : _expenseService = expenseService,
        _feedService = feedService,
        _inventoryService = inventoryService;

  /// Main calculation flow: feed → cost → expense → inventory validation
  ///
  /// This method ensures all three systems stay in sync when feed is recorded
  Future<SyncResult> recordFeedWithSync({
    required String farmId,
    required String cropId,
    required String pondId,
    required int doc,
    required List<double> feedRounds,
    required double feedCostPerKg,
  }) async {
    try {
      AppLogger.info('Starting system sync for feed recording');

      // Step 1: Calculate total feed amount
      final totalFeedAmount = feedRounds.fold(0.0, (sum, round) => sum + round);

      // Step 2: Feed cost is now calculated from inventory system
      // No need to calculate here as it comes from inventory usage

      // Step 3: Validate inventory has sufficient feed
      final inventoryValidation = await _validateFeedInventory(
          pondId, totalFeedAmount,
          cropId: cropId, farmId: farmId);
      if (!inventoryValidation.isValid) {
        return SyncResult.failure(
          'Insufficient feed inventory. Available: ${inventoryValidation.available}kg, Required: ${inventoryValidation.required}kg',
        );
      }

      // Step 4: Record feed (this should already be done by feed_service)
      // This is a validation step to ensure feed was recorded
      final feedRecords = await _feedService.fetchFeedLogs(pondId);
      final todayFeed = feedRecords.where((log) =>
          log['doc'] == doc &&
          DateTime.parse(log['created_at']).day == DateTime.now().day);

      if (todayFeed.isEmpty) {
        return SyncResult.failure('Feed not found in feed logs for DOC $doc');
      }

      // Step 5: Feed cost is now automatically calculated from inventory
      // No manual feed expense entry needed - feed cost comes from inventory system
      AppLogger.info('Feed cost will be calculated from inventory usage');

      // Step 6: Validate inventory deduction happened
      await _validateInventoryDeduction(pondId, totalFeedAmount,
          cropId: cropId, farmId: farmId);

      AppLogger.info('System sync completed successfully');
      return SyncResult.success();
    } catch (e) {
      AppLogger.error('System sync failed: $e');
      return SyncResult.failure('Sync failed: ${e.toString()}');
    }
  }

  /// Calculates total feed cost from inventory consumption records for a period
  Future<double> _calculateFeedCostFromInventory({
    required String farmId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final feedItem = await _inventoryService.getFeedItemForFarm(farmId);
      if (feedItem == null) return 0.0;

      final itemId = feedItem['id'] as String;
      final startStr = startDate.toIso8601String().split('T')[0];
      final endStr = endDate.toIso8601String().split('T')[0];

      final consumptionResult = await _inventoryService.supabase
          .from('inventory_consumption')
          .select('quantity_used, cost_at_consumption')
          .eq('item_id', itemId)
          .eq('source', 'feed_auto')
          .gte('date', startStr)
          .lte('date', endStr);

      double totalCost = 0.0;
      for (final record in consumptionResult) {
        final quantity = (record['quantity_used'] as num?)?.toDouble() ?? 0.0;
        final costPerUnit =
            (record['cost_at_consumption'] as num?)?.toDouble() ?? 0.0;
        totalCost += quantity * costPerUnit;
      }

      return totalCost;
    } catch (e) {
      AppLogger.error('Failed to calculate feed cost from inventory: $e');
      return 0.0;
    }
  }

  /// Gets average feed price from purchase history
  Future<double> _getAverageFeedPrice(String farmId) async {
    try {
      final feedItem = await _inventoryService.getFeedItemForFarm(farmId);
      if (feedItem == null) return 50.0; // Fallback to default

      final itemId = feedItem['id'] as String;
      final purchases = await _inventoryService.getPurchaseHistory(itemId);

      if (purchases.isEmpty) return 50.0; // Fallback to default

      double totalCost = 0.0;
      double totalQuantity = 0.0;

      for (final purchase in purchases) {
        final quantity = (purchase['quantity'] as num?)?.toDouble() ?? 0.0;
        final pricePerUnit =
            (purchase['price_per_unit'] as num?)?.toDouble() ?? 0.0;

        // Handle pack-based purchases
        final packs = (purchase['packs'] as num?)?.toDouble();
        final packSize =
            (purchase['pack_size_at_purchase'] as num?)?.toDouble();
        final costPerPack = (purchase['cost_per_pack'] as num?)?.toDouble();

        if (packs != null && packSize != null && costPerPack != null) {
          totalQuantity += packs * packSize;
          totalCost += packs * costPerPack;
        } else if (quantity > 0 && pricePerUnit > 0) {
          totalQuantity += quantity;
          totalCost += quantity * pricePerUnit;
        }
      }

      return totalQuantity > 0 ? totalCost / totalQuantity : 50.0;
    } catch (e) {
      AppLogger.error('Failed to get average feed price: $e');
      return 50.0; // Fallback to default
    }
  }

  /// Validates that inventory has sufficient feed before recording
  Future<InventoryValidation> _validateFeedInventory(
      String pondId, double requiredAmount,
      {required String cropId, required String farmId}) async {
    try {
      final inventoryStock = await _inventoryService.getInventoryStock(farmId);

      // Find feed items in inventory
      final feedItems = inventoryStock.where(
          (item) => item['category']?.toString().toLowerCase() == 'feed');

      double totalAvailable = 0.0;
      for (final item in feedItems) {
        totalAvailable += (item['quantity'] as num?)?.toDouble() ?? 0.0;
      }

      return InventoryValidation(
        isValid: totalAvailable >= requiredAmount,
        available: totalAvailable,
        required: requiredAmount,
        deficit: requiredAmount > totalAvailable
            ? requiredAmount - totalAvailable
            : 0.0,
      );
    } catch (e) {
      AppLogger.error('Inventory validation failed: $e');
      return InventoryValidation(
        isValid: false,
        available: 0.0,
        required: requiredAmount,
        deficit: requiredAmount,
        error: e.toString(),
      );
    }
  }

  /// Validates that inventory was properly deducted after feed recording
  Future<void> _validateInventoryDeduction(
      String pondId, double expectedDeduction,
      {required String cropId, required String farmId}) async {
    try {
      AppLogger.info(
          'Validating inventory deduction: ${expectedDeduction.toStringAsFixed(1)}kg for pond $pondId');

      // Get feed item for this farm
      final feedItem = await _inventoryService.getFeedItemForFarm(farmId);
      if (feedItem == null) {
        AppLogger.warn(
            'Cannot validate deduction - no feed item found for farm $farmId');
        return;
      }

      final itemId = feedItem['id'] as String;

      // Get today's consumption records for this feed item
      final today = DateTime.now();
      final todayStart = today.toIso8601String().split('T')[0];

      final consumptionResult = await _inventoryService.supabase
          .from('inventory_consumption')
          .select('quantity_used, pond_id, date')
          .eq('item_id', itemId)
          .eq('date', todayStart)
          .eq('source', 'feed_auto');

      // Sum up consumption for this specific pond
      double actualDeduction = 0.0;
      for (final record in consumptionResult) {
        if (record['pond_id'] == pondId) {
          actualDeduction +=
              (record['quantity_used'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // Validate match within tolerance (0.1kg for floating point comparison)
      const tolerance = 0.1;
      final difference = (actualDeduction - expectedDeduction).abs();

      if (difference > tolerance) {
        AppLogger.error(
            'INVENTORY MISMATCH: Pond $pondId - Expected deduction: ${expectedDeduction.toStringAsFixed(2)}kg, Actual: ${actualDeduction.toStringAsFixed(2)}kg, Diff: ${difference.toStringAsFixed(2)}kg');
        throw Exception(
            'Inventory deduction mismatch: expected ${expectedDeduction.toStringAsFixed(2)}kg but ${actualDeduction.toStringAsFixed(2)}kg was deducted');
      }

      AppLogger.info(
          'Inventory deduction validated: ${actualDeduction.toStringAsFixed(2)}kg matches expected ${expectedDeduction.toStringAsFixed(2)}kg');
    } catch (e) {
      AppLogger.error('Inventory deduction validation failed: $e');
      throw Exception('Inventory validation error: $e');
    }
  }

  /// Reconciles data between systems for a specific period
  Future<ReconciliationReport> reconcileSystems({
    required String farmId,
    required String cropId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      AppLogger.info('Starting system reconciliation');

      // Get feed data
      final feedLogs = await _feedService
          .fetchFeedLogs(''); // Get all feed logs for the period

      // Get inventory data
      final inventoryStock = await _inventoryService.getInventoryStock(farmId);

      // Calculate totals
      final totalFeedAmount = feedLogs.fold(0.0,
          (sum, log) => sum + ((log['feed_given'] as num?)?.toDouble() ?? 0.0));

      // Calculate actual feed cost from inventory consumption records
      final totalFeedExpenses = await _calculateFeedCostFromInventory(
        farmId: farmId,
        startDate: startDate,
        endDate: endDate,
      );

      final totalInventoryFeed = inventoryStock
          .where((item) => item['category']?.toString().toLowerCase() == 'feed')
          .fold(
              0.0,
              (sum, item) =>
                  sum + ((item['quantity'] as num?)?.toDouble() ?? 0.0));

      // Identify discrepancies
      final discrepancies = <Discrepancy>[];

      // Check feed vs expenses (cost from inventory consumption)
      // Calculate expected cost based on average purchase price
      final avgFeedPrice = await _getAverageFeedPrice(farmId);
      final expectedFeedExpense = totalFeedAmount * avgFeedPrice;
      final expenseDiscrepancy = totalFeedExpenses - expectedFeedExpense;

      // Only flag if difference is > 5% and > Rs. 100 (allows for price variations)
      final expenseDiffPercent = expectedFeedExpense > 0
          ? (expenseDiscrepancy.abs() / expectedFeedExpense) * 100
          : 0;
      if (expenseDiffPercent > 5.0 && expenseDiscrepancy.abs() > 100.0) {
        discrepancies.add(Discrepancy(
          type: 'Feed Cost Variance',
          expected: expectedFeedExpense,
          actual: totalFeedExpenses,
          difference: expenseDiscrepancy,
        ));
      }

      // Check feed vs inventory
      final inventoryDiscrepancy = totalInventoryFeed - totalFeedAmount;
      if (inventoryDiscrepancy.abs() > 1.0) {
        discrepancies.add(Discrepancy(
          type: 'Feed vs Inventory',
          expected: totalFeedAmount,
          actual: totalInventoryFeed,
          difference: inventoryDiscrepancy,
        ));
      }

      return ReconciliationReport(
        period:
            '${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        totalFeedAmount: totalFeedAmount,
        totalFeedExpenses: totalFeedExpenses,
        totalInventoryFeed: totalInventoryFeed,
        discrepancies: discrepancies,
        isBalanced: discrepancies.isEmpty,
      );
    } catch (e) {
      AppLogger.error('Reconciliation failed: $e');
      throw Exception('Reconciliation failed: $e');
    }
  }
}

/// Result of system synchronization operation
class SyncResult {
  final bool success;
  final String? error;

  SyncResult._({required this.success, this.error});

  factory SyncResult.success() => SyncResult._(success: true);
  factory SyncResult.failure(String error) =>
      SyncResult._(success: false, error: error);
}

/// Result of inventory validation
class InventoryValidation {
  final bool isValid;
  final double available;
  final double required;
  final double deficit;
  final String? error;

  InventoryValidation({
    required this.isValid,
    required this.available,
    required this.required,
    this.deficit = 0.0,
    this.error,
  });
}

/// Discrepancy found during reconciliation
class Discrepancy {
  final String type;
  final double expected;
  final double actual;
  final double difference;

  Discrepancy({
    required this.type,
    required this.expected,
    required this.actual,
    required this.difference,
  });
}

/// Report from system reconciliation
class ReconciliationReport {
  final String period;
  final double totalFeedAmount;
  final double totalFeedExpenses;
  final double totalInventoryFeed;
  final List<Discrepancy> discrepancies;
  final bool isBalanced;

  ReconciliationReport({
    required this.period,
    required this.totalFeedAmount,
    required this.totalFeedExpenses,
    required this.totalInventoryFeed,
    required this.discrepancies,
    required this.isBalanced,
  });
}
