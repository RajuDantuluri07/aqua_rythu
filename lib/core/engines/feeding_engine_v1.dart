/// Feeding Engine V1 — Single Source of Truth
///
/// All feed calculations MUST go through [calculateFeed].
/// No biomass, no survival rates, no FCR, no 235 normalization.
///
/// Formula:
///   1. Base Feed  → DOC-linear ramp per stocking type
///   2. Density Scaling → base × (density / 100000)
///   3. Tray Factor → adjust based on leftover % (tray active after threshold DOC)
///   4. Safety Clamp → ±30% of density-scaled base
///
/// TEST CASES:
///   T1  DOC=1,  hatchery, density=100000, leftover=null  → ~2.00 kg
///   T2  DOC=15, hatchery, density=100000, leftover=null  → ~4.10 kg
///   T3  DOC=1,  nursery,  density=100000, leftover=null  → ~4.00 kg
///   T4  leftover=30%, tray active                        → feed decreases (factor 0.9)
///   T5  density=200000                                   → feed doubles vs density=100000

/// Step-by-step debug output from [FeedingEngineV1.calculateFeedWithDebug].
class FeedDebugData {
  final int doc;
  final String stockingType;
  final int density;

  /// Base feed (kg per 100K shrimp, before density scaling).
  final double baseFeed;

  /// After density scaling: baseFeed × (density / 100000).
  final double adjustedFeed;

  /// Tray adjustment factor (1.0 when tray inactive or no data).
  final double trayFactor;

  /// Raw feed before safety clamp: adjustedFeed × trayFactor.
  final double rawFeed;

  /// Final feed after safety clamp.
  final double finalFeed;

  /// Minimum allowed feed (adjustedFeed × 0.7).
  final double minFeed;

  /// Maximum allowed feed (adjustedFeed × 1.3).
  final double maxFeed;

  /// True when rawFeed was clamped to min or max.
  final bool isClamped;

  /// Tray leftover % used (null = no data).
  final double? leftover;

  /// Whether tray adjustment is active for this DOC + stocking type.
  final bool trayActive;

  const FeedDebugData({
    required this.doc,
    required this.stockingType,
    required this.density,
    required this.baseFeed,
    required this.adjustedFeed,
    required this.trayFactor,
    required this.rawFeed,
    required this.finalFeed,
    required this.minFeed,
    required this.maxFeed,
    required this.isClamped,
    required this.leftover,
    required this.trayActive,
  });
}

class FeedingEngineV1 {
  // ── TRAY ACTIVATION THRESHOLDS ───────────────────────────────────────────

  /// Tray adjustment activates at DOC 15 for hatchery, DOC 3 for nursery.
  static bool isTrayActive(String stockingType, int doc) {
    if (stockingType == 'hatchery') return doc >= 15;
    return doc >= 3; // nursery
  }

  // ── TRAY FACTOR ──────────────────────────────────────────────────────────

  /// Maps leftover percentage to a feed adjustment factor.
  ///
  /// 0%        → 1.1  (clean tray — shrimp hungry, increase feed)
  /// 1–10%     → 1.0  (trace leftover — on track)
  /// 11–25%    → 0.9  (moderate leftover — slight reduction)
  /// > 25%     → 0.75 (heavy leftover — reduce significantly)
  static double trayFactor(double leftoverPercent) {
    if (leftoverPercent == 0) return 1.1;
    if (leftoverPercent <= 10) return 1.0;
    if (leftoverPercent <= 25) return 0.9;
    return 0.75;
  }

  // ── MAIN CALCULATION ─────────────────────────────────────────────────────

  /// Calculate daily feed in kg.
  ///
  /// [doc]            Day of Culture (1-based).
  /// [stockingType]   'hatchery' or 'nursery'.
  /// [density]        Current stocking count (shrimp). Scales linearly.
  /// [leftoverPercent] Tray leftover % (null = no tray data, factor = 1.0).
  static double calculateFeed({
    required int doc,
    required String stockingType,
    required int density,
    double? leftoverPercent,
  }) {
    return calculateFeedWithDebug(
      doc: doc,
      stockingType: stockingType,
      density: density,
      leftoverPercent: leftoverPercent,
    ).finalFeed;
  }

  /// Same as [calculateFeed] but returns every intermediate step.
  /// Use this for the debug dashboard — compute once, show everything.
  static FeedDebugData calculateFeedWithDebug({
    required int doc,
    required String stockingType,
    required int density,
    double? leftoverPercent,
  }) {
    // Step 1: Base Feed (kg per 100K shrimp)
    final double base;
    if (stockingType == 'hatchery') {
      base = 2.0 + (doc - 1) * 0.15;
    } else {
      base = 4.0 + (doc - 1) * 0.25;
    }

    // Step 2: Density Scaling
    final double adjustedBase = base * (density / 100000);

    // Step 3: Tray Factor
    final bool active = isTrayActive(stockingType, doc);
    final double factor =
        (active && leftoverPercent != null) ? trayFactor(leftoverPercent) : 1.0;

    // Step 4: Raw Feed
    final double raw = adjustedBase * factor;

    // Step 5: Safety Clamp
    final double minFeed = adjustedBase * 0.7;
    final double maxFeed = adjustedBase * 1.3;
    final double final_ = raw.clamp(minFeed, maxFeed);
    final bool clamped = (raw - final_).abs() > 0.001;

    return FeedDebugData(
      doc: doc,
      stockingType: stockingType,
      density: density,
      baseFeed: double.parse(base.toStringAsFixed(3)),
      adjustedFeed: double.parse(adjustedBase.toStringAsFixed(3)),
      trayFactor: factor,
      rawFeed: double.parse(raw.toStringAsFixed(3)),
      finalFeed: double.parse(final_.toStringAsFixed(3)),
      minFeed: double.parse(minFeed.toStringAsFixed(3)),
      maxFeed: double.parse(maxFeed.toStringAsFixed(3)),
      isClamped: clamped,
      leftover: leftoverPercent,
      trayActive: active,
    );
  }
}
