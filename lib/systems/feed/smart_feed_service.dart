// Smart Feed Service - Apply intelligent adjustments to baseline feed
//
// This service applies real-time corrections to the baseline feed amount
// based on tray observations, growth patterns, and FCR data.
// All adjustments are safety-capped to prevent extreme recommendations.

import '../../core/utils/logger.dart';
import '../../features/tray/enums/tray_status.dart';

/// Smart Feed Service
///
/// Applies intelligent adjustments to baseline feed calculations
/// with safety caps to prevent extreme recommendations.
class SmartFeedService {
  static const String version = '1.0.0';

  /// Apply smart adjustments to baseline feed
  ///
  /// [baselineFeed] The calculated baseline feed amount in kg
  /// [trayFactor] Adjustment factor based on tray observations (0.7-1.3)
  /// [growthFactor] Adjustment factor based on growth patterns (0.8-1.2)
  /// [fcrFactor] Adjustment factor based on FCR trends (0.8-1.2)
  ///
  /// Returns adjusted feed amount with safety caps applied
  static double applySmartAdjustments({
    required double baselineFeed,
    required double trayFactor,
    required double growthFactor,
    required double fcrFactor,
  }) {
    AppLogger.info(
      'SmartFeedService: applying adjustments',
      {
        'baselineFeed': baselineFeed,
        'trayFactor': trayFactor,
        'growthFactor': growthFactor,
        'fcrFactor': fcrFactor,
      },
    );

    // Validate baseline feed
    if (baselineFeed <= 0) {
      AppLogger.warn('Invalid baseline feed: $baselineFeed, returning 0');
      return 0.0;
    }

    // Clamp individual factors to reasonable ranges
    final double safeTrayFactor = trayFactor.clamp(0.7, 1.3);
    final double safeGrowthFactor = growthFactor.clamp(0.8, 1.2);
    final double safeFcrFactor = fcrFactor.clamp(0.8, 1.2);

    // Apply adjustments sequentially
    double adjusted = baselineFeed;
    adjusted *= safeTrayFactor;
    adjusted *= safeGrowthFactor;
    adjusted *= safeFcrFactor;

    // Apply safety caps (±10-12% from baseline)
    final double minFeed = baselineFeed * 0.88; // -12%
    final double maxFeed = baselineFeed * 1.12; // +12%

    final double finalFeed = adjusted.clamp(minFeed, maxFeed);

    AppLogger.info(
      'SmartFeedService: adjustments applied',
      {
        'safeTrayFactor': safeTrayFactor,
        'safeGrowthFactor': safeGrowthFactor,
        'safeFcrFactor': safeFcrFactor,
        'rawAdjusted': adjusted,
        'minFeed': minFeed,
        'maxFeed': maxFeed,
        'finalFeed': finalFeed,
        'wasClamped': finalFeed != adjusted,
      },
    );

    return finalFeed;
  }

  /// Calculate tray adjustment factor from tray statuses
  ///
  /// [trayStatuses] List of tray observations
  ///
  /// Returns adjustment factor (0.7-1.3)
  static double calculateTrayFactor(List<TrayStatus>? trayStatuses) {
    if (trayStatuses == null || trayStatuses.isEmpty) {
      return 1.0; // No tray data, no adjustment
    }

    int full = 0;
    int empty = 0;
    int partial = 0;

    // Count tray statuses
    for (final status in trayStatuses) {
      switch (status) {
        case TrayStatus.heavy:
          full++;
          break;
        case TrayStatus.empty:
          empty++;
          break;
        case TrayStatus.light:
        case TrayStatus.medium:
          partial++;
          break;
      }
    }

    final int totalTrays = full + empty + partial;
    if (totalTrays == 0) return 1.0;

    // Calculate adjustment based on tray patterns
    final double fullRatio = full / totalTrays;
    final double emptyRatio = empty / totalTrays;

    if (fullRatio > 0.6) {
      // Most trays full - reduce feeding (poor appetite)
      return 0.85;
    } else if (fullRatio > 0.4) {
      // Many trays full - slight reduction
      return 0.92;
    } else if (emptyRatio > 0.6) {
      // Most trays empty - increase feeding (good appetite)
      return 1.08;
    } else if (emptyRatio > 0.4) {
      // Many trays empty - slight increase
      return 1.04;
    } else {
      // Balanced - no adjustment
      return 1.0;
    }
  }

  /// Calculate growth adjustment factor
  ///
  /// [currentAbw] Current average body weight
  /// [expectedAbw] Expected ABW for current DOC
  /// [previousGrowthRate] Previous growth rate (g/day)
  ///
  /// Returns adjustment factor (0.8-1.2)
  static double calculateGrowthFactor({
    required double currentAbw,
    required double expectedAbw,
    required double previousGrowthRate,
  }) {
    if (currentAbw <= 0 || expectedAbw <= 0) {
      return 1.0; // Invalid data, no adjustment
    }

    // Calculate growth deviation
    final double growthRatio = currentAbw / expectedAbw;

    if (growthRatio < 0.8) {
      // Growth significantly behind target
      return 1.15; // Increase feeding to catch up
    } else if (growthRatio < 0.9) {
      // Growth slightly behind target
      return 1.08; // Slight increase
    } else if (growthRatio > 1.2) {
      // Growth significantly ahead of target
      return 0.85; // Reduce feeding to optimize
    } else if (growthRatio > 1.1) {
      // Growth slightly ahead of target
      return 0.92; // Slight reduction
    } else {
      // Growth on target
      return 1.0; // No adjustment
    }
  }

