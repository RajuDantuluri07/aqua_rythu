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
  final FeedDebugInfo? debugInfo;

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
    this.debugInfo,
  });
}
