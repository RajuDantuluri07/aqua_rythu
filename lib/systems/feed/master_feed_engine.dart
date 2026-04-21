// Master Feed Engine — Single Source of Truth for all feed computation
//
// Responsibilities:
//   1. Base feed calculation (DOC ramp + density scaling)
//   2. Full pipeline orchestration: base → stage → intelligence → corrections →
//      decision → recommendation
//
// Pipeline (orchestrate / orchestrateForPond):
//   INPUTS (FeedInput from DB)
//     ↓
//   compute()               → base expected feed (DOC ramp, density scaling)
//     ↓
//   FeedStageResolver       → blind | transitional | intelligent
//     ↓
//   FeedIntelligenceEngine  → expected vs actual, deviation, status
//     ↓
//   SmartFeedEngineV2       → apply corrections (tray, growth, environment, FCR)
//     ↓
//   FeedDecisionEngine      → Increase / Reduce / Maintain / Stop
//     ↓
//   FeedRecommendationEngine → next feed quantity and timing
//     ↓
//   OrchestratorResult (returned to caller — NO DB writes here)
//
// Sub-engines are pure helpers called only from here.
// DB persistence lives in FeedService.

import '../../../features/feed/enums/feed_stage.dart';
import '../../../features/tray/enums/tray_status.dart';
import '../../../features/pond/enums/stocking_type.dart';
import '../../../core/validators/feed_input_validator.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/feed_config_constants.dart';
// import '../growth/fcr_engine.dart'; // ❌ DISABLED FOR V1
import 'feed_decision_engine.dart'; // Used for FeedDecision result
import 'feed_input_builder.dart';
import 'feed_intelligence_engine.dart'; // Used for IntelligenceResult
import 'feed_recommendation_engine.dart'; // Used for FeedRecommendation result
// import 'smart_feed_engine_v2.dart'; // ❌ DISABLED FOR V1 LAUNCH
import '../../../features/feed/models/feed_input.dart';
import '../../../features/feed/models/correction_result.dart';
import '../../../features/feed/models/feed_debug_info.dart';
import '../../../features/feed/models/orchestrator_result.dart';
import 'engine_constants.dart';
export '../../../features/feed/models/correction_result.dart';
export '../../../features/feed/models/feed_debug_info.dart';
export '../../../features/feed/models/orchestrator_result.dart';

// ── ABSOLUTE SAFETY CAPS ──────────────────────────────────────────────────────

/// Global hard floor — final feed never below this value (kg).
const double kAbsoluteMinFeed = 0.1;

/// Global hard ceiling — final feed never above this value (kg).
const double kAbsoluteMaxFeed = 50.0;

/// Minimum DOC for smart-mode corrections (SmartFeedEngineV2, FCR, intelligence).
/// DOC ≤ this value = blind phase; DOC > this value = smart phase.
const int kSmartModeMinDoc = 30;

// ── DEBUG MODEL ───────────────────────────────────────────────────────────────

/// Step-by-step debug output from [MasterFeedEngine.computeWithDebug].
class FeedDebugData {
  final int doc;
  final StockingType stockingType;
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

  // ── BASE FEED (DOC RAMP + DENSITY SCALING) ────────────────────────────────

  /// Calculate base expected feed (kg) for a given DOC.
  ///
  /// [doc]             Day of Culture (1-based).
  /// [stockingType]    Stocking type enum.
  /// [density]         Live stocking count (shrimp). Scales linearly.
  ///
  /// NOTE: Tray adjustments are NOT applied here — they belong in SmartFeedEngineV2.
  static double compute({
    required int doc,
    required StockingType stockingType,
    required int density,
  }) {
    return computeWithDebug(
      doc: doc,
      stockingType: stockingType,
      density: density,
    ).finalFeed;
  }