  /// Calculate ABW-based feed rate (more precise than DOC-only)
  ///
  /// [abw] Average Body Weight in grams
  /// Returns feed rate based on shrimp size
  static double calculateFeedRateFromAbw(double abw) {
    if (abw <= 2) return 0.05; // Very small shrimp: higher rate
    if (abw <= 5) return 0.045; // Small shrimp: slightly reduced
    if (abw <= 10) return 0.035; // Medium shrimp: standard rate
    if (abw <= 20) return 0.025; // Large shrimp: reduced rate
    if (abw <= 30) return 0.02; // Very large shrimp: lowest rate
    return 0.025; // Default for very large shrimp
  }

  /// Calculate FCR adjustment factor
  ///
  /// [currentFcr] Current Feed Conversion Ratio
  /// [targetFcr] Target FCR for current DOC
  /// [trend] FCR trend ('improving', 'stable', 'worsening')
  ///
  /// Returns adjustment factor (0.8-1.2)
  static double calculateFcrFactor({
    required double currentFcr,
    required double targetFcr,
    required String trend,
  }) {
    if (currentFcr <= 0 || targetFcr <= 0) {
      return 1.0; // Invalid data, no adjustment
    }

    // Calculate FCR efficiency
    final double fcrEfficiency = targetFcr / currentFcr;

    if (fcrEfficiency < 0.8) {
      // Poor FCR efficiency - reduce feeding
      return 0.85;
    } else if (fcrEfficiency < 0.9) {
      // Slightly poor efficiency
      return 0.92;
    } else if (fcrEfficiency > 1.2) {
      // Excellent FCR efficiency - can increase slightly
      return 1.08;
    } else if (fcrEfficiency > 1.1) {
      // Good efficiency
      return 1.04;
    } else {
      // Normal efficiency
      return 1.0;
    }
  }

  /// Apply water quality adjustments
  ///
  /// [dissolvedOxygen] DO level in mg/L
  /// [temperature] Water temperature in °C
  /// [ammonia] Ammonia level in ppm
  ///
  /// Returns adjustment factor (0.5-1.0)
  static double applyWaterQualityAdjustment({
    required double dissolvedOxygen,
    required double temperature,
    required double ammonia,
  }) {
    double adjustment = 1.0;

    // Dissolved oxygen adjustment
    if (dissolvedOxygen < 3.0) {
      adjustment *= 0.5; // Critical - reduce by 50%
    } else if (dissolvedOxygen < 4.0) {
      adjustment *= 0.7; // Low - reduce by 30%
    } else if (dissolvedOxygen < 5.0) {
      adjustment *= 0.85; // Suboptimal - reduce by 15%
    }

    // Temperature adjustment
    if (temperature < 25.0 || temperature > 32.0) {
      adjustment *= 0.8; // Outside optimal range
    } else if (temperature < 26.0 || temperature > 31.0) {
      adjustment *= 0.9; // Near edge of optimal range
    }

    // Ammonia adjustment
    if (ammonia > 1.0) {
      adjustment *= 0.7; // High ammonia - reduce feeding
    } else if (ammonia > 0.5) {
      adjustment *= 0.85; // Moderate ammonia
    }

    return adjustment.clamp(0.5, 1.0);
  }

  /// Get adjustment explanation
  ///
  /// Returns human-readable explanation of applied adjustments
  static String getAdjustmentExplanation({
    required double trayFactor,
    required double growthFactor,
    required double fcrFactor,
    double? waterQualityFactor,
  }) {
    final List<String> explanations = [];

    if (trayFactor != 1.0) {
      if (trayFactor < 1.0) {
        explanations.add('Tray observation: reduced feeding due to leftovers');
      } else {
        explanations
            .add('Tray observation: increased feeding due to clean trays');
      }
    }

    if (growthFactor != 1.0) {
      if (growthFactor < 1.0) {
        explanations.add(
            'Growth optimization: reduced feeding (growth ahead of target)');
      } else {
        explanations.add(
            'Growth optimization: increased feeding (growth behind target)');
      }
    }

    if (fcrFactor != 1.0) {
      if (fcrFactor < 1.0) {
        explanations.add('FCR optimization: reduced feeding (poor efficiency)');
      } else {
        explanations
            .add('FCR optimization: increased feeding (good efficiency)');
      }
    }

    if (waterQualityFactor != null && waterQualityFactor != 1.0) {
      explanations.add('Water quality: adjusted for environmental conditions');
    }

    if (explanations.isEmpty) {
      return 'Standard optimization applied';
    }

    return explanations.join('; ');
  }

  /// Validate adjustment factors
  ///
  /// Returns validation result
  static SmartAdjustmentValidation validateAdjustmentFactors({
    required double trayFactor,
    required double growthFactor,
    required double fcrFactor,
  }) {
    final List<String> errors = [];

    if (trayFactor < 0.5 || trayFactor > 1.5) {
      errors.add('Tray factor out of range: $trayFactor (expected 0.5-1.5)');
    }

    if (growthFactor < 0.5 || growthFactor > 1.5) {
      errors
          .add('Growth factor out of range: $growthFactor (expected 0.5-1.5)');
    }

    if (fcrFactor < 0.5 || fcrFactor > 1.5) {
      errors.add('FCR factor out of range: $fcrFactor (expected 0.5-1.5)');
    }

    return SmartAdjustmentValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Validation result for smart adjustment factors
class SmartAdjustmentValidation {
  final bool isValid;
  final List<String> errors;

  const SmartAdjustmentValidation({
    required this.isValid,
    required this.errors,
  });
}
