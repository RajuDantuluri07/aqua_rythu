import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../growth/growth_provider.dart';

class FarmDashboardConstants {
  static const double defaultBiomassFactor = 0.005;
  static const double defaultFeedFactor = 0.0005;
}

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
    final growthState = ref.watch(growthProvider(pond.id));
    final lastSample = growthState.lastSample;

    // Biomass and Growth
    if (lastSample != null) {
      // Biomass = (Seed Count * ABW in grams) / 1000 => kg
      final biomass = (pond.seedCount * lastSample.abw) / 1000;
      totalBiomass += biomass;

      if (pond.doc > 0) {
        // Growth rate = ABW / DOC
        totalGrowthRate += (lastSample.abw / pond.doc);
      }
    } else {
       // Placeholder if no sampling yet (FCR usually calculated from expected biomass)
       // totalBiomass += pond.seedCount * FarmDashboardConstants.defaultBiomassFactor; // Dummy estimate
    }

    // Feed
    final plan = planMap[pond.id];

    if (plan != null && plan.days.isNotEmpty) {
      totalFeed += plan.days
          .where((d) => d.doc <= pond.doc)
          .fold(0.0, (sum, day) => sum + day.total);
    } else {
      totalFeed += pond.seedCount * FarmDashboardConstants.defaultFeedFactor * pond.doc;
    }
  }

  final double avgGrowth =
      pondCount > 0 ? totalGrowthRate / pondCount : 0;

  final double fcr =
      totalBiomass > 0 ? totalFeed / totalBiomass : 0;

  AppLogger.debug("DEBUG → Feed: $totalFeed | Biomass: $totalBiomass");

  return FarmDashboardState(
    totalFeed: totalFeed,
    totalBiomass: totalBiomass,
    avgGrowth: avgGrowth,
    fcr: fcr,
  );
});