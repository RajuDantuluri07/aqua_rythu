class EnforcementEngine {
  /// ✅ IMPROVED: Proportional enforcement instead of hardcoded 0.90
  /// 
  /// Logic:
  /// - If yesterday overfeeding (actual > recommended):
  ///   Proportionally reduce today (more overage = more reduction)
  /// - If yesterday underfeeding (actual < recommended):
  ///   Proportionally increase today (more underage = more bonus)
  /// - Clamp to reasonable bounds [0.70, 1.25]
  static double apply({
    required double recommendedFeed,
    required double? actualFeedYesterday,
  }) {
    if (actualFeedYesterday == null) return recommendedFeed;

    final deviation = actualFeedYesterday - recommendedFeed;
    
    // No change if deviation is negligible
    if (deviation.abs() < recommendedFeed * 0.05) {
      return recommendedFeed;  // Within ±5% tolerance
    }

    // Case 1: OVERFEEDING yesterday (actual > recommended)
    // Proportionally reduce today based on overage magnitude
    if (deviation > recommendedFeed * 0.05) {
      // Map overage percentage to reduction factor
      // 10% overage → -5% reduction
      // 50% overage → -15% reduction
      // 100% overage → -25% reduction (clamped to min)
      final overagePercent = deviation / recommendedFeed;
      final reductionFactor = 1.0 - (overagePercent * 0.25);  // 25% of overage
      final factor = reductionFactor.clamp(0.70, 1.0);  // Min 30% reduction
      
      return recommendedFeed * factor;
    }

    // Case 2: UNDERFEEDING yesterday (actual < recommended)
    // Proportionally increase today to catch up
    if (deviation < -recommendedFeed * 0.05) {
      // Map underage percentage to bonus factor
      // -10% underage → +3% bonus
      // -50% underage → +8% bonus
      // -100% underage → +15% bonus (clamped to max)
      final underfeedingPercent = (deviation.abs() / recommendedFeed);
      final bonusFactor = 1.0 + (underfeedingPercent * 0.15);  // 15% of shortfall
      final factor = bonusFactor.clamp(1.0, 1.25);  // Max 25% bonus
      
      return recommendedFeed * factor;
    }

    return recommendedFeed;
  }

  /// Get descriptive reason for enforcement adjustment
  static String getEnforcementReason(double? actualFeedYesterday, double recommendedToday) {
    if (actualFeedYesterday == null) return "";
    
    final deviation = actualFeedYesterday - recommendedToday;
    final percentDev = (deviation / recommendedToday * 100).toStringAsFixed(1);
    
    if (deviation > recommendedToday * 0.05) {
      return "Yesterday overfeeding (+$percentDev%) → Reducing today";
    }
    if (deviation < -recommendedToday * 0.05) {
      return "Yesterday underfeeding ($percentDev%) → Increasing today";
    }
    return "";
  }
}