  /// Same as [compute] but returns every intermediate step for the debug panel.
  static FeedDebugData computeWithDebug({
    required int doc,
    required StockingType stockingType,
    required int density,
  }) {
    // ── Step 0: Validation ────────────────────────────────────────────────
    final int validatedDoc = doc < 1 ? 1 : doc;
    final int validatedDensity = density <= 0 ? 100000 : density;

    // ── Step 0b: Input clamping ───────────────────────────────────────────
    final int safeDoc = validatedDoc.clamp(1, FeedConfig.maxDoc);
    final int safeDensity = validatedDensity.clamp(1000, 1000000);
    final bool wasInputClamped = doc != safeDoc || density != safeDensity;

    // ── Step 1: Base feed (kg per 100 K shrimp) ───────────────────────────
    final double base = FeedConfig.baseFeedPer100k(safeDoc, stockingType);

    // ── Step 2: Density scaling ───────────────────────────────────────────
    final double adjustedBase = base * (safeDensity / 100000);

    // ── Step 3: Safety clamp (±30%) ───────────────────────────────────────
    final double minFeed = adjustedBase * FeedEngineConstants.minFeedFactor;
    final double maxFeed = adjustedBase * FeedEngineConstants.maxFeedFactor;
    double final_ = adjustedBase.clamp(minFeed, maxFeed);

    // ── Step 3b: Density-proportional hard cap ───────────────────────────
    // kAbsoluteMaxFeed (50 kg) is defined per 100K shrimp. A 500K-shrimp pond
    // legitimately needs up to 250 kg/day at late DOC — the fixed 50 kg cap
    // would silently underfeed by ~47 % at maximum stocking density.
    final double effectiveMaxFeed =
        ((safeDensity / 100000.0) * kAbsoluteMaxFeed)
            .clamp(kAbsoluteMaxFeed, 500.0);
    final_ = final_.clamp(kAbsoluteMinFeed, effectiveMaxFeed);
    if (final_.isNaN || final_.isInfinite) {
      final_ = adjustedBase.clamp(kAbsoluteMinFeed, effectiveMaxFeed);
    }

    final bool clamped = (adjustedBase - final_).abs() > 0.001;

    final result = FeedDebugData(
      doc: safeDoc,
      stockingType: stockingType,
      density: safeDensity,
      baseFeed: double.parse(base.toStringAsFixed(3)),
      adjustedFeed: double.parse(adjustedBase.toStringAsFixed(3)),
      trayFactor: 1.0, // Tray logic removed from base compute
      rawFeed:
          double.parse(adjustedBase.toStringAsFixed(3)), // No tray adjustment
      finalFeed: double.parse(final_.toStringAsFixed(3)),
      minFeed: double.parse(minFeed.toStringAsFixed(3)),
      maxFeed: double.parse(maxFeed.toStringAsFixed(3)),
      isClamped: clamped,
      leftover: null, // Tray logic removed from base compute
      trayActive: false, // Tray logic removed from base compute
      trayStatusReason: 'Tray handled by SmartFeedEngineV2 only',
      wasInputClamped: wasInputClamped,
    );

    _logFeed(result);
    return result;
  }

  // ── FULL PIPELINE ORCHESTRATION ───────────────────────────────────────────
  // V1 SIMPLIFIED: Single deterministic flow
  // Step 1: Base Feed (DOC ramp + density scaling)
  // Step 2: Tray Factor (simple appetite signal)
  // Step 3: Apply Factor
  // Step 4: Safety Clamp (±30% from base)
  // Step 5: Return result

