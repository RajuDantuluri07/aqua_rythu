import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/feed_result.dart';

/// Provider for managing Smart Feed Debug Dashboard data
final smartFeedDebugProvider =
    StateNotifierProvider<SmartFeedDebugNotifier, FeedResult?>((ref) {
  return SmartFeedDebugNotifier();
});

class SmartFeedDebugNotifier extends StateNotifier<FeedResult?> {
  SmartFeedDebugNotifier() : super(null);

  /// Set the feed result data to display
  void setFeedResult(FeedResult result) {
    state = result;
  }

  /// Clear the current feed result
  void clear() {
    state = null;
  }

  /// Update only the confidence score
  void updateConfidenceScore(double score) {
    if (state != null) {
      state = FeedResult(
        finalFeed: state!.finalFeed,
        source: state!.source,
        docFeed: state!.docFeed,
        biomassFeed: state!.biomassFeed,
        fcrFactor: state!.fcrFactor,
        trayFactor: state!.trayFactor,
        growthFactor: state!.growthFactor,
        explanation: state!.explanation,
        confidenceScore: score,
      );
    }
  }

  /// Update the explanation text
  void updateExplanation(String explanation) {
    if (state != null) {
      state = FeedResult(
        finalFeed: state!.finalFeed,
        source: state!.source,
        docFeed: state!.docFeed,
        biomassFeed: state!.biomassFeed,
        fcrFactor: state!.fcrFactor,
        trayFactor: state!.trayFactor,
        growthFactor: state!.growthFactor,
        explanation: explanation,
        confidenceScore: state!.confidenceScore,
      );
    }
  }
}
