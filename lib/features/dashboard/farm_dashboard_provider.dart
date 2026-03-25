final farmDashboardProvider = Provider<FarmDashboardState>((ref) {
  print("🔥 FARM DASHBOARD PROVIDER RUNNING 🔥");

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
    final growthLogs = ref.watch(growthProvider(pond.id));

    // Biomass
    if (growthLogs.isNotEmpty) {
      final lastLog = growthLogs.first; // Newest first
      // Estimate biomass: SeedCount * Survival * ABW / 1000
      // Assuming simple survival decay for dashboard view
      double survival = 1.0; 
      if (pond.doc > 30) survival = 0.95;
      if (pond.doc > 60) survival = 0.90;
      
      totalBiomass += (pond.seedCount * survival * lastLog.averageBodyWeight) / 1000;

      // Growth
      if (pond.doc > 0) {
        totalGrowthRate += (lastLog.averageBodyWeight / pond.doc);
      }
    }

    // Feed
    final plan = planMap[pond.id];
    if (plan != null && plan.days.isNotEmpty) {
      totalFeed += plan.days
          .where((d) => d.doc <= pond.doc)
          .fold(0.0, (sum, day) => sum + day.total);
    } else {
      totalFeed += pond.seedCount * 0.0005 * pond.doc;
    }
  }

  final double avgGrowth =
      pondCount > 0 ? totalGrowthRate / pondCount : 0;

  final double fcr =
      totalBiomass > 0 ? totalFeed / totalBiomass : 0;

  print("DEBUG → Feed: $totalFeed | Biomass: $totalBiomass");

  return FarmDashboardState(
    totalFeed: totalFeed,
    totalBiomass: totalBiomass,
    avgGrowth: avgGrowth,
    fcr: fcr,
  );
});