import 'supplement_provider.dart';

/// 🍤 FEED MIX ENGINE (CORE LOGIC)
/// Ticket ID: AQR-SUPPLEMENT-001
class FeedMixEngine {
  static List<CalculatedItem> applyFeedMix({
    required double feedQty,
    required int doc,
    required String round, // e.g. "R1", "R2"
    required List<Supplement> plans,
  }) {
    // Filter applicable plans based on DOC range and Round/TimeSlot
    final applicable = plans.where((p) {
      final isFeedType = p.type == SupplementType.feedMix;
      final inDocRange = doc >= p.startDoc && doc <= p.endDoc;

      // Normalize round checking (handle "R1" vs "6:00 AM" if needed,
      // but ticket specifies Round string)
      final matchesRound = p.feedingTimes.contains(round);

      return isFeedType && inDocRange && matchesRound;
    });

    return applicable.expand((plan) {
      return plan.calculateAppliedItems(feedKg: feedQty);
    }).toList();
  }
}
