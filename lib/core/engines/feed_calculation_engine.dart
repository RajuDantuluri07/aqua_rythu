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
    if (doc <= 1) return FeedEngineConstants.survivalRates[1]!;
    if (doc >= 120) return FeedEngineConstants.survivalRates[120]!;

    final points = [1, 15, 30, 60, 90, 120];
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (doc >= p1 && doc <= p2) {
        final t = (doc - p1) / (p2 - p1);
        final v1 = FeedEngineConstants.survivalRates[p1]!;
        final v2 = FeedEngineConstants.survivalRates[p2]!;
        return v1 + t * (v2 - v1);
      }
    }
    return FeedEngineConstants.survivalRates[120]!;
  }

  /// STANDARD WEIGHT CURVE (Blind Mode fallback)
  static double _avgWeight(int doc) {
    if (doc <= 1) return FeedEngineConstants.abwTargets[1]!;
    if (doc >= 120) return FeedEngineConstants.abwTargets[120]!;

    final points = [1, 15, 30, 45, 60, 75, 90, 105, 120];
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (doc >= p1 && doc <= p2) {
        final t = (doc - p1) / (p2 - p1);
        final v1 = FeedEngineConstants.abwTargets[p1]!;
        final v2 = FeedEngineConstants.abwTargets[p2]!;
        return v1 + t * (v2 - v1);
      }
    }
    return FeedEngineConstants.abwTargets[120]!;
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
