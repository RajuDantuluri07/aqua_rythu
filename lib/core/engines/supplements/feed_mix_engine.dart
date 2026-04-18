import 'package:aqua_rythu/features/supplements/supplement_provider.dart';

class FeedMixEngine {
  static List<CalculatedItem> applyFeedMix({
    required double feedQty,
    required int doc,
    required String round,
    required List<Supplement> plans,
  }) {
    final applicable = plans.where((p) {
      final isFeedType = p.type == SupplementType.feedMix;
      final inDocRange = doc >= p.startDoc && doc <= p.endDoc;
      final matchesRound = p.feedingTimes.contains(round);
      return isFeedType && inDocRange && matchesRound;
    });

    return applicable.expand((plan) {
      return plan.calculateAppliedItems(feedKg: feedQty);
    }).toList();
  }
}