  /// Run the simplified feed pipeline from a pre-built [FeedInput].
  ///
  /// Pure — no DB writes. Use [orchestrateForPond] when the caller only has
  /// a pondId and needs DB state fetched first.
  static OrchestratorResult orchestrate(FeedInput input) {
    FeedInputValidator.validate(input);

    // ── STEP 0: Critical DO safety — enforced for ALL DOC ─────────────────
    if (input.dissolvedOxygen < 3.5) {
      AppLogger.error(
        '[MasterFeedEngine] Critical DO (${input.dissolvedOxygen} mg/L) '
        'at DOC ${input.doc} — stopping feed',
      );
      return OrchestratorResult.stopFeed(
        reason: 'Critical DO',
        engineVersion: version,
        doc: input.doc,
      );
    }

    // ── STEP 1: Base Feed (keep existing compute logic) ───────────────────
    final stage1Debug = computeWithDebug(
      doc: input.doc,
      stockingType: input.stockingType,
      density: input.seedCount,
    );
    final baseFeed = (input.doc > kSmartModeMinDoc && input.anchorFeed != null)
        ? input.anchorFeed!
        : stage1Debug.finalFeed;

    // ── STEP 2: Tray Factor (simple & deterministic) ───────────────────────
    final trayFactor = _simpleTrayFactor(input.trayStatuses);

    // ── STEP 3: Apply factor ──────────────────────────────────────────────
    double feed = baseFeed * trayFactor;

    // ── STEP 4: Safety Clamp (prevent spikes — ±30% from baseFeed) ────────
    final minFeed = baseFeed * FeedEngineConstants.minFeedFactor; // 0.7
    final maxFeed = baseFeed * FeedEngineConstants.maxFeedFactor; // 1.3
    feed = feed.clamp(minFeed, maxFeed);

    final bool wasClamped = (baseFeed * trayFactor - feed).abs() > 0.001;
    final clampReason = wasClamped
        ? (baseFeed * trayFactor) > maxFeed
            ? 'Feed increase capped at +30%'
            : 'Feed reduction capped at -30%'
        : null;

    final finalFeed = double.parse(feed.toStringAsFixed(3));

    // ── STEP 5: Build minimal result objects for backward compatibility ────
    final feedStage = FeedStageResolver.resolve(
      doc: input.doc,
      hasSampling: input.abw != null,
    );

    // Minimal intelligence result
    const intelligence = IntelligenceResult(
      expectedFeed: 0.0,
      status: FeedStatus.onTrack,
    );

    // Minimal correction result (all factors = 1.0 except tray)
    final correction = CorrectionResult(
      finalFeed: finalFeed,
      trayFactor: trayFactor,
      growthFactor: 1.0, // ❌ DISABLED
      samplingFactor: 1.0,
      environmentFactor: 1.0, // ❌ DISABLED (DO already checked)
      fcrFactor: 1.0, // ❌ DISABLED
      intelligenceFactor: 1.0, // ❌ DISABLED
      v2Factor: trayFactor, // Only tray factor in V1
      combinedFactor: trayFactor,
      reasons: trayFactor != 1.0
          ? ['Tray appetite adjustment: ${_factorToPercent(trayFactor)}']
          : [],
      alerts: const [],
      isCriticalStop: false,
      isSmartApplied: false,
      factorBreakdown: {'tray': trayFactor},
      factorExplanations: trayFactor != 1.0
          ? {
              'tray': trayFactor >= 1.10
                  ? 'Clean tray — good appetite'
                  : trayFactor >= 1.05
                      ? 'Light leftover — acceptable'
                      : trayFactor <= 0.70
                          ? 'High leftover — reduce feeding'
                          : 'Moderate leftover — stable',
            }
          : {},
      wasCombinedClamped: wasClamped,
      clampReason: clampReason,
    );

    // Minimal decision
    final decision = FeedDecision(
      action: finalFeed > 0 ? 'Maintain Feeding' : 'Stop Feeding',
      deltaKg: finalFeed - baseFeed,
      reason: 'V1 simplified flow — tray adjustment only',
      recommendations: const [],
      decisionTrace: [
        'Base (DOC ramp): ${baseFeed.toStringAsFixed(3)} kg',
        'Tray factor: ${trayFactor.toStringAsFixed(3)}',
        '= Final: ${finalFeed.toStringAsFixed(3)} kg',
      ],
    );

    // Minimal recommendation
    final recommendation = FeedRecommendation(
      nextFeedKg: finalFeed / 5, // Rough 5 feeds per day
      nextFeedTime: DateTime.now().add(const Duration(hours: 4)),
      instruction: 'Feed ${(finalFeed / 5).toStringAsFixed(1)} kg',
    );

    AppLogger.info(
      'FEED_PIPELINE_V1_SIMPLIFIED',
      {
        'doc': input.doc,
        'baseFeed': baseFeed,
        'trayFactor': trayFactor,
        'finalFeed': finalFeed,
        'isClamped': wasClamped,
      },
    );

    // ── STEP 5: Return result ─────────────────────────────────────────────
    return OrchestratorResult(
      baseFeed: baseFeed,
      feedStage: feedStage,
      intelligence: intelligence,
      correction: correction,
      decision: decision,
      recommendation: recommendation,
      engineVersion: version,
      debugInfo: FeedDebugInfo(
        doc: input.doc,
        baseFeedPer100k: stage1Debug.baseFeed,
        adjustedFeed: stage1Debug.adjustedFeed,
        minFeed: stage1Debug.minFeed,
        maxFeed: stage1Debug.maxFeed,
        isBaseFeedClamped: stage1Debug.isClamped,
        wasInputClamped: stage1Debug.wasInputClamped,
        baseFeed: baseFeed,
        trayFactor: trayFactor,
        smartFactor: trayFactor,
        combinedFactor: trayFactor,
        rawCombinedFactor: baseFeed * trayFactor,
        fcr: 1.0,
        finalFeed: finalFeed,
        isSmartApplied: false,
        wasClamped: wasClamped,
        clampReason: clampReason,
        hasSampling: input.abw != null,
        feedStage: feedStage.name,
        v2Debug: null, // ❌ DISABLED
      ),
    );
  }

