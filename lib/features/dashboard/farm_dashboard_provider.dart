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
    final growth = ref.watch(growthProvider(pond.id));

    // Biomass
    totalBiomass += growth.biomass;

    // Growth
    if (pond.doc > 0) {
      totalGrowthRate += (growth.avgWeight / pond.doc);
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