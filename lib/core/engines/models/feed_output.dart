class FeedOutput {
  final double recommendedFeed;
  final double baseFeed;
  final double finalFactor;
  final double fcrFactor;
  final Map<String, double> factorBreakdown;
  final Map<String, double> factors;
  final List<String> alerts;
  final List<String> reasons;  // ✅ Reasons for adjustment (trust builder)
  final String engineVersion;

  FeedOutput({
    required this.recommendedFeed,
    required this.baseFeed,
    required this.finalFactor,
    required this.fcrFactor,
    required this.factorBreakdown,
    required this.factors,
    required this.engineVersion,
    required this.alerts,
    this.reasons = const [],
  });

  /// 📊 Get adjustment percentage
  double get adjustmentPercent {
    if (baseFeed == 0) return 0;
    return ((recommendedFeed - baseFeed) / baseFeed) * 100;
  }

  /// 🚨 Is this a critical stop (no feeding)?
  bool get isCriticalStop => recommendedFeed == 0 && alerts.any((a) => a.contains("DO") || a.contains("STOP"));

  /// Alias for compatibility with new debug output naming.
  double get feedQty => recommendedFeed;
}