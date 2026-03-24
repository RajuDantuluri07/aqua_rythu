import 'engine_constants.dart';

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
    return _interpolate(doc, FeedEngineConstants.survivalRates);
  }

  /// WEIGHT CURVE (Smooth Interpolation — grams)
  static double _avgWeight(int doc) {
    return _interpolate(doc, FeedEngineConstants.abwTargets);
  }

  /// FEED % (Smooth Interpolation)
  static double _feedPercent(int doc) {
    return _interpolate(doc, FeedEngineConstants.feedingRates);
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
      if (i == 0) return base * FeedEngineConstants.firstMealFactor;
      if (i == meals - 1) return base * FeedEngineConstants.lastMealFactor;
      return base;
    });
  }
}