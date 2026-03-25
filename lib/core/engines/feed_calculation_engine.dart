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
    final feedPct = _feedPercent(weight); // Feed % depends on Weight, not just DOC

    final biomass = (seedCount * survival * weight) / 1000;

    return biomass * feedPct;
  }

  /// SURVIVAL CURVE
  static double _survivalRate(int doc) {
    if (doc < 30) return 0.95;
    if (doc < 60) return 0.90;
    if (doc < 90) return 0.85;
    return 0.80;
  }

  /// STANDARD WEIGHT CURVE (Blind Mode fallback)
  static double _avgWeight(int doc) {
    if (doc <= 15) return 0.02;
    if (doc <= 30) return 0.2;
    if (doc <= 60) return 1.5;
    if (doc <= 90) return 8.0;
    if (doc <= 120) return 20.0;
    return 30.0;
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
      if (i == 0) return base * 0.8;
      if (i == meals - 1) return base * 1.2;
      return base;
    });
  }
}