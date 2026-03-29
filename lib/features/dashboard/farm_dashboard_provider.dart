import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supplements/supplement_provider.dart';
import '../supplements/water_task_engine.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../pond/growth_provider.dart';
import '../../core/utils/logger.dart';

/// State for the Farm Dashboard Metrics
class FarmDashboardState {
  final double totalFeed;
  final double totalBiomass;
  final double avgGrowth;
  final double fcr;

  const FarmDashboardState({
    this.totalFeed = 0,
    this.totalBiomass = 0,
    this.avgGrowth = 0,
    this.fcr = 0,
  });
}

final farmDashboardProvider = Provider<FarmDashboardState>((ref) {
  AppLogger.debug("🔥 FARM DASHBOARD PROVIDER RUNNING 🔥");

  final farmState = ref.watch(farmProvider);
  final currentFarm = farmState.currentFarm;

  if (currentFarm == null) {
    return const FarmDashboardState();
  }

  double totalFeed = 0;
  double totalBiomass = 0;
  double totalGrowthRate = 0;
  int pondCount = currentFarm.ponds.length;

  final planMap = ref.watch(feedPlanProvider);

  // ✅ SINGLE CLEAN LOOP
  for (var pond in currentFarm.ponds) {
    final currentDoc = ref.watch(docProvider(pond.id));
    final growthLogs = ref.watch(growthProvider(pond.id));

    // Biomass
    if (growthLogs.isNotEmpty) {
      final lastLog = growthLogs.first; // Newest first
      // Estimate biomass: SeedCount * Survival * ABW / 1000
      // Assuming simple survival decay for dashboard view
      double survival = 1.0;
      if (currentDoc > 60) {
        survival = 0.90;
      } else if (currentDoc > 30) {
        survival = 0.95;
      } else {
        survival = 1.0;
      }

      totalBiomass +=
          (pond.seedCount * survival * lastLog.averageBodyWeight) / 1000;

      // Growth
      if (currentDoc > 0) {
        totalGrowthRate += (lastLog.averageBodyWeight / currentDoc);
      }
    }

    // Feed
    final plan = planMap[pond.id];
    if (plan != null && plan.days.isNotEmpty) {
      totalFeed += plan.days
          .where((d) => d.doc <= currentDoc)
          .fold(0.0, (sum, day) => sum + day.total);
    } else {
      totalFeed += pond.seedCount * 0.0005 * currentDoc;
    }
  }

  final double avgGrowth = pondCount > 0 ? totalGrowthRate / pondCount : 0;

  final double fcr = totalBiomass > 0 ? totalFeed / totalBiomass : 0;

  AppLogger.debug("DEBUG → Feed: $totalFeed | Biomass: $totalBiomass");

  return FarmDashboardState(
    totalFeed: totalFeed,
    totalBiomass: totalBiomass,
    avgGrowth: avgGrowth,
    fcr: fcr,
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
