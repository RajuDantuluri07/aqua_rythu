// Feed Orchestrator — Pure Computation Entry Point
//
// Pipeline:
//   INPUTS (FeedInput from DB)
//     ↓
//   MasterFeedEngine        → base expected feed (DOC ramp, density scaling)
//     ↓
//   FeedStageResolver       → blind | transitional | intelligent
//     ↓
//   FeedIntelligenceEngine  → expected vs actual, deviation, status
//     ↓
//   SmartFeedEngine         → apply corrections (tray, growth, environment, FCR)
//     ↓
//   OrchestratorResult (returned to caller — NO DB writes here)
//
// DB persistence (applyTrayAdjustment, recalculateFeedPlan) lives in FeedService.
// UI and providers call computeForPond() for computation.
// UI and providers call FeedService for computation + persistence.

import '../enums/feed_stage.dart';
import 'fcr_engine.dart';
import 'feed_decision_engine.dart';
import 'feed_input_builder.dart';
import 'feed_intelligence_engine.dart';
import 'feed_recommendation_engine.dart';
import 'master_feed_engine.dart';
import 'smart_feed_engine.dart';
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

  /// Stage 3: Correction factors from SmartFeedEngine.
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
    final intelligence = FeedIntelligenceEngine.compute(
      expectedFeed: baseFeed,
      actualFeedYesterday: input.actualFeedYesterday,
    );

    // ── Stage 2b: FCR factor (intelligent stage only) ─────────────────────
    final fcrFactor = feedStage == FeedStage.intelligent
        ? FCREngine.correction(input.lastFcr)
        : 1.0;

    // ── Stage 3: Smart corrections ────────────────────────────────────────
    final correction = SmartFeedEngine.apply(
      baseFeed: baseFeed,
      intelligence: intelligence,
      doc: input.doc,
      trayStatuses: input.trayStatuses,
      recentTrayLeftoverPct: input.recentTrayLeftoverPct,
      abw: input.abw,
      sampleAgeDays: input.sampleAgeDays,
      fcrFactor: fcrFactor,
      dissolvedOxygen: input.dissolvedOxygen,
      ammonia: input.ammonia,
    );

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
