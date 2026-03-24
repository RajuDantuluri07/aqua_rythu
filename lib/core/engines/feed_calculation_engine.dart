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

  /// SURVIVAL CURVE (Smooth Interpolation)
  static double _survivalRate(int doc) {
    return _interpolate(doc, {
      1: 0.98,
      15: 0.96,
      30: 0.93,
      60: 0.88,
      90: 0.83,
      120: 0.80,
    });
  }

  /// WEIGHT CURVE (Smooth Interpolation — grams)
  static double _avgWeight(int doc) {
    return _interpolate(doc, {
      1: 0.01,
      15: 0.08,
      30: 0.5,
      45: 2.0,
      60: 5.0,
      75: 10.0,
      90: 18.0,
      105: 25.0,
      120: 32.0,
    });
  }

  /// FEED % (Smooth Interpolation)
  static double _feedPercent(int doc) {
    return _interpolate(doc, {
      1: 0.15,
      15: 0.12,
      30: 0.08,
      60: 0.05,
      90: 0.035,
      120: 0.025,
    });
  }

  /// Linear interpolation between data points
  static double _interpolate(int doc, Map<int, double> points) {
    final keys = points.keys.toList()..sort();

    if (doc <= keys.first) return points[keys.first]!;
    if (doc >= keys.last) return points[keys.last]!;

    for (int i = 0; i < keys.length - 1; i++) {
      final x0 = keys[i];
      final x1 = keys[i + 1];
      if (doc >= x0 && doc <= x1) {
        final t = (doc - x0) / (x1 - x0);
        return points[x0]! + t * (points[x1]! - points[x0]!);
      }
    }

    return points[keys.last]!;
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