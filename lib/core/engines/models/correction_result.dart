// CorrectionResult — output of the SmartFeedEngineV2 correction step as
// surfaced by FeedOrchestrator. Carries the full factor breakdown used by
// FeedDecisionEngine, FeedService debug logging, and the debug dashboard.

class CorrectionResult {
  /// Final recommended feed after all corrections (kg).
  final double finalFeed;

  /// Factor breakdown for debug / display.
  final double trayFactor;
  final double growthFactor;

  /// Sampling confidence decay — V2 bakes this into growthFactor; always 1.0.
  final double samplingFactor;

  /// Water quality risk factor (0.0 = critical stop).
  final double environmentFactor;

  final double fcrFactor;

  /// Intelligence deviation factor — removed from V2 pipeline; always 1.0.
  final double intelligenceFactor;

  /// Combined guarded factor (ratio of finalFeed to baseFeed, clamped ±30%).
  final double combinedFactor;

  /// Human-readable reasons for each non-neutral factor.
  final List<String> reasons;

  /// Alerts that may require farmer attention.
  final List<String> alerts;

  /// True when environment factor caused a complete feed stop.
  final bool isCriticalStop;

  const CorrectionResult({
    required this.finalFeed,
    required this.trayFactor,
    required this.growthFactor,
    required this.samplingFactor,
    required this.environmentFactor,
    required this.fcrFactor,
    required this.intelligenceFactor,
    required this.combinedFactor,
    required this.reasons,
    required this.alerts,
    required this.isCriticalStop,
  });
}
