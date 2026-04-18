/// Typed debug snapshot of the full feed pipeline output.
///
/// Replaces the previous Map<String, dynamic> debugInfo on OrchestratorResult.
/// All fields are the exact values used in the computation — no transformations.
class FeedDebugInfo {
  final int doc;

  // ── Stage 1: Base feed breakdown ──────────────────────────────────────────

  /// Base feed per 100K shrimp before density scaling (kg).
  final double baseFeedPer100k;

  /// After density scaling, before safety clamp (kg).
  final double adjustedFeed;

  /// Safety lower bound: adjustedFeed × 0.70 (kg).
  final double minFeed;

  /// Safety upper bound: adjustedFeed × 1.30 (kg).
  final double maxFeed;

  /// True when adjustedFeed was safety-clamped.
  final bool isBaseFeedClamped;

  /// True when DOC or density was input-clamped before Stage 1.
  final bool wasInputClamped;

  // ── Stage 1 output / pipeline base ───────────────────────────────────────

  final double baseFeed;
  final double trayFactor;

  /// SmartFeedEngineV2 combined factor (before FCR + intelligence).
  final double smartFactor;

  /// Full combined factor (all corrections), clamped to [0.70, 1.30].
  final double combinedFactor;

  final double finalFeed;

  /// FCR correction factor.
  final double fcr;

  final bool isSmartApplied;

  /// Raw combined factor before clamping (V2 × FCR × intelligence).
  final double rawCombinedFactor;

  /// True when the raw combined factor was clamped to [0.70, 1.30].
  final bool wasClamped;

  /// Human-readable reason for clamping (null when not clamped).
  final String? clampReason;

  /// True when yesterday's actual feed data was available for intelligence.
  final bool hasSampling;

  /// Feed stage name: 'blind' | 'transitional' | 'intelligent'.
  final String feedStage;

  /// Full SmartFeedV2Result breakdown from toDebugMap().
  /// Null for blind phase and anchor-feed flow (V2 not run).
  final Map<String, dynamic>? v2Debug;

  const FeedDebugInfo({
    required this.doc,
    required this.baseFeedPer100k,
    required this.adjustedFeed,
    required this.minFeed,
    required this.maxFeed,
    required this.isBaseFeedClamped,
    required this.wasInputClamped,
    required this.baseFeed,
    required this.trayFactor,
    required this.smartFactor,
    required this.combinedFactor,
    required this.rawCombinedFactor,
    required this.finalFeed,
    required this.fcr,
    required this.isSmartApplied,
    required this.wasClamped,
    this.clampReason,
    required this.hasSampling,
    required this.feedStage,
    this.v2Debug,
  });
}
