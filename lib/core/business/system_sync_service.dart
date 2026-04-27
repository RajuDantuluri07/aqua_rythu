import '../services/expense_service.dart';
import '../services/feed_service.dart';
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

  /// Validates that inventory has sufficient feed before recording
  Future<InventoryValidation> _validateFeedInventory(
      String pondId, double requiredAmount,
      {required String cropId, required String farmId}) async {
    try {
      final inventoryStock =
          await _inventoryService.getInventoryStock(cropId, farmId);

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
      // This would typically check inventory logs or compare before/after states
      // For now, we'll log the validation
      AppLogger.info(
          'Validating inventory deduction: ${expectedDeduction.toStringAsFixed(1)}kg for pond $pondId');

      // TODO: Implement actual inventory deduction validation
      // This would require tracking inventory changes over time
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
      final inventoryStock = await _inventoryService.getInventoryStock(
        cropId,
        farmId,
      );

      // Calculate totals
      final totalFeedAmount = feedLogs.fold(0.0,
          (sum, log) => sum + ((log['feed_given'] as num?)?.toDouble() ?? 0.0));

      // Feed expenses are no longer tracked - feed cost comes from inventory only
      const totalFeedExpenses = 0.0;

      final totalInventoryFeed = inventoryStock
          .where((item) => item['category']?.toString().toLowerCase() == 'feed')
          .fold(
              0.0,
              (sum, item) =>
                  sum + ((item['quantity'] as num?)?.toDouble() ?? 0.0));

      // Identify discrepancies
      final discrepancies = <Discrepancy>[];

      // Check feed vs expenses
      final expectedFeedExpense = totalFeedAmount * 50.0; // Assuming Rs. 50/kg
      final expenseDiscrepancy = totalFeedExpenses - expectedFeedExpense;
      if (expenseDiscrepancy.abs() > 1.0) {
        discrepancies.add(Discrepancy(
          type: 'Feed vs Expense',
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
