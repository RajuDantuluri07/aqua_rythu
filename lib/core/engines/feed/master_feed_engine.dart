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

import '../../enums/feed_stage.dart';
import '../../enums/tray_status.dart';
import '../../enums/stocking_type.dart';
import '../../validators/feed_input_validator.dart';
import '../../utils/logger.dart';
import '../../utils/feed_config_constants.dart';
import '../growth/fcr_engine.dart';
import 'feed_decision_engine.dart';
import 'feed_input_builder.dart';
import 'feed_intelligence_engine.dart';
import 'feed_recommendation_engine.dart';
import 'smart_feed_engine_v2.dart';
import '../../models/feed_input.dart';
import '../../models/correction_result.dart';
import '../../models/feed_debug_info.dart';
import '../../models/orchestrator_result.dart';
import 'engine_constants.dart';
export '../../models/correction_result.dart';
export '../../models/feed_debug_info.dart';
export '../../models/orchestrator_result.dart';

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
        ((safeDensity / 100000.0) * kAbsoluteMaxFeed).clamp(kAbsoluteMaxFeed, 500.0);
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
      rawFeed: double.parse(adjustedBase.toStringAsFixed(3)), // No tray adjustment
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

  /// Run the full feed pipeline from a pre-built [FeedInput].
  ///
  /// Pure — no DB writes. Use [orchestrateForPond] when the caller only has
  /// a pondId and needs DB state fetched first.
  static OrchestratorResult orchestrate(FeedInput input) {
    FeedInputValidator.validate(input);

    // ── Critical DO safety — enforced for ALL DOC ─────────────────────────
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

    // ── Stage 1: Base feed ────────────────────────────────────────────────
    // computeWithDebug is called once to capture Stage 1 intermediate values
    // for FeedDebugInfo (baseFeedPer100k, adjustedFeed, min/max, clamp flags).
    // anchorFeed overrides the DOC-ramp output but we still compute for debug.
    final stage1Debug = computeWithDebug(
      doc: input.doc,
      stockingType: input.stockingType,
      density: input.seedCount,
    );
    final baseFeed = (input.doc > kSmartModeMinDoc && input.anchorFeed != null)
        ? input.anchorFeed!
        : stage1Debug.finalFeed;

    // ── Stage 1b: Resolve feed stage ──────────────────────────────────────
    final hasSampling = input.abw != null;
    final feedStage = FeedStageResolver.resolve(
      doc: input.doc,
      hasSampling: hasSampling,
    );

    // ── Stage 2: Intelligence (expected vs actual) ────────────────────────
    // Compare yesterday's actual against YESTERDAY's expected base feed, not
    // today's. Using today's baseFeed creates a systematic underfeeding signal
    // every day because today's ramp is always higher than yesterday's.
    final yesterdayBaseFeed = input.doc > 1
        ? compute(
            doc: input.doc - 1,
            stockingType: input.stockingType,
            density: input.seedCount,
          )
        : baseFeed;
    final intelligence = FeedIntelligenceEngine.compute(
      expectedFeed: yesterdayBaseFeed,
      actualFeedYesterday: input.actualFeedYesterday,
    );

    // ── Stage 2b: FCR factor (intelligent stage only) ─────────────────────
    final fcrFactor = feedStage == FeedStage.intelligent
        ? FCREngine.correction(input.lastFcr)
        : 1.0;

    // ── Stage 3: Smart corrections ────────────────────────────────────────
    // Tray history prep: FeedInputBuilder returns recentTrayLeftoverPct
    // newest-first and excludes today. V2._resolveLatestLeftover treats the
    // LAST element as most recent, so reverse to oldest-first, then append
    // today's live reading (if any).
    final historicLeftovers = input.recentTrayLeftoverPct
        .where((v) => v >= 0)
        .toList()
        .reversed
        .toList(); // now oldest → newest

    if (input.trayStatuses.isNotEmpty) {
      double sum = 0;
      for (final s in input.trayStatuses) {
        switch (s) {
          case TrayStatus.empty:
            break;
          case TrayStatus.partial:
            sum += 30.0;
            break;
          case TrayStatus.full:
            sum += 70.0;
            break;
        }
      }
      historicLeftovers.add(sum / input.trayStatuses.length);
    }

    // DOC ≤ 30 = blind phase: skip smart corrections entirely.
    // SmartFeedEngineV2 is only ever called for DOC > 30 (asserted inside).
    final v2Result = input.doc > kSmartModeMinDoc
        ? SmartFeedEngineV2.calculate(
            baseFeed: baseFeed,
            doc: input.doc,
            recentTrayLeftoverPct: historicLeftovers,
            abw: input.abw,
            sampleAgeDays: input.sampleAgeDays,
            dissolvedOxygen: input.dissolvedOxygen,
            ammonia: input.ammonia,
          )
        : SmartFeedEngineV2.blindPhaseResult(baseFeed, input.doc);

    AppLogger.debug('SMART_FEED_V2: ${v2Result.toDebugMap()}');

    final intelligenceFactor = _intelligenceFactor(intelligence);

    final CorrectionResult correction;
    final bool smartApplied = input.doc > kSmartModeMinDoc;
    double rawCombinedFactorSnap = 0.0;

    if (v2Result.isCriticalStop) {
      correction = CorrectionResult(
        finalFeed: 0.0,
        trayFactor: 1.0,
        growthFactor: 1.0,
        samplingFactor: 1.0,
        environmentFactor: 0.0,
        fcrFactor: 1.0,
        intelligenceFactor: 1.0,
        v2Factor: 0.0,
        combinedFactor: 0.0,
        reasons: v2Result.reasons,
        alerts: ['🚨 Critical DO — stop feeding'],
        isCriticalStop: true,
        isSmartApplied: smartApplied,
        factorBreakdown: const {
          'tray': 1.0,
          'growth': 1.0,
          'environment': 0.0,
          'fcr': 1.0,
          'intelligence': 1.0,
        },
        factorExplanations: const {
          'environment': 'CRITICAL — stop feeding (dissolved oxygen too low)',
        },
      );
    } else {
      // V2 factor = correctedFeed / baseFeed (the V2-only combined correction,
      // AFTER the V2 safety clamp).
      final v2Factor = baseFeed > 0 ? v2Result.correctedFeed / baseFeed : 1.0;

      // ── TASK 3: Breakdown integrity check ─────────────────────────────────
      // The product of individual V2 factors must equal rawProduct
      // (the pre-clamp V2 result). This catches any mismatch between what we
      // expose in factorBreakdown and what the engine actually computed.
      if (baseFeed > 0) {
        final breakdownV2Product = v2Result.trayFactor *
            v2Result.growthFactor *
            v2Result.waterFactor *
            v2Result.docFactor;
        assert(
          (breakdownV2Product - v2Result.rawProduct).abs() < 0.01,
          'Breakdown integrity: tray×growth×water×doc=$breakdownV2Product '
          '≠ rawProduct=$v2Result.rawProduct',
        );
      }

      // Apply FCR then deviation-enforcement on top of V2 corrected feed.
      // Guard: clamp the combined ratio first so finalFeed == baseFeed × combinedFactor always.
      final rawFeedFinal = v2Result.correctedFeed * fcrFactor * intelligenceFactor;
      final rawCombinedFactor =
          baseFeed > 0 ? rawFeedFinal / baseFeed : 1.0;
      final combinedFactor = rawCombinedFactor.clamp(FeedEngineConstants.minFeedFactor, FeedEngineConstants.maxFeedFactor);

      rawCombinedFactorSnap = rawCombinedFactor;
      final stackingImpact = rawCombinedFactor - combinedFactor;
      if (stackingImpact.abs() > 0.2) {
        AppLogger.warn('HIGH_STACKING', {
          'raw': rawCombinedFactor,
          'clamped': combinedFactor,
          'impact': stackingImpact,
        });
      }
      final feedFinal = baseFeed * combinedFactor;

      // ── TASK 2: Factor consistency assertion ──────────────────────────────
      // combinedFactor must be the clamped product of v2Factor × fcr × intelligence.
      assert(
        (combinedFactor -
                (v2Factor * fcrFactor * intelligenceFactor).clamp(FeedEngineConstants.minFeedFactor, FeedEngineConstants.maxFeedFactor))
                .abs() <
            0.01,
        'Factor mismatch: combinedFactor=$combinedFactor ≠ '
        'clamp(v2=$v2Factor × fcr=$fcrFactor × intel=$intelligenceFactor, ${FeedEngineConstants.minFeedFactor}, ${FeedEngineConstants.maxFeedFactor})',
      );

      // ── TASK 6: Clamp visibility ──────────────────────────────────────────
      final wasCombinedClamped = (rawCombinedFactor - combinedFactor).abs() > 0.001;
      final clampReason = wasCombinedClamped
          ? rawCombinedFactor > 1.30
              ? 'Feed increase capped at +30%'
              : 'Feed reduction capped at -30%'
          : null;

      final alerts = <String>[
        if (v2Result.waterFactor <= 0.0)
          '🚨 Critical DO — stop feeding'
        else if (v2Result.waterFactor < 1.0)
          v2Result.waterFactor <= 0.80
              ? '⚠️ High water risk — feed reduced'
              : '⚠️ Water stress — feed reduced',
      ];

      final extraReasons = <String>[
        if (fcrFactor != 1.0)
          'FCR adjustment: ${fcrFactor > 1.0 ? '+' : ''}${((fcrFactor - 1) * 100).toStringAsFixed(0)}%',
        if (intelligenceFactor != 1.0)
          'Deviation enforcement: ${intelligenceFactor > 1.0 ? '+' : ''}${((intelligenceFactor - 1) * 100).toStringAsFixed(0)}% (${intelligence.statusLabel})',
      ];

      correction = CorrectionResult(
        finalFeed: double.parse(feedFinal.toStringAsFixed(3)),
        trayFactor: v2Result.trayFactor,
        growthFactor: v2Result.growthFactor,
        samplingFactor: 1.0,
        environmentFactor: v2Result.waterFactor,
        fcrFactor: fcrFactor,
        intelligenceFactor: intelligenceFactor,
        v2Factor: double.parse(v2Factor.toStringAsFixed(3)),
        combinedFactor: double.parse(combinedFactor.toStringAsFixed(3)),
        reasons: [...v2Result.reasons, ...extraReasons],
        alerts: alerts,
        isCriticalStop: false,
        isSmartApplied: smartApplied,
        // Includes docFactor so product equals rawProduct/baseFeed (TASK 3).
        factorBreakdown: {
          'tray': v2Result.trayFactor,
          'growth': v2Result.growthFactor,
          'environment': v2Result.waterFactor,
          'doc': v2Result.docFactor,
          'fcr': fcrFactor,
          'intelligence': intelligenceFactor,
        },
        factorExplanations: _buildFactorExplanations(
          trayFactor: v2Result.trayFactor,
          growthFactor: v2Result.growthFactor,
          waterFactor: v2Result.waterFactor,
          fcrFactor: fcrFactor,
          intelligenceFactor: intelligenceFactor,
          intelligenceLabel: intelligence.statusLabel,
        ),
        wasCombinedClamped: wasCombinedClamped,
        clampReason: clampReason,
      );
    }

    // ── Output sanity check ───────────────────────────────────────────────
    if (!correction.isCriticalStop) {
      FeedInputValidator.validateOutput(correction.finalFeed, baseFeed);
    }

    // ── Stage 4: Decision ─────────────────────────────────────────────────
    final recommendations = FeedDecisionEngine.generateRecommendations(
      trayFactor: correction.trayFactor,
      growthFactor: correction.growthFactor,
      fcrFactor: correction.fcrFactor,
      confidenceScore: FeedDecisionEngine.confidenceForStage(feedStage),
      alerts: correction.alerts,
      isCriticalStop: correction.isCriticalStop,
    );

    final decisionTrace = [
      'Base (DOC ramp): ${baseFeed.toStringAsFixed(3)} kg',
      'Feed stage: ${feedStage.name}',
      'Intelligence: ${intelligence.statusLabel}',
      ...correction.reasons,
      if (correction.isCriticalStop) '⚠ CRITICAL STOP',
      '= Final: ${correction.finalFeed.toStringAsFixed(3)} kg',
    ];

    final decision = FeedDecisionEngine.compute(
      baseFeed: baseFeed,
      finalFeed: correction.finalFeed,
      intelligence: intelligence,
      stage: feedStage,
      trayFactor: correction.trayFactor,
      growthFactor: correction.growthFactor,
      environmentFactor: correction.environmentFactor,
      fcrFactor: correction.fcrFactor,
      intelligenceStatus: intelligence.status,
      hasActualData: intelligence.hasActualData,
      confidenceScore: FeedDecisionEngine.confidenceForStage(feedStage),
      alerts: correction.alerts,
      existingRecommendations: recommendations,
      decisionTrace: decisionTrace,
      isCriticalStop: correction.isCriticalStop,
    );

    // ── Stage 5: Recommendation ───────────────────────────────────────────
    final recommendation = FeedRecommendationEngine.compute(
      finalFeedPerDay: correction.finalFeed,
      decision: decision,
      lastFeedTime: input.lastFeedTime,
      doc: input.doc,
      minGapMinutes: input.doc > kSmartModeMinDoc ? 180 : 150,
    );

    AppLogger.info(
      'FEED_PIPELINE',
      {
        'stage': feedStage.name,
        'baseFeed': baseFeed,
        'finalFeed': correction.finalFeed,
        'trayFactor': correction.trayFactor,
        'growthFactor': correction.growthFactor,
        'envFactor': correction.environmentFactor,
        'fcrFactor': correction.fcrFactor,
        'intelligence': intelligence.statusLabel,
        'decision': decision.action,
        'nextFeedKg': recommendation.nextFeedKg,
        'nextFeedTime': recommendation.nextFeedTime.toIso8601String(),
      },
    );

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
        trayFactor: correction.trayFactor,
        smartFactor: correction.v2Factor,
        combinedFactor: correction.combinedFactor,
        rawCombinedFactor: rawCombinedFactorSnap,
        fcr: correction.fcrFactor,
        finalFeed: correction.finalFeed,
        isSmartApplied: correction.isSmartApplied,
        wasClamped: correction.wasCombinedClamped,
        clampReason: correction.clampReason,
        hasSampling: input.abw != null,
        feedStage: feedStage.name,
        v2Debug: input.doc > kSmartModeMinDoc ? v2Result.toDebugMap() : null,
      ),
    );
  }

  /// Fetch pond state from DB, then run the full pipeline.
  ///
  /// Use [FeedService.applyTrayAdjustment] or [FeedService.recalculateFeedPlan]
  /// when you also need to persist the result to feed_rounds.
  static Future<OrchestratorResult> orchestrateForPond(String pondId) async {
    final input = await FeedInputBuilder.fromDB(pondId);
    return orchestrate(input);
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

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

    return factor.clamp(FeedEngineConstants.minFeedFactor, FeedEngineConstants.maxFeedFactor);
  }

  static String _factorToPercent(double factor) {
    final pct = ((factor - 1.0) * 100).round();
    if (pct > 0) return '+$pct%';
    if (pct < 0) return '$pct%';
    return '0%';
  }

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
      final label = growthFactor >= 1.05 ? 'Good growth' : 'Below-expected growth';
      reasons['growth'] = '$label → ${_factorToPercent(growthFactor)}';
    }

    if (waterFactor < 1.0) {
      final label = waterFactor <= 0.80 ? 'High water risk' : 'Water stress';
      reasons['environment'] = '$label → ${_factorToPercent(waterFactor)}';
    }

    if ((fcrFactor - 1.0).abs() > 0.01) {
      final label = fcrFactor > 1.0 ? 'Underfeeding detected' : 'Overfeeding detected';
      reasons['fcr'] = '$label → ${_factorToPercent(fcrFactor)}';
    }

    if ((intelligenceFactor - 1.0).abs() > 0.01) {
      reasons['intelligence'] =
          'Feed deviation ($intelligenceLabel) → ${_factorToPercent(intelligenceFactor)}';
    }

    return reasons;
  }
}
