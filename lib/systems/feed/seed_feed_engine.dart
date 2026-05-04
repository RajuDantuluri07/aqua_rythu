// Seed Feed Engine — DOC-table-based feed calculation for early growth phase.
//
// Covers DOC 1–25 (hatchery) and DOC 1–20 (nursery) using predefined feed
// tables. Falls back to the master engine curve for DOC beyond the table range.
//
// Pipeline: getBaseFeed → getTrayFactor → getSmartFactor → calculateFinalFeed
// Returns a FeedExplanation for transparent UI display.

import '../../features/pond/enums/seed_type.dart';
import '../../features/feed/models/feed_explanation.dart';
import 'seed_feed_config.dart';

const double _kFeedPricePerKg = 60.0; // Approx ₹60/kg feed price for savings calc

class SeedFeedEngine {
  // ── BASE FEED ──────────────────────────────────────────────────────────────

  /// Returns base feed (kg) from the DOC table for [seedType].
  ///
  /// If [doc] is beyond the table range, returns null — callers should fall
  /// back to the master engine for those DOCs.
  static double? getBaseFeedFromTable({
    required SeedType seedType,
    required int doc,
    required int seedCount,
  }) {
    final table = feedTableFor(seedType);
    try {
      final plan = table.firstWhere(
        (p) => doc >= p.docStart && doc <= p.docEnd,
      );
      return plan.feedKgPer100k * (seedCount / 100000);
    } catch (_) {
      return null; // DOC outside table range
    }
  }

  /// Returns base feed, falling back to a simple interpolated curve when the
  /// DOC exceeds the seed table range.
  static double getBaseFeed({
    required SeedType seedType,
    required int doc,
    required int seedCount,
  }) {
    return getBaseFeedFromTable(
          seedType: seedType,
          doc: doc,
          seedCount: seedCount,
        ) ??
        _fallbackFeed(doc, seedCount);
  }

  // ── TRAY FACTOR ───────────────────────────────────────────────────────────

  /// Returns tray adjustment factor.
  ///
  /// [leftoverPercent] — % of feed left in tray (0–100). -1 = no data.
  /// [emptiedFast]     — true when tray was emptied quickly (high appetite).
  ///
  /// Returns an additive factor:
  ///   -0.10 → reduce 10%   |  +0.08 → increase 8%   |  0.0 → no change
  static double getTrayFactor({
    required double leftoverPercent,
    required bool emptiedFast,
  }) {
    if (leftoverPercent < 0) return 0.0; // No data — no adjustment

    if (leftoverPercent > 20) return -0.10; // High leftover → reduce
    if (emptiedFast) return 0.08;           // Fast finish → increase
    return 0.0;
  }

  // ── SMART FACTOR ──────────────────────────────────────────────────────────

  /// Returns smart adjustment factor based on seed type and DOC stage.
  ///
  /// Hatchery early phase (DOC < 15): conservative — reduces by 5%.
  /// Nursery early phase (DOC < 10): growth push — increases by 5%.
  /// All other combinations: no adjustment.
  static double getSmartFactor({
    required SeedType seedType,
    required int doc,
  }) {
    if (seedType == SeedType.hatcherySmall && doc < 15) return -0.05;
    if (seedType == SeedType.nurseryBig && doc < 10) return 0.05;
    return 0.0;
  }

  // ── FINAL FEED ────────────────────────────────────────────────────────────

  /// Combines base + tray + smart factors into final feed (kg).
  ///
  /// Uses multiplicative factors for correct proportional adjustment.
  /// Clamps total factor adjustment to ±20% to prevent extreme jumps.
  static double calculateFinalFeed({
    required double baseFeed,
    required double trayFactor,
    required double smartFactor,
  }) {
    final rawFactor = (1.0 + trayFactor) * (1.0 + smartFactor);
    // Clamp: never go below 80% or above 120% of base
    final clampedFactor = rawFactor.clamp(0.80, 1.20);
    return baseFeed * clampedFactor;
  }

  // ── EXPLANATION ENGINE ───────────────────────────────────────────────────

  /// Runs the full pipeline and returns a structured explanation for UI display.
  ///
  /// [leftoverPercent] — % leftover in tray. -1 = no tray data.
  /// [emptiedFast]     — true when tray was cleared faster than expected.
  static FeedExplanation buildExplanation({
    required SeedType seedType,
    required int doc,
    required int seedCount,
    double leftoverPercent = -1,
    bool emptiedFast = false,
  }) {
    final base = getBaseFeed(
      seedType: seedType,
      doc: doc,
      seedCount: seedCount,
    );

    final tray = getTrayFactor(
      leftoverPercent: leftoverPercent,
      emptiedFast: emptiedFast,
    );

    final smart = getSmartFactor(seedType: seedType, doc: doc);

    final finalFeed = calculateFinalFeed(
      baseFeed: base,
      trayFactor: tray,
      smartFactor: smart,
    );

    final isSeedPhase = getBaseFeedFromTable(
          seedType: seedType,
          doc: doc,
          seedCount: seedCount,
        ) !=
        null;

    // Savings calculation: when tray factor reduces feed, estimate cost saved
    double? savings;
    if (tray < 0) {
      final savedKg = base - finalFeed;
      if (savedKg > 0) savings = savedKg * _kFeedPricePerKg;
    }

    final message = _buildMessage(tray, smart, savings);

    return FeedExplanation(
      baseFeed: double.parse(base.toStringAsFixed(2)),
      trayImpact: tray,
      smartImpact: smart,
      finalFeed: double.parse(finalFeed.toStringAsFixed(2)),
      message: message,
      seedType: seedType,
      doc: doc,
      isSeedTablePhase: isSeedPhase,
      savingsRupees: savings != null ? double.parse(savings.toStringAsFixed(0)) : null,
    );
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  static double _fallbackFeed(int doc, int seedCount) {
    // Simple linear extension beyond the table range
    double kgPer100k;
    if (doc <= 30) {
      kgPer100k = 5.0;
    } else if (doc <= 40) {
      kgPer100k = 6.5;
    } else if (doc <= 50) {
      kgPer100k = 8.0;
    } else {
      kgPer100k = 10.0;
    }
    return kgPer100k * (seedCount / 100000);
  }

  static String _buildMessage(double tray, double smart, double? savings) {
    final parts = <String>[];

    if (tray < 0) {
      parts.add('Tray leftover detected → reduced by ${(-tray * 100).round()}%');
    } else if (tray > 0) {
      parts.add('Tray emptied fast → increased by ${(tray * 100).round()}%');
    }

    if (smart < 0) {
      parts.add('Conservative early phase → reduced by ${(-smart * 100).round()}%');
    } else if (smart > 0) {
      parts.add('Growth push phase → increased by ${(smart * 100).round()}%');
    }

    if (savings != null && savings > 0) {
      parts.add('Saved ₹${savings.round()} by avoiding overfeeding');
    }

    if (parts.isEmpty) return 'Feed on track — no adjustments needed';
    return parts.join(' · ');
  }
}
