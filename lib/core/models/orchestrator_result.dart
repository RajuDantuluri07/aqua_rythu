import '../enums/feed_stage.dart';
import '../engines/feed/feed_intelligence_engine.dart';
import '../engines/feed/feed_decision_engine.dart';
import '../engines/feed/feed_recommendation_engine.dart';
import 'correction_result.dart';
import 'feed_debug_info.dart';

class OrchestratorResult {
  /// Stage 1: Base expected feed from DOC ramp (kg).
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

  /// Typed debug snapshot of the pipeline for UI transparency.
  final FeedDebugInfo debugInfo;

  /// Engine version that produced this result (for traceability).
  final String engineVersion;

  // ── Convenience getters ───────────────────────────────────────────────────

  double get finalFeed => correction.finalFeed;
  double get combinedFactor => correction.combinedFactor;
  double get trayFactor => correction.trayFactor;
  double get smartFactor => correction.v2Factor;
  double get fcrFactor => correction.fcrFactor;
  double get fcr => correction.fcrFactor;
  bool get isSmartApplied => correction.isSmartApplied;

  const OrchestratorResult({
    required this.baseFeed,
    required this.feedStage,
    required this.intelligence,
    required this.correction,
    required this.decision,
    required this.recommendation,
    required this.engineVersion,
    required this.debugInfo,
  });

  factory OrchestratorResult.stopFeed({
    required String reason,
    required String engineVersion,
    required int doc,
  }) {
    const correction = CorrectionResult(
      finalFeed: 0.0,
      trayFactor: 1.0,
      growthFactor: 1.0,
      samplingFactor: 1.0,
      environmentFactor: 0.0,
      fcrFactor: 1.0,
      intelligenceFactor: 1.0,
      v2Factor: 0.0,
      combinedFactor: 0.0,
      reasons: ['Critical DO — stop feeding'],
      alerts: ['🚨 Critical DO — stop feeding'],
      isCriticalStop: true,
      isSmartApplied: false,
      factorBreakdown: {'environment': 0.0},
      factorExplanations: {'environment': 'CRITICAL — dissolved oxygen too low'},
    );
    const decision = FeedDecision(
      action: 'Stop Feeding',
      deltaKg: 0.0,
      reason: 'Dissolved oxygen critically low — stop feeding immediately',
      recommendations: ['Stop all feeding until DO recovers above 3.5 mg/L'],
      decisionTrace: ['Critical DO → feed = 0'],
    );
    final recommendation = FeedRecommendation(
      nextFeedKg: 0.0,
      nextFeedTime: DateTime.now(),
      instruction: 'Do not feed — dissolved oxygen critically low',
    );
    const intelligence = IntelligenceResult(
      expectedFeed: 0.0,
      status: FeedStatus.onTrack,
    );
    final debugInfo = FeedDebugInfo(
      doc: doc,
      baseFeedPer100k: 0.0,
      adjustedFeed: 0.0,
      minFeed: 0.0,
      maxFeed: 0.0,
      isBaseFeedClamped: false,
      wasInputClamped: false,
      baseFeed: 0.0,
      trayFactor: 1.0,
      smartFactor: 1.0,
      combinedFactor: 0.0,
      rawCombinedFactor: 0.0,
      fcr: 1.0,
      finalFeed: 0.0,
      isSmartApplied: false,
      wasClamped: false,
      hasSampling: false,
      feedStage: 'critical_stop',
    );
    return OrchestratorResult(
      baseFeed: 0.0,
      feedStage: FeedStage.blind,
      intelligence: intelligence,
      correction: correction,
      decision: decision,
      recommendation: recommendation,
      engineVersion: engineVersion,
      debugInfo: debugInfo,
    );
  }
}
