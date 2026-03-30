class EnforcementEngine {
  static double apply({
    required double recommendedFeed,
    required double? actualFeedYesterday,
  }) {
    if (actualFeedYesterday == null) return recommendedFeed;

    final deviation = actualFeedYesterday - recommendedFeed;

    if (deviation > 0) {
      return recommendedFeed * 0.90;
    }

    return recommendedFeed;
  }
}