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

// ── ABSOLUTE SAFETY CAPS ─────────────────────────────────────────────────────

/// Global hard floor — final feed is never below this value (kg).
const double _kAbsoluteMinFeed = 0.1;

/// Global hard ceiling — final feed is never above this value (kg).
const double _kAbsoluteMaxFeed = 50.0;

// ── DEBUG LOGGER ─────────────────────────────────────────────────────────────

/// Lightweight debug logger called before every result is returned.
/// Uses [print] which only surfaces in debug builds via Flutter's console.
void logFeed(FeedDebugData data) {
  // ignore: avoid_print
  print(
    '[FeedingEngine] '
    'DOC=${data.doc} '
    'density=${data.density} '
    'base=${data.baseFeed} kg '
    'trayFactor=${data.trayFactor} '
    'final=${data.finalFeed} kg',
  );
}

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

  /// Human-readable reason why the tray factor was or was not applied.
  ///
  /// Examples:
  ///   "DOC < 15 → tray inactive"
  ///   "No leftover data → tray skipped"
  ///   "Tray applied (leftover 30%)"
  final String trayStatusReason;

  /// True when any input (doc, density, leftoverPercent) was silently clamped
  /// to its safe range. Surfaces to the debug panel so the farmer can see
  /// that the value they entered was out-of-range and was adjusted.
  final bool wasInputClamped;

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
    required this.trayStatusReason,
    required this.wasInputClamped,
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
  /// [doc]             Day of Culture (1-based).
  /// [stockingType]    'hatchery' or 'nursery'.
  /// [density]         Current stocking count (shrimp). Scales linearly.
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
  ///
  /// Throws [ArgumentError] for invalid inputs:
  ///   • doc < 1
  ///   • density <= 0
  ///   • stockingType not 'hatchery' or 'nursery'
  static FeedDebugData calculateFeedWithDebug({
    required int doc,
    required String stockingType,
    required int density,
    double? leftoverPercent,
  }) {
    // ── Step 0: Input Validation ──────────────────────────────────────────
    if (doc < 1) {
      throw ArgumentError('doc must be >= 1, got $doc');
    }
    if (density <= 0) {
      throw ArgumentError('density must be > 0, got $density');
    }
    if (stockingType != 'hatchery' && stockingType != 'nursery') {
      throw ArgumentError(
        "stockingType must be 'hatchery' or 'nursery', got '$stockingType'",
      );
    }

    // ── Step 0b: Input Clamping ───────────────────────────────────────────
    final int safeDoc = doc.clamp(1, 200);
    final int safeDensity = density.clamp(1000, 1000000);
    final double? safeLeftover =
        leftoverPercent != null ? leftoverPercent.clamp(0.0, 100.0) : null;

    // ── Step 1: Base Feed (kg per 100K shrimp) ────────────────────────────
    final double base;
    if (stockingType == 'hatchery') {
      base = 2.0 + (safeDoc - 1) * 0.15;
    } else {
      base = 4.0 + (safeDoc - 1) * 0.25;
    }

    // ── Step 2: Density Scaling ───────────────────────────────────────────
    final double adjustedBase = base * (safeDensity / 100000);

    // ── Step 0c: Input Clamp Awareness ───────────────────────────────────
    final bool wasInputClamped =
        doc != safeDoc ||
        density != safeDensity ||
        leftoverPercent != safeLeftover;

    // ── Step 3: Tray Factor ───────────────────────────────────────────────
    final bool active = isTrayActive(stockingType, safeDoc);
    final double factor =
        (active && safeLeftover != null) ? trayFactor(safeLeftover) : 1.0;

    // ── Step 3b: Tray Status Reason ───────────────────────────────────────
    final String trayStatusReason;
    if (!active) {
      final int threshold = stockingType == 'hatchery' ? 15 : 3;
      trayStatusReason = 'DOC < $threshold → tray inactive';
    } else if (safeLeftover == null) {
      trayStatusReason = 'No leftover data → tray skipped';
    } else {
      trayStatusReason =
          'Tray applied (leftover ${safeLeftover.toStringAsFixed(0)}%)';
    }

    // ── Step 4: Raw Feed ──────────────────────────────────────────────────
    // Defensive: fall back to adjustedBase if arithmetic produces NaN/Infinity.
    double raw = adjustedBase * factor;
    if (raw.isNaN || raw.isInfinite) raw = adjustedBase;

    // ── Step 5: Safety Clamp (±30%) ───────────────────────────────────────
    final double minFeed = adjustedBase * 0.7;
    final double maxFeed = adjustedBase * 1.3;
    double final_ = raw.clamp(minFeed, maxFeed);

    // ── Step 5b: Absolute Hard Cap ────────────────────────────────────────
    // Ensures feed is always in [0.1, 50] kg regardless of inputs.
    final_ = final_.clamp(_kAbsoluteMinFeed, _kAbsoluteMaxFeed);

    // Final NaN/Infinity guard — last-resort fallback before returning.
    if (final_.isNaN || final_.isInfinite) {
      final_ = adjustedBase.clamp(_kAbsoluteMinFeed, _kAbsoluteMaxFeed);
    }

    final bool clamped = (raw - final_).abs() > 0.001;

    final result = FeedDebugData(
      doc: safeDoc,
      stockingType: stockingType,
      density: safeDensity,
      baseFeed: double.parse(base.toStringAsFixed(3)),
      adjustedFeed: double.parse(adjustedBase.toStringAsFixed(3)),
      trayFactor: factor,
      rawFeed: double.parse(raw.toStringAsFixed(3)),
      finalFeed: double.parse(final_.toStringAsFixed(3)),
      minFeed: double.parse(minFeed.toStringAsFixed(3)),
      maxFeed: double.parse(maxFeed.toStringAsFixed(3)),
      isClamped: clamped,
      leftover: safeLeftover,
      trayActive: active,
      trayStatusReason: trayStatusReason,
      wasInputClamped: wasInputClamped,
    );

    logFeed(result);
    return result;
  }
}
