import '../../models/feed_result.dart';
import '../engines/models/smart_feed_output.dart';

/// SmartFeedDebugHelper - Simplified Mapper
///
/// IMPORTANT: This helper is now a MAPPER ONLY
///
/// All decision intelligence has been moved to SmartFeedDecisionEngine:
/// ❌ buildFeedResult() - deprecated, use SmartFeedOutput directly
/// ❌ generateExplanation() - moved to SmartFeedDecisionEngine
/// ❌ calculateConfidenceScore() - moved to SmartFeedDecisionEngine
/// ❌ determineFeedSource() - moved to SmartFeedDecisionEngine
///
/// This helper now only provides simple conversions for backwards compatibility
@deprecated(
  'SmartFeedDebugHelper is deprecated. Use SmartFeedDecisionEngine directly '
  'to generate output, then use buildFeedResultFromOutput() for conversion.'
)
class SmartFeedDebugHelper {
  /// Convert SmartFeedOutput to FeedResult for display in UI
  /// 
  /// This is the ONLY remaining purpose of the helper:
  /// Bridge between engine (SmartFeedOutput) and UI (FeedResult)
  static FeedResult buildFeedResultFromOutput(SmartFeedOutput output) {
    return FeedResult(
      finalFeed: output.finalFeed,
      source: output.source,
      docFeed: output.docFeed,
      biomassFeed: output.biomassFeed,
      fcrFactor: output.fcrFactor,
      trayFactor: output.trayFactor,
      growthFactor: output.growthFactor,
      explanation: output.explanation,
      confidenceScore: output.confidenceScore,
    );
  }

  /// Legacy method for backwards compatibility
  /// 
  /// ⚠️ DEPRECATED - Use SmartFeedDecisionEngine.buildSmartFeedOutput() instead
  @deprecated('Use SmartFeedDecisionEngine.buildSmartFeedOutput() instead')
  static FeedResult buildFeedResult({
    required dynamic engineOutput,
    required double docFeed,
    required double? biomassFeed,
    required double? abw,
    required int doc,
    required String explanation,
    required double confidenceScore,
  }) {
    return FeedResult(
      finalFeed: (engineOutput as dynamic).recommendedFeed ?? 0.0,
      source: abw != null ? FeedSource.biomass : FeedSource.doc,
      docFeed: docFeed,
      biomassFeed: biomassFeed,
      fcrFactor: null,
      trayFactor: null,
      growthFactor: null,
      explanation: explanation,
      confidenceScore: confidenceScore,
    );
  }
}
