/// Typed debug snapshot of the full feed pipeline output.
///
/// Replaces the previous Map<String, dynamic> debugInfo on OrchestratorResult.
/// All fields are the exact values used in the computation — no transformations.
class FeedDebugInfo {
  final int doc;
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

  const FeedDebugInfo({
    required this.doc,
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
  });
}
