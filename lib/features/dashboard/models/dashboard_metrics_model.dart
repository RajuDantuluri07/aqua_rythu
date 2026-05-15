class DashboardMetrics {
  final double estimatedBiomassKg;
  final double totalFeedKg;
  final double survivalPercent;
  final double revenuePotential;
  final double feedCost;
  final double productionCost;
  final double estimatedProfit;
  final double profitMargin;
  final int activePonds;

  const DashboardMetrics({
    required this.estimatedBiomassKg,
    required this.totalFeedKg,
    required this.survivalPercent,
    required this.revenuePotential,
    required this.feedCost,
    required this.productionCost,
    required this.estimatedProfit,
    required this.profitMargin,
    required this.activePonds,
  });

  static const empty = DashboardMetrics(
    estimatedBiomassKg: 0,
    totalFeedKg: 0,
    survivalPercent: 0,
    revenuePotential: 0,
    feedCost: 0,
    productionCost: 0,
    estimatedProfit: 0,
    profitMargin: 0,
    activePonds: 0,
  );
}
