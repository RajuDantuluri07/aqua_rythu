/// Feed round configuration keyed by DOC range.
///
/// DOC 1–7   → 2 rounds  (NORMAL)     | splits [0.50, 0.50]             | timings 07:00, 18:00
/// DOC 8–14  → 4 rounds  (NORMAL)     | splits [0.25, 0.20, 0.30, 0.25] | timings 06:00, 11:00, 16:00, 21:00
/// DOC 15–30 → 4 rounds  (TRAY_HABIT) | same splits, tray data collected, no adjustment
/// DOC 31+   → 4 rounds  (SMART)      | biomass-based, tray × smart × safety guardrails

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

/// DOC 1–7 feed configuration: 4 rows stored, only R1+R2 active (R3=R4=0).
/// Splits for active rounds; R3/R4 always 0.
const FeedConfig initialFeedConfig = FeedConfig(
  rounds: 4,
  splits: [0.50, 0.50, 0.0, 0.0],
  timings24h: ["07:00", "18:00", "--:--", "--:--"],
  timingsDisplay: ["07:00 AM", "06:00 PM", "--", "--"],
);

/// DOC 8+ feed configuration: 4 rounds, weighted split.
const FeedConfig postWeekFeedConfig = FeedConfig(
  rounds: 4,
  splits: [0.25, 0.20, 0.30, 0.25],
  timings24h: ["06:00", "11:00", "16:00", "21:00"],
  timingsDisplay: ["06:00 AM", "11:00 AM", "04:00 PM", "09:00 PM"],
);

/// Returns the correct [FeedConfig] for a given DOC.
FeedConfig getFeedConfig(int doc) => doc <= 7 ? initialFeedConfig : postWeekFeedConfig;

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
