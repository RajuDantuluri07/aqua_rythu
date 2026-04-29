class FeedBaseService {
  static const int _baseShrimpCount = 100000;

  double getBaseFeedKg(
    int doc,
    int shrimpCount, {
    double? previousDayFeedKg,
  }) {
    final safeDoc = doc < 1 ? 1 : doc;
    final safeShrimpCount = shrimpCount < 0 ? 0 : shrimpCount;

    double basePerLakh = 1.5;
    for (int day = 2; day <= safeDoc; day++) {
      if (day <= 7) {
        basePerLakh += 0.2;
      } else if (day <= 14) {
        basePerLakh += 0.3;
      } else if (day <= 21) {
        basePerLakh += 0.4;
      } else if (day <= 30) {
        basePerLakh += 0.5;
      } else {
        basePerLakh += 0.5;
      }
    }

    var baseFeed = basePerLakh * (safeShrimpCount / _baseShrimpCount);

    if (previousDayFeedKg != null &&
        previousDayFeedKg > 0 &&
        !previousDayFeedKg.isNaN &&
        !previousDayFeedKg.isInfinite) {
      final minAllowed = previousDayFeedKg * 0.9;
      final maxAllowed = previousDayFeedKg * 1.3;
      baseFeed = baseFeed.clamp(minAllowed, maxAllowed).toDouble();
    }

    return baseFeed < 0 ? 0.0 : baseFeed;
  }
}
