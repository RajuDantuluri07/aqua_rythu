import '../constants/expected_abw_table.dart';
import 'engine_constants.dart';

/// Pure Dart — no Flutter dependencies.
/// Calculates the estimated pond harvest value as a range (min/max)
/// with a daily delta and a confidence score.
class PondValue {
  /// Lower bound of estimated value (₹)
  final double min;

  /// Upper bound of estimated value (₹)
  final double max;

  /// Value added today from consistent feeding (₹)
  final double delta;

  /// Confidence in the estimate, 0–100
  final int confidence;

  const PondValue({
    required this.min,
    required this.max,
    required this.delta,
    required this.confidence,
  });
}

class PondValueEngine {
  // Default market price per kg for L. vannamei.
  // Pulled from FeedEngineConstants so both engines share one tunable value.
  static const double _defaultPricePerKg = FeedEngineConstants.harvestPricePerKg;

  /// Calculate pond value.
  ///
  /// [stockCount]        — stocking seed count
  /// [avgWeightG]        — latest sampled ABW in grams (0 = use DOC estimate)
  /// [survivalRate]      — fraction 0.0–1.0
  /// [doc]               — day of culture
  /// [fedToday]          — at least one round completed today
  /// [missedFeed]        — no feed at all logged today (and DOC > 1)
  /// [traySignal]        — 'full' | 'empty' | 'partial' | null
  /// [feedingConsistent] — streak ≥ 3 consecutive days
  /// [hasTrayData]       — at least one non-skipped tray log exists
  /// [missingLogs]       — today has no feed and DOC > 1
  static PondValue calculate({
    required int stockCount,
    required double avgWeightG,
    required double survivalRate,
    required int doc,
    required bool fedToday,
    required bool missedFeed,
    required String? traySignal,
    required bool feedingConsistent,
    required bool hasTrayData,
    required bool missingLogs,
  }) {
    // Use sampled ABW if available; otherwise use the shared expected ABW table
    // (same source used by smart_feed_engine and sampling_factor — single SSOT)
    final double effectiveAbwG =
        avgWeightG > 0 ? avgWeightG : getExpectedABW(doc);

    // Biomass = stockCount × ABW_g / 1000 → kg; adjusted by survival
    final double biomassKg = (stockCount * effectiveAbwG * survivalRate) / 1000;
    final double baseValue = biomassKg * _defaultPricePerKg;

    // Behavioural adjustments
    double factor = 1.0;
    if (fedToday) factor += 0.01;
    if (missedFeed) factor -= 0.02;
    if (traySignal == 'full') factor -= 0.02; // overfeeding → FCR risk, feed wasted
    if (traySignal == 'empty') factor += 0.01; // shrimp eating well → biomass growing

    final double finalValue = baseValue * factor;
    final double delta = finalValue * 0.01; // +1% per feeding event

    // Confidence scoring
    // BUG-14 fix: SSOT documented range as 0–100 but actual achievable range
    // is 50–90 (base=60, max +30, max -10). The .clamp(0, 100) is defensive
    // arithmetic protection only — real output never leaves [50, 90].
    // Comment corrected; SSOT updated to match.
    int confidence = 60; // base
    if (doc > 30) confidence += 10;        // pond age signal
    if (feedingConsistent) confidence += 10; // ≥3-day streak
    if (hasTrayData) confidence += 10;     // tray signal present
    if (missingLogs) confidence -= 10;     // today's data absent
    // Effective range: min=50 (base - penalty), max=90 (base + all bonuses)
    confidence = confidence.clamp(0, 100);

    return PondValue(
      min: finalValue * 0.9,
      max: finalValue * 1.1,
      delta: delta,
      confidence: confidence,
    );
  }

  // _estimatedAbwFromDoc removed — replaced by getExpectedABW(doc) from
  // expected_abw_table.dart, which is the single SSOT for L. vannamei growth.
}
