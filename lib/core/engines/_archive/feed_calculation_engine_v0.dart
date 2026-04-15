import '../feeding_engine_v1.dart';

/// DEPRECATED — delegates to [FeedingEngineV1.calculateFeed].
///
/// Retained only for call-site compatibility with [MasterFeedEngine].
/// Do NOT add new logic here. Use [FeedingEngineV1] directly.
/// 
/// ARCHIVED: April 15, 2026 — Use FeedingEngineV1 instead.
class FeedCalculationEngine {
  static double calculateFeed({
    required int seedCount,
    required int doc,
    double? currentAbw,
    String stockingType = 'nursery',
  }) {
    return FeedingEngineV1.calculateFeed(
      doc: doc,
      stockingType: stockingType,
      density: seedCount,
      leftoverPercent: null,
    );
  }

  /// Split daily feed into per-round amounts.
  static List<double> distributeFeed(double totalFeed, int meals) {
    final base = totalFeed / meals;
    return List.generate(meals, (_) => base);
  }
}
