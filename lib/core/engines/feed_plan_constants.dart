/// Feed round configuration keyed by DOC range.
///
/// DOC 1–30  → 4 rounds  (NORMAL/TRAY_HABIT) | equal splits [0.25, 0.25, 0.25, 0.25] | timings 06:00, 11:00, 16:00, 21:00
/// DOC 31+   → 4 rounds  (SMART)              | biomass-based, tray × smart × safety guardrails
library;

class FeedConfig {
  final int rounds;

  /// Fraction of total daily feed assigned to each round (must sum to 1.0).
  final List<double> splits;

  /// 24-hour time strings for each round (e.g. "07:00").
  final List<String> timings24h;

  /// Display-friendly AM/PM time strings for each round.
  final List<String> timingsDisplay;

  const FeedConfig({
    required this.rounds,
    required this.splits,
    required this.timings24h,
    required this.timingsDisplay,
  });

  /// Quantity (kg) for a specific round index (0-based) given total daily feed.
  double quantityForRound(int roundIndex, double totalFeedKg) {
    if (roundIndex < 0 || roundIndex >= rounds) return 0;
    final qty = totalFeedKg * splits[roundIndex];
    // Round to 2 decimal places
    return (qty * 100).round() / 100;
  }
}

/// Feed configuration for all DOCs: 4 equal rounds.
/// 1 kg total → 250 g per round.
const FeedConfig standardFeedConfig = FeedConfig(
  rounds: 4,
  splits: [0.25, 0.25, 0.25, 0.25],
  timings24h: ["06:00", "11:00", "16:00", "21:00"],
  timingsDisplay: ["06:00 AM", "11:00 AM", "04:00 PM", "09:00 PM"],
);

/// Feed configuration for DOC 1–7: 2 rounds at 50/50 split.
/// Matches [Pond.feedRoundsForDoc] which returns 2 for DOC ≤ 7.
/// Rounds 3 and 4 have split 0.0 so [saveFeedPlans] stores 0 kg for them.
const FeedConfig earlyFeedConfig = FeedConfig(
  rounds: 2,
  splits: [0.50, 0.50, 0.00, 0.00],
  timings24h: ["06:00", "17:00", "", ""],
  timingsDisplay: ["06:00 AM", "05:00 PM", "", ""],
);

/// Returns the correct [FeedConfig] for a given DOC.
/// DOC 1–7 → 2 rounds (early acclimation period).
/// DOC 8+  → 4 rounds (standard schedule).
FeedConfig getFeedConfig(int doc) {
  if (doc <= 7) return earlyFeedConfig;
  return standardFeedConfig;
}

/// Returns the feed type label recommended for the given Day of Culture (DOC).
///
/// Applies primarily for the first 30 days.
String getFeedType(int doc) {
  if (doc <= 7) return "1R";
  if (doc <= 14) return "1R + 2R";
  if (doc <= 21) return "2R";
  if (doc <= 28) return "2R + 3S";
  return "3S";
}
