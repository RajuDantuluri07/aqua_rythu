import 'engine_constants.dart';

class FeedCalculationEngine {
  /// MAIN CALCULATION
  static double calculateFeed({
    required int seedCount,
    required int doc,
    double? currentAbw, // Optional: Actual sampled ABW
  }) {
    final survival = _survivalRate(doc);
    // Use actual ABW if available, otherwise use standard curve
    final weight = currentAbw ?? _avgWeight(doc);
    final feedPct =
        _feedPercent(weight); // Feed % depends on Weight, not just DOC

    final biomass = (seedCount * survival * weight) / 1000;

    return biomass * feedPct;
  }

  /// SURVIVAL CURVE
  static double _survivalRate(int doc) {
    if (doc >= 120) return FeedEngineConstants.survivalRates[120]!;
    if (doc >= 90) return FeedEngineConstants.survivalRates[90]!;
    if (doc >= 60) return FeedEngineConstants.survivalRates[60]!;
    if (doc >= 30) return FeedEngineConstants.survivalRates[30]!;
    if (doc >= 15) return FeedEngineConstants.survivalRates[15]!;
    return FeedEngineConstants.survivalRates[1]!;
  }

  /// STANDARD WEIGHT CURVE (Blind Mode fallback)
  static double _avgWeight(int doc) {
    if (doc >= 120) return FeedEngineConstants.abwTargets[120]!;
    if (doc >= 105) return FeedEngineConstants.abwTargets[105]!;
    if (doc >= 90) return FeedEngineConstants.abwTargets[90]!;
    if (doc >= 75) return FeedEngineConstants.abwTargets[75]!;
    if (doc >= 60) return FeedEngineConstants.abwTargets[60]!;
    if (doc >= 45) return FeedEngineConstants.abwTargets[45]!;
    if (doc >= 30) return FeedEngineConstants.abwTargets[30]!;
    if (doc >= 15) return FeedEngineConstants.abwTargets[15]!;
    return FeedEngineConstants.abwTargets[1]!;
  }

  /// FEED % TABLE (PRD 5.3) based on ABW
  static double _feedPercent(double abw) {
    if (abw < 1) return 0.15; // 15%
    if (abw < 3) return 0.10; // 10%
    if (abw < 5) return 0.08; // 8%
    if (abw < 8) return 0.06; // 6%
    if (abw < 12) return 0.045; // 4.5%
    if (abw < 18) return 0.035; // 3.5%
    if (abw < 25) return 0.03; // 3.0%
    return 0.025; // 2.5%
  }

  /// SPLIT INTO ROUNDS
  static List<double> distributeFeed(double totalFeed, int meals) {
    final base = totalFeed / meals;

    return List.generate(meals, (i) {
      if (i == 0) return base * FeedEngineConstants.firstMealFactor;
      if (i == meals - 1) return base * FeedEngineConstants.lastMealFactor;
      return base;
    });
  }
}
