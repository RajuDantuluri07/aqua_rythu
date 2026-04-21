class CorrectionResult {
  final double finalFeed;
  final double trayFactor;
  final double growthFactor;
  final double samplingFactor;
  final double environmentFactor;
  final double fcrFactor;
  final double intelligenceFactor;

  /// Combined factor from SmartFeedEngineV2 alone (before FCR + intelligence).
  final double v2Factor;

  /// Full combined factor (V2 × FCR × intelligence), clamped to [0.70, 1.30].
  final double combinedFactor;

  final List<String> reasons;
  final List<String> alerts;
  final bool isCriticalStop;
  final bool isSmartApplied;

  /// Per-factor numeric breakdown — includes doc factor so the product equals
  /// the raw V2 combined factor (before clamping).
  final Map<String, double> factorBreakdown;

  /// User-readable explanation per factor (e.g. "Clean tray → +10%").
  final Map<String, String> factorExplanations;

  /// True when the raw combined factor was outside [0.70, 1.30] and clamped.
  final bool wasCombinedClamped;

  /// Human-readable reason for clamping (null when not clamped).
  final String? clampReason;

  /// Convenience alias for combinedFactor.
  double get factor => combinedFactor;

  const CorrectionResult({
    required this.finalFeed,
    required this.trayFactor,
    required this.growthFactor,
    required this.samplingFactor,
    required this.environmentFactor,
    required this.fcrFactor,
    required this.intelligenceFactor,
    required this.v2Factor,
    required this.combinedFactor,
    required this.reasons,
    required this.alerts,
    required this.isCriticalStop,
    required this.isSmartApplied,
    this.factorBreakdown = const {},
    this.factorExplanations = const {},
    this.wasCombinedClamped = false,
    this.clampReason,
  });
}
