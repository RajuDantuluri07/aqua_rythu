import 'blind_feeding_engine.dart';

class FeedBaseService {
  /// Calculate base feed using BlindFeedingEngine (optimized, no loops)
  ///
  /// For DOC 1-30: Uses the official blind feeding algorithm
  /// For DOC > 30: Should be replaced by smart feed engine
  ///
  /// Applies continuity guard to prevent feed jumps that could shock shrimp.
  double getBaseFeedKg(
    int doc,
    int shrimpCount, {
    double? previousDayFeedKg,
  }) {
    final safeDoc = doc < 1 ? 1 : doc;
    final safeShrimpCount = shrimpCount < 0 ? 0 : shrimpCount;

    // Use optimized BlindFeedingEngine for DOC 1-30
    var baseFeed = BlindFeedingEngine.calculateBlindFeed(
      doc: safeDoc,
      seedCount: safeShrimpCount,
    );

    // Apply continuity damping: prevent sudden jumps
    // If yesterday's feed is valid, clamp today to ±30% from yesterday
    if (previousDayFeedKg != null &&
        previousDayFeedKg > 0 &&
        !previousDayFeedKg.isNaN &&
        !previousDayFeedKg.isInfinite) {
      final minAllowed = previousDayFeedKg * 0.7;  // Don't drop more than 30%
      final maxAllowed = previousDayFeedKg * 1.3;  // Don't jump more than 30%
      baseFeed = baseFeed.clamp(minAllowed, maxAllowed).toDouble();
    }

    return baseFeed < 0 ? 0.0 : baseFeed;
  }
}
