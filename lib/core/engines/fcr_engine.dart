class FCREngine {
  /// ✅ SMOOTH SCALING FCR MODEL (Production-Ready)
  /// 
  /// Rewards efficient fish (low FCR) and penalizes wasteful feeding (high FCR)
  /// with smooth, predictable transitions to maintain farmer trust.
  /// 
  /// FCR = Feed used / Weight gain (lower is better)
  static double correction(double? fcr) {
    if (fcr == null) return 1.0;

    return getFcrFactor(fcr);
  }

  /// 📊 Get FCR adjustment factor with smooth scaling
  /// 
  /// Returns multiplier to apply to daily feed recommendation:
  /// - > 1.0: Increase feed (efficient fish)
  /// - = 1.0: No change (acceptable baseline)
  /// - < 1.0: Reduce feed (wasteful feeding)
  static double getFcrFactor(double fcr) {
    if (fcr <= 1.0) return 1.15;  // Exceptional efficiency: +15%
    if (fcr <= 1.2) return 1.10;  // Very good: +10%
    if (fcr <= 1.3) return 1.05;  // Good: +5%
    if (fcr <= 1.4) return 1.00;  // Acceptable: no change
    if (fcr <= 1.5) return 0.90;  // Poor: -10%
    return 0.85;                  // Very poor/wasteful: -15%
  }

  /// 📋 Reference: FCR Interpretation
  /// 
  /// FCR ≤ 1.0   = Exceptional conversion (rarely seen)
  /// FCR ≤ 1.2   = Highly efficient (target for good farms)
  /// FCR ≤ 1.3   = Good performance
  /// FCR ≤ 1.4   = Acceptable baseline
  /// FCR ≤ 1.5   = Inefficient (needs attention)
  /// FCR > 1.5   = Wasteful feeding or poor fish health
}