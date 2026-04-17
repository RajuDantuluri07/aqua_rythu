// Feed Orchestrator — Pure Computation Entry Point
//
// 🚫 DO NOT ADD BUSINESS LOGIC HERE
// This layer only orchestrates engine calls.
// All feed corrections live in SmartFeedEngineV2.
//
// Pipeline (FINAL — do not insert extra multipliers):
//   INPUTS (FeedInput from DB)
//     ↓
//   MasterFeedEngine        → base expected feed (DOC ramp, density scaling)
//     ↓
//   FeedStageResolver       → blind | transitional | intelligent
//     ↓
//   FeedIntelligenceEngine  → expected vs actual, deviation, status
//     ↓
//   SmartFeedEngineV2       → apply ALL corrections (tray, growth, water, DOC)
//     ↓
//   FCREngine               → single FCR multiplier (intelligent stage only)
//     ↓
//   combinedFactor.clamp(0.70, 1.30)  → ONLY clamp in this layer
//     ↓
//   OrchestratorResult (returned to caller — NO DB writes here)
//
// DB persistence (applyTrayAdjustment, recalculateFeedPlan) lives in FeedService.
// UI and providers call computeForPond() for computation.
// UI and providers call FeedService for computation + persistence.

import '../enums/feed_stage.dart';
import '../enums/tray_status.dart';
import '../validators/feed_input_validator.dart';
import 'fcr_engine.dart';
import 'feed_decision_engine.dart';
import 'feed_input_builder.dart';
import 'feed_intelligence_engine.dart';
import 'feed_recommendation_engine.dart';
import 'master_feed_engine.dart';
import 'models/correction_result.dart';
import 'smart_feed_engine_v2.dart';
import 'models/feed_input.dart';
import '../utils/logger.dart';

// ── ORCHESTRATOR RESULT ───────────────────────────────────────────────────────

/// Full pipeline result returned by [FeedOrchestrator.compute].
class OrchestratorResult {
  /// Stage 1: Base expected feed from MasterFeedEngine (kg).
  final double baseFeed;

  /// Feed stage resolved from DOC + sampling state.
  final FeedStage feedStage;

  /// Stage 2: Intelligence analysis (expected vs actual).
  final IntelligenceResult intelligence;

  /// Stage 3: Correction factors from SmartFeedEngineV2.
  final CorrectionResult correction;

  /// Stage 4: Decision — single action + reason + recommendations.
  final FeedDecision decision;

  /// Stage 5: Recommendation — next feed quantity and timing.
  final FeedRecommendation recommendation;

  /// Final recommended feed (= correction.finalFeed).
  double get finalFeed => correction.finalFeed;

  /// Combined factor applied to base feed.
  double get combinedFactor => correction.combinedFactor;

  const OrchestratorResult({
    required this.baseFeed,
    required this.feedStage,
    required this.intelligence,
    required this.correction,
    required this.decision,
    required this.recommendation,
  });
}

// ── ORCHESTRATOR ──────────────────────────────────────────────────────────────

class FeedOrchestrator {
  // ── PURE COMPUTATION ──────────────────────────────────────────────────────

  /// Run the full feed pipeline from a pre-built [FeedInput].
  ///
  /// Pure — no DB writes. Use this for testing or when the caller already
  /// has a [FeedInput] (e.g. debug dashboard, FeedService).
  static OrchestratorResult compute(FeedInput input) {
    FeedInputValidator.validate(input);

    // ── Stage 1: Base feed ────────────────────────────────────────────────
    final baseFeed = MasterFeedEngine.compute(
      doc: input.doc,
      stockingType: input.stockingType,
      density: input.seedCount,
    );

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
        ? MasterFeedEngine.compute(
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

    // ── Stage 3: Smart corrections (SmartFeedEngineV2 — single source) ──────
    // V2 handles: tray appetite, growth/ABW, water quality, DOC-stage factor.
    // FCR is applied on top (intelligent stage only). Nothing else touches feed.
    //
    // Tray history prep:
    //   FeedInputBuilder returns recentTrayLeftoverPct newest-first and excludes
    //   today. V2._resolveLatestLeftover treats the LAST element as most recent,
    //   so we reverse to oldest-first, then append today's live reading (if any).
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

    final v2Result = SmartFeedEngineV2.calculate(
      baseFeed: baseFeed,
      doc: input.doc,
      recentTrayLeftoverPct: historicLeftovers,
      abw: input.abw,
      sampleAgeDays: input.sampleAgeDays,
      dissolvedOxygen: input.dissolvedOxygen,
      ammonia: input.ammonia,
    );

    // ── TICKET 1/3/4: Final feed pipeline — V2 is the ONLY correction source.
    // MasterFeedEngine → SmartFeedEngineV2 → FCR → clamp(0.70, 1.30) → FINAL.
    // No intelligenceFactor. Single clamp here; V2 has its own internal clamp.
    final CorrectionResult correction;
    if (v2Result.isCriticalStop) {
      correction = CorrectionResult(
        finalFeed: 0.0,
        trayFactor: 1.0,
        growthFactor: 1.0,
        samplingFactor: 1.0,
        environmentFactor: 0.0,
        fcrFactor: 1.0,
        intelligenceFactor: 1.0,
        combinedFactor: 0.0,
        reasons: v2Result.reasons,
        alerts: ['🚨 Critical DO — stop feeding'],
        isCriticalStop: true,
      );
    } else {
      // V2 finalFeed × FCR → ratio-clamp → final. One clamp, no extra multipliers.
      final rawFeedFinal = v2Result.finalFeed * fcrFactor;
      final combinedFactor = baseFeed > 0
          ? (rawFeedFinal / baseFeed).clamp(0.70, 1.30)
          : 1.0;
      final feedFinal = baseFeed * combinedFactor;

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
      ];

      correction = CorrectionResult(
        finalFeed: double.parse(feedFinal.toStringAsFixed(3)),
        trayFactor: v2Result.trayFactor,
        growthFactor: v2Result.growthFactor,
        samplingFactor: 1.0, // V2 bakes sampling decay into growthFactor
        environmentFactor: v2Result.waterFactor,
        fcrFactor: fcrFactor,
        intelligenceFactor: 1.0, // removed — no deviation enforcement outside V2
        combinedFactor: double.parse(combinedFactor.toStringAsFixed(3)),
        reasons: [...v2Result.reasons, ...extraReasons],
        alerts: alerts,
        isCriticalStop: false,
      );
    }

    // ── Output sanity check ───────────────────────────────────────────────
    // validateOutput was declared but never called — NaN / negative / extreme
    // values would silently propagate to the farmer UI and feed_rounds.
    if (!correction.isCriticalStop) {
      FeedInputValidator.validateOutput(correction.finalFeed, baseFeed);
    }

    // ── Stage 4: Decision ─────────────────────────────────────────────
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

    final recommendation = FeedRecommendationEngine.compute(
      finalFeedPerDay: correction.finalFeed,
      decision: decision,
      lastFeedTime: input.lastFeedTime,
      doc: input.doc,
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
    );
  }

  /// Fetch pond state from DB, then run the full pipeline.
  ///
  /// Use [FeedService.applyTrayAdjustment] or [FeedService.recalculateFeedPlan]
  /// when you also need to persist the result to feed_rounds.
  static Future<OrchestratorResult> computeForPond(String pondId) async {
    final input = await FeedInputBuilder.fromDB(pondId);
    return compute(input);
  }
}
