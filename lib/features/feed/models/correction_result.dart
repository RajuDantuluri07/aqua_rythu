class CorrectionResult {
  final double baseFeed;
  final double trayFactor;
  final double finalFeed;
  final String safetyStatus; // normal / stopped

  final List<String> reasons;
  final List<String> alerts;
  final bool isCriticalStop;
  final bool isSmartApplied;

  /// True when the tray factor was clamped to safety limits.
  final bool wasClamped;

  /// Human-readable reason for clamping (null when not clamped).
  final String? clampReason;

  /// Convenience alias for trayFactor.
  double get factor => trayFactor;

  const CorrectionResult({
    required this.baseFeed,
    required this.trayFactor,
    required this.finalFeed,
    required this.safetyStatus,
    required this.reasons,
    required this.alerts,
    required this.isCriticalStop,
    required this.isSmartApplied,
    this.wasClamped = false,
    this.clampReason,
  });
}
