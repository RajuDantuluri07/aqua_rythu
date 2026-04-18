import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supplements/supplement_provider.dart';
import '../../core/engines/supplements/water_task_engine.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';
import '../profile/farm_settings_provider.dart';
import '../../core/utils/logger.dart';

/// State for the Farm Dashboard Metrics
class FarmDashboardState {
  final double totalFeed;
  final double totalBiomass;
  final double avgGrowth;
  final double fcr;
  final String healthIndicator; // "Healthy", "Caution", "Critical"

  const FarmDashboardState({
    this.totalFeed = 0,
    this.totalBiomass = 0,
    this.avgGrowth = 0,
    this.fcr = 0,
    this.healthIndicator = "Healthy",
  });
}

final farmDashboardProvider = Provider<FarmDashboardState>((ref) {
  AppLogger.debug("🔥 FARM DASHBOARD PROVIDER RUNNING 🔥");

  final farmState = ref.watch(farmProvider);
  final farmSettings = ref.watch(farmSettingsProvider);
  final currentFarm = farmState.currentFarm;

  if (currentFarm == null) {
    return const FarmDashboardState();
  }

  double totalFeed = 0;
  double totalBiomass = 0;
  double totalGrowthRate = 0;
  int pondCount = currentFarm.ponds.where((p) => p.status.name == 'active').length;

  // Real feed totals from logged history (single source of truth)
  final feedHistory = ref.watch(feedHistoryProvider);

  // Get survival rates based on farm type and settings
  final isSemiIntensive = farmSettings.farmType == "Semi-Intensive";
  final survivalEarlyStage = isSemiIntensive ? 0.98 : 0.95;
  final survivalMiddleStage = isSemiIntensive ? 0.95 : 0.90;
  final survivalLateStage = isSemiIntensive ? 0.92 : 0.85;

  // ✅ SINGLE CLEAN LOOP - Only count active ponds
  for (var pond in currentFarm.ponds.where((p) => p.status.name == 'active')) {
    final currentDoc = ref.watch(docProvider(pond.id));
    final growthLogs = ref.watch(growthProvider(pond.id));

    // Biomass calculation with farm-specific survival rates
    if (growthLogs.isNotEmpty) {
      final lastLog = growthLogs.first; // Newest first
      
      // Estimate biomass: SeedCount * Survival * ABW / 1000
      // Survival rates based on farm type and DOC stage
      double survival = survivalEarlyStage;
      if (currentDoc > 60 && lastLog.doc > 60) { // Added lastLog.doc check for robustness
        survival = survivalLateStage;
      } else if (currentDoc > 30 && lastLog.doc > 30) { // Added lastLog.doc check for robustness
        survival = survivalMiddleStage;
      }

      totalBiomass += (pond.seedCount * survival * lastLog.abw) / 1000;

      // Growth rate (ABW per day)
      if (currentDoc > 0) {
        totalGrowthRate += (lastLog.abw / currentDoc);
      }
    }

    // Sum actual logged feed for this pond from feedHistoryProvider
    final pondLogs = feedHistory[pond.id] ?? [];
    totalFeed += pondLogs.fold(0.0, (sum, log) => sum + log.total);
  }

  final double avgGrowth = pondCount > 0 ? totalGrowthRate / pondCount : 0;
  final double fcr = totalBiomass > 0 ? totalFeed / totalBiomass : 0;

  // Health indicator based on FCR
  String healthIndicator = "Healthy";
  if (fcr > 2.5) {
    healthIndicator = "Critical"; // High FCR indicates issues
  } else if (fcr > 2.0) {
    healthIndicator = "Caution";
  }

  AppLogger.debug("DEBUG → Feed: $totalFeed | Biomass: $totalBiomass | FCR: $fcr");

  return FarmDashboardState(
    totalFeed: totalFeed,
    totalBiomass: totalBiomass,
    avgGrowth: avgGrowth,
    fcr: fcr,
    healthIndicator: healthIndicator,
  );
});

/// 💧 Water Task Provider for Daily Tasks UI
final waterTasksProvider = Provider<List<WaterTask>>((ref) {
  final plans = ref.watch(supplementProvider);

  return WaterTaskEngine.generateWaterTasks(
    today: DateTime.now(),
    plans: plans,
  );
});