  /// Fetch pond state from DB, then run the full pipeline.
  ///
  /// Use [FeedService.applyTrayAdjustment] or [FeedService.recalculateFeedPlan]
  /// when you also need to persist the result to feed_rounds.
  static Future<OrchestratorResult> orchestrateForPond(String pondId) async {
    // 🔥 VERIFICATION LOG: Should print ONLY ONCE per pond load (via Controller cache)
    AppLogger.info('🔥 FEED ENGINE CALLED: pond=$pondId');

    final input = await FeedInputBuilder.fromDB(pondId);
    return orchestrate(input);
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  /// Simple tray factor based on tray status.
  ///
  /// ✅ DETERMINISTIC:
  /// - full > empty → reduce feeding (shrimp not eating) → 0.85
  /// - empty > full → increase feeding (clean trays, good appetite) → 1.1
  /// - balanced or no data → 1.0
  ///
  /// ❌ DISABLED FEATURES:
  /// - Tray history analysis
  /// - ABW-based growth signal
  /// - Water quality factors
  /// - DOC-based conservatism
  static double _simpleTrayFactor(List<TrayStatus>? trays) {
    if (trays == null || trays.isEmpty) {
      return 1.0; // Default — no tray data
    }

    int full = 0;
    int empty = 0;

    for (final status in trays) {
      switch (status) {
        case TrayStatus.full:
          full++;
          break;
        case TrayStatus.empty:
          empty++;
          break;
        case TrayStatus.partial:
          // Neutral — don't count
          break;
      }
    }

    if (full > empty) {
      return 0.85; // More full trays — reduce feeding
    } else if (empty > full) {
      return 1.1; // More empty trays — increase feeding
    } else {
      return 1.0; // Balanced — no adjustment
    }
  }

  /// Convert factor to human-readable percentage change.
  /// Used for UI display.

  /// ❌ DISABLED FOR V1 LAUNCH
  /// Intelligence factor calculation — no longer used
  /// Replaced by simple tray-only logic
  static double _intelligenceFactor(IntelligenceResult intel) {
    if (!intel.hasActualData) return 1.0;

    final deviation = intel.deviationPercent;
    if (deviation == null) return 1.0;

    double factor = 1.0;

    if (deviation > FeedEngineConstants.intelligenceHighThreshold) {
      factor = FeedEngineConstants.intelligenceHighFactor;
    } else if (deviation > FeedEngineConstants.intelligenceLowThreshold) {
      factor = FeedEngineConstants.intelligenceMediumFactor;
    } else if (deviation < -FeedEngineConstants.intelligenceHighThreshold) {
      factor = FeedEngineConstants.intelligenceVeryLowFactor;
    } else if (deviation < -FeedEngineConstants.intelligenceLowThreshold) {
      factor = FeedEngineConstants.intelligenceLowFactor;
    }

    return factor.clamp(
        FeedEngineConstants.minFeedFactor, FeedEngineConstants.maxFeedFactor);
  }

  /// ❌ DISABLED FOR V1 LAUNCH
  /// Old multi-factor explanation builder — no longer used
  /// Replaced by simple tray-only logic

  /// ❌ DISABLED FOR V1 LAUNCH
  /// Old multi-factor explanation builder — no longer used
  /// Replaced by simple tray-only logic
  static String _factorToPercent(double factor) {
    final pct = ((factor - 1.0) * 100).round();
    if (pct > 0) return '+$pct%';
    if (pct < 0) return '$pct%';
    return '0%';
  }

  /// ❌ DISABLED FOR V1 LAUNCH
  /// Old multi-factor explanation builder — no longer used
  /// Replaced by simple tray-only logic
  static Map<String, String> _buildFactorExplanations({
    required double trayFactor,
    required double growthFactor,
    required double waterFactor,
    required double fcrFactor,
    required double intelligenceFactor,
    required String intelligenceLabel,
  }) {
    final reasons = <String, String>{};

    if ((trayFactor - 1.0).abs() > 0.01) {
      final label = trayFactor >= 1.10
          ? 'Clean tray — shrimp eating well'
          : trayFactor >= 1.05
              ? 'Light leftover — good appetite'
              : trayFactor <= 0.70
                  ? 'Very high leftover'
                  : 'Moderate leftover';
      reasons['tray'] = '$label → ${_factorToPercent(trayFactor)}';
    }

    if ((growthFactor - 1.0).abs() > 0.01) {
      final label =
          growthFactor >= 1.05 ? 'Good growth' : 'Below-expected growth';
      reasons['growth'] = '$label → ${_factorToPercent(growthFactor)}';
    }

    if (waterFactor < 1.0) {
      final label = waterFactor <= 0.80 ? 'High water risk' : 'Water stress';
      reasons['environment'] = '$label → ${_factorToPercent(waterFactor)}';
    }

    if ((fcrFactor - 1.0).abs() > 0.01) {
      final label =
          fcrFactor > 1.0 ? 'Underfeeding detected' : 'Overfeeding detected';
      reasons['fcr'] = '$label → ${_factorToPercent(fcrFactor)}';
    }

    if ((intelligenceFactor - 1.0).abs() > 0.01) {
      reasons['intelligence'] =
          'Feed deviation ($intelligenceLabel) → ${_factorToPercent(intelligenceFactor)}';
    }

    return reasons;
  }
}
