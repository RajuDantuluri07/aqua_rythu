import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/profit/profit_service.dart';

class ProfitNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final ProfitService _profitService;
  final String cropId;

  ProfitNotifier(this._profitService, this.cropId) : super(const AsyncValue.loading()) {
    loadProfitSummary();
  }

  Future<void> loadProfitSummary() async {
    state = const AsyncValue.loading();
    try {
      final summary = await _profitService.getProfitSummary(cropId);
      state = AsyncValue.data(summary);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<Map<String, double>> calculateProfit({
    required double harvestWeight,
    required double sellingPrice,
  }) async {
    try {
      final profit = await _profitService.calculateProfit(
        cropId: cropId,
        harvestWeight: harvestWeight,
        sellingPrice: sellingPrice,
      );
      
      // Refresh the summary
      await loadProfitSummary();
      
      return profit;
    } catch (e) {
      // Let the UI handle the error
      rethrow;
    }
  }

  Future<double> getDailyFeedCost() async {
    try {
      return await _profitService.getDailyFeedCost(cropId);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, double>> getTotalCost() async {
    try {
      return await _profitService.getTotalCost(cropId: cropId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    await loadProfitSummary();
  }
}

// Providers
final profitServiceProvider = Provider<ProfitService>((ref) {
  return ProfitService();
});

final profitProvider = StateNotifierProvider.family<ProfitNotifier, AsyncValue<Map<String, dynamic>>, String>(
  (ref, cropId) {
    final profitService = ref.watch(profitServiceProvider);
    return ProfitNotifier(profitService, cropId);
  },
);
