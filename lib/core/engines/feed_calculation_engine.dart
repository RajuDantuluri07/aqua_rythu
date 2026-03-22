class FeedCalculationEngine {
  /// MAIN CALCULATION
  static double calculateFeed({
    required int seedCount,
    required int doc,
  }) {
    final survival = _survivalRate(doc);
    final weight = _avgWeight(doc);
    final feedPct = _feedPercent(doc);

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

  /// WEIGHT CURVE
  static double _avgWeight(int doc) {
    if (doc <= 15) return 0.02;
    if (doc <= 30) return 0.2;
    if (doc <= 60) return 1.5;
    if (doc <= 90) return 8.0;
    if (doc <= 120) return 20.0;
    return 30.0;
  }

  /// FEED %
  static double _feedPercent(int doc) {
    if (doc <= 15) return 0.15;
    if (doc <= 30) return 0.10;
    if (doc <= 60) return 0.06;
    if (doc <= 90) return 0.04;
    return 0.03;
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