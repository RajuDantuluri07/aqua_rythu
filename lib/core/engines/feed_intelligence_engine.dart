// Feed Intelligence Engine
//
// Computes the gap between expected and actual feed consumption.
// Pure function — no DB calls, no biomass, no FCR.
//
// Pipeline position:
//   MasterFeedEngine (base feed) → FeedIntelligenceEngine → SmartFeedEngine (corrections)
//
// Responsibilities:
//   - Expected feed  (= base feed from MasterFeedEngine)
//   - Actual feed    (from yesterday's feed logs)
//   - Deviation      (actual − expected)
//   - Deviation %    ((deviation / expected) × 100)
//   - Status         (OnTrack / Overfeeding / Underfeeding)

// ── THRESHOLD ────────────────────────────────────────────────────────────────

/// Deviation within ±5 % is considered "on track".
const double _kOnTrackThresholdPct = 5.0;

// ── STATUS ENUM ──────────────────────────────────────────────────────────────

enum FeedStatus { onTrack, overfeeding, underfeeding }

// ── RESULT MODEL ─────────────────────────────────────────────────────────────

class IntelligenceResult {
  /// Expected feed for today (kg) — equals base feed from MasterFeedEngine.
  final double expectedFeed;

  /// Actual feed given yesterday (kg). Null when no log exists yet.
  final double? actualFeed;

  /// Actual − Expected (kg). Positive = overfeeding, negative = underfeeding.
  /// Null when [actualFeed] is null.
  final double? deviation;

  /// Deviation as a percentage of expected feed.
  /// Positive = overfeeding %, negative = underfeeding %.
  /// Null when [actualFeed] is null.
  final double? deviationPercent;

  /// Feeding status derived from [deviationPercent].
  final FeedStatus status;

  const IntelligenceResult({
    required this.expectedFeed,
    required this.status,
    this.actualFeed,
    this.deviation,
    this.deviationPercent,
  });

  /// True when we have enough data to assess yesterday's performance.
  bool get hasActualData => actualFeed != null;

  /// Signed deviation label for display, e.g. "+12.5 %" or "−8.0 %".
  String get deviationLabel {
    if (deviationPercent == null) return '—';
    final pct = deviationPercent!;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)} %';
  }

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case FeedStatus.onTrack:
        return 'On Track';
      case FeedStatus.overfeeding:
        return 'Overfeeding';
      case FeedStatus.underfeeding:
        return 'Underfeeding';
    }
  }
}

// ── ENGINE ───────────────────────────────────────────────────────────────────

class FeedIntelligenceEngine {
  /// Compute expected vs actual feed analysis.
  ///
  /// [expectedFeed]        Base feed from MasterFeedEngine (kg).
  /// [actualFeedYesterday] Sum of all feed given yesterday (kg). Pass null
  ///                       when no feed log exists (first day, etc.).
  static IntelligenceResult compute({
    required double expectedFeed,
    required double? actualFeedYesterday,
  }) {
    if (actualFeedYesterday == null) {
      return IntelligenceResult(
        expectedFeed: expectedFeed,
        status: FeedStatus.onTrack,
      );
    }

    final deviation = actualFeedYesterday - expectedFeed;
    final deviationPct =
        expectedFeed > 0 ? (deviation / expectedFeed) * 100.0 : 0.0;

    final FeedStatus status;
    if (deviationPct > _kOnTrackThresholdPct) {
      status = FeedStatus.overfeeding;
    } else if (deviationPct < -_kOnTrackThresholdPct) {
      status = FeedStatus.underfeeding;
    } else {
      status = FeedStatus.onTrack;
    }

    return IntelligenceResult(
      expectedFeed: expectedFeed,
      actualFeed: actualFeedYesterday,
      deviation: double.parse(deviation.toStringAsFixed(3)),
      deviationPercent: double.parse(deviationPct.toStringAsFixed(1)),
      status: status,
    );
  }
}
