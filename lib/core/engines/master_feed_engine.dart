// Master Feed Engine — Single Source of Truth for Base Feed
//
// Responsibilities:
//   1. DOC-based feed ramp (linear curve per stocking type)
//   2. Density scaling
//   3. Tray factor (during initial plan generation only)
//   4. Safety clamps (±30% of density-scaled base, absolute 0.1–50 kg)
//
// MUST NOT:
//   - Apply tray corrections at runtime
//   - Use growth data
//   - Use FCR
//   - Use biomass
//
// All factor adjustments are applied downstream by SmartFeedEngine.
// The single orchestration path is FeedOrchestrator.

// Fix: import must appear before declarations (Dart directive order rule)
import '../utils/logger.dart';

// ── ABSOLUTE SAFETY CAPS ──────────────────────────────────────────────────────

/// Global hard floor — final feed never below this value (kg).
const double kAbsoluteMinFeed = 0.1;

/// Global hard ceiling — final feed never above this value (kg).
const double kAbsoluteMaxFeed = 50.0;

// ── DEBUG MODEL ───────────────────────────────────────────────────────────────

/// Step-by-step debug output from [MasterFeedEngine.computeWithDebug].
class FeedDebugData {
  final int doc;
  final String stockingType;
  final int density;

  /// Base feed per 100 K shrimp before density scaling (kg).
  final double baseFeed;

  /// After density scaling: baseFeed × (density / 100 000).
  final double adjustedFeed;

  /// Tray adjustment factor (1.0 when tray inactive or no data).
  final double trayFactor;

  /// Raw feed before safety clamp: adjustedFeed × trayFactor.
  final double rawFeed;

  /// Final feed after safety clamp.
  final double finalFeed;

  /// Minimum allowed feed (adjustedFeed × 0.70).
  final double minFeed;

  /// Maximum allowed feed (adjustedFeed × 1.30).
  final double maxFeed;

  /// True when rawFeed was clamped.
  final bool isClamped;

  /// Tray leftover % used (null = no data).
  final double? leftover;

  /// Whether tray adjustment is active for this DOC + stocking type.
  final bool trayActive;

  /// Human-readable reason for tray factor decision.
  final String trayStatusReason;

  /// True when any input was silently clamped to its safe range.
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

// ── DEBUG LOGGER ──────────────────────────────────────────────────────────────

/// Fix: use AppLogger (respects debug/release mode) instead of raw print
/// which fires on every feed calculation and floods production logs.
void _logFeed(FeedDebugData d) {
  AppLogger.debug(
    '[MasterFeedEngine] DOC=${d.doc} density=${d.density} '
    'base=${d.baseFeed} kg trayFactor=${d.trayFactor} '
    'final=${d.finalFeed} kg',
  );
}

// ── ENGINE ────────────────────────────────────────────────────────────────────

class MasterFeedEngine {
  static const String version = 'v2.0.0';

  // ── TRAY ACTIVATION ───────────────────────────────────────────────────────

  /// Tray adjustment activates at DOC 15 for hatchery, DOC 3 for nursery.
  /// Only used during plan generation — runtime corrections use SmartFeedEngine.
  static bool isTrayActive(String stockingType, int doc) {
    if (stockingType == 'hatchery') return doc >= 15;
    return doc >= 3;
  }

  /// Maps leftover percentage → feed factor.
  ///
  ///   0 %      → 1.10  (clean tray)
  ///   1–10 %   → 1.00  (trace leftover)
  ///   11–25 %  → 0.90  (moderate leftover)
  ///   > 25 %   → 0.75  (heavy leftover)
  static double trayFactor(double leftoverPercent) {
    if (leftoverPercent == 0) return 1.1;
    if (leftoverPercent <= 10) return 1.0;
    if (leftoverPercent <= 25) return 0.9;
    return 0.75;
  }

  // ── PRIMARY ENTRY POINTS ──────────────────────────────────────────────────

  /// Calculate base expected feed (kg) for a given DOC.
  ///
  /// [doc]             Day of Culture (1-based).
  /// [stockingType]    'hatchery' or 'nursery'.
  /// [density]         Live stocking count (shrimp). Scales linearly.
  /// [leftoverPercent] Tray leftover % — only used during plan generation
  ///                   (pass null at runtime; SmartFeedEngine applies tray).
  static double compute({
    required int doc,
    required String stockingType,
    required int density,
    double? leftoverPercent,
  }) {
    return computeWithDebug(
      doc: doc,
      stockingType: stockingType,
      density: density,
      leftoverPercent: leftoverPercent,
    ).finalFeed;
  }

  /// Same as [compute] but returns every intermediate step for the debug panel.
  static FeedDebugData computeWithDebug({
    required int doc,
    required String stockingType,
    required int density,
    double? leftoverPercent,
  }) {
    // ── Step 0: Validation ────────────────────────────────────────────────
    // Production Safety: Instead of crashing with ArgumentError, 
    // we clamp and proceed with safe defaults.
    final int validatedDoc = doc < 1 ? 1 : doc;
    final int validatedDensity = density <= 0 ? 100000 : density;
    final String validatedType = (stockingType == 'hatchery' || stockingType == 'nursery') 
        ? stockingType 
        : 'hatchery';

    // ── Step 0b: Input clamping ───────────────────────────────────────────
    final int safeDoc = validatedDoc.clamp(1, 200);
    final int safeDensity = validatedDensity.clamp(1000, 1000000);
    final double? safeLeftover = leftoverPercent?.clamp(0.0, 100.0);
    final bool wasInputClamped =
        doc != safeDoc || density != safeDensity || leftoverPercent != safeLeftover;

    // ── Step 1: Base feed (kg per 100 K shrimp) ───────────────────────────
    final double base = stockingType == 'hatchery'
        ? 2.0 + (safeDoc - 1) * 0.15
        : 4.0 + (safeDoc - 1) * 0.25;

    // ── Step 2: Density scaling ───────────────────────────────────────────
    final double adjustedBase = base * (safeDensity / 100000);

    // ── Step 3: Tray factor (plan-generation only) ────────────────────────
    final bool active = isTrayActive(stockingType, safeDoc);
    final double factor =
        (active && safeLeftover != null) ? trayFactor(safeLeftover) : 1.0;

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

    // ── Step 4: Raw feed ──────────────────────────────────────────────────
    double raw = adjustedBase * factor;
    if (raw.isNaN || raw.isInfinite) raw = adjustedBase;

    // ── Step 5: Safety clamp (±30%) ───────────────────────────────────────
    final double minFeed = adjustedBase * 0.70;
    final double maxFeed = adjustedBase * 1.30;
    double final_ = raw.clamp(minFeed, maxFeed);

    // ── Step 5b: Density-proportional hard cap ───────────────────────────
    // kAbsoluteMaxFeed (50 kg) is defined per 100K shrimp. A 500K-shrimp pond
    // legitimately needs up to 250 kg/day at late DOC — the fixed 50 kg cap
    // would silently underfeed by ~47 % at maximum stocking density.
    final double effectiveMaxFeed =
        ((safeDensity / 100000.0) * kAbsoluteMaxFeed).clamp(kAbsoluteMaxFeed, 500.0);
    final_ = final_.clamp(kAbsoluteMinFeed, effectiveMaxFeed);
    if (final_.isNaN || final_.isInfinite) {
      final_ = adjustedBase.clamp(kAbsoluteMinFeed, effectiveMaxFeed);
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

    _logFeed(result);
    return result;
  }
}
