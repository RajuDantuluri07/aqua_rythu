// Baseline Feed Calculator - System-generated feed calculations
//
// This service calculates the baseline feed amount based on:
// - Day of Culture (DOC)
// - Shrimp count and survival rate
// - Average Body Weight (ABW) - either sampled or estimated
// - Industry-standard feed rates
//
// The baseline represents the theoretical optimal feed amount
// without any smart adjustments or real-time corrections.

import 'dart:math';
import '../../core/utils/logger.dart';

/// Baseline Feed Calculator
///
/// Calculates the baseline feed amount for a pond based on biological
/// parameters and industry-standard feed rates.
class BaselineCalculator {
  static const String version = '1.0.0';

  /// Calculate baseline feed amount in kilograms
  ///
  /// [doc] Day of Culture (1-based)
  /// [shrimpCount] Initial shrimp count at stocking
  /// [sampledAbw] Optional actual ABW from sampling (grams)
  /// [survivalRate] Expected survival rate (0.0-1.0)
  ///
  /// Returns baseline feed amount in kg
  static double calculateBaselineFeed({
    required int doc,
    required int shrimpCount,
    required double? sampledAbw,
    required double survivalRate,
  }) {
    AppLogger.info(
      'BaselineCalculator: calculating baseline feed',
      {
        'doc': doc,
        'shrimpCount': shrimpCount,
        'sampledAbw': sampledAbw,
        'survivalRate': survivalRate,
      },
    );

    // Validate inputs
    if (doc <= 0) {
      AppLogger.warn('Invalid DOC: $doc, using 1');
      doc = 1;
    }

    if (shrimpCount <= 0) {
      AppLogger.error('Zero or negative shrimp count: $shrimpCount');
      return 0.0;
    }

    if (survivalRate <= 0 || survivalRate > 1.0) {
      AppLogger.warn('Invalid survival rate: $survivalRate, using 0.85');
      survivalRate = 0.85;
    }

    // Step 1: Determine ABW (use sampled if available, otherwise estimate)
    final double abw = sampledAbw ?? estimateAbwFromDoc(doc);

    // Step 2: Calculate effective shrimp count (accounting for mortality)
    final double effectiveCount = shrimpCount * survivalRate;

    // Step 3: Calculate biomass in kg (convert grams to kg)
    final double biomass = (effectiveCount * abw) / 1000.0;

    // Step 4: Get feed rate based on DOC and ABW
    final double feedRate = getFeedRate(doc, abw);

    // Step 5: Calculate baseline feed (biomass × feed rate)
    final double baselineFeed = biomass * feedRate;

    AppLogger.info(
      'BaselineCalculator: calculation complete',
      {
        'abw': abw,
        'effectiveCount': effectiveCount,
        'biomass': biomass,
        'feedRate': feedRate,
        'baselineFeed': baselineFeed,
      },
    );

    // Ensure non-negative result
    return max(0.0, baselineFeed);
  }

  /// Estimate Average Body Weight (ABW) from Day of Culture
  ///
  /// Uses smooth industry-standard growth curves for Pacific white shrimp
  /// Eliminates sudden jumps and provides more realistic growth patterns
  /// Returns ABW in grams
  static double estimateAbwFromDoc(int doc) {
    if (doc <= 0) return 0.0;
    if (doc <= 30) return 0.06 * doc; // Smooth growth: ~2g at day 30
    if (doc <= 60)
      return 2.0 + ((doc - 30) * 0.27); // Smooth growth: ~10g at day 60
    if (doc <= 90)
      return 10.0 + ((doc - 60) * 0.33); // Smooth growth: ~20g at day 90
    if (doc <= 120)
      return 20.0 + ((doc - 90) * 0.27); // Smooth growth: ~28g at day 120
    return 28.0 + min((doc - 120) * 0.05, 2.0); // Smooth growth: Max 30g
  }

  /// Get feed rate based on DOC and ABW
  ///
  /// Feed rate represents the percentage of body weight fed per day
  /// Returns feed rate as decimal (e.g., 0.05 = 5% of body weight)
  static double getFeedRate(int doc, double abw) {
    // ABW-based feed rate (more precise than DOC-only)
    if (abw <= 2) return 0.05; // Very small shrimp: higher rate
    if (abw <= 5) return 0.045; // Small shrimp: slightly reduced
    if (abw <= 10) return 0.035; // Medium shrimp: standard rate
    if (abw <= 20) return 0.025; // Large shrimp: reduced rate
    if (abw <= 30) return 0.02; // Very large shrimp: lowest rate

    // Fallback to DOC-based calculation for edge cases
    return getFeedRateFromDoc(doc);
  }

  /// Legacy DOC-based feed rate (fallback method)
  ///
  /// Used when ABW data is unreliable or unavailable
  static double getFeedRateFromDoc(int doc) {
    // Early stage: higher feed rate for rapid growth
    if (doc <= 30) return 0.06; // 6% of body weight
    if (doc <= 45) return 0.05; // 5% of body weight
    if (doc <= 60) return 0.035; // 3.5% of body weight
    if (doc <= 90) return 0.025; // 2.5% of body weight
    // Finishing phase: lowest feed rate
    return 0.02; // 2% of body weight
  }

  /// Calculate biomass from shrimp count and ABW
  ///
  /// [shrimpCount] Number of shrimp
  /// [abw] Average Body Weight in grams
  /// [survivalRate] Survival rate (0.0-1.0)
  ///
  /// Returns biomass in kg
  static double calculateBiomass({
    required int shrimpCount,
    required double abw,
    required double survivalRate,
  }) {
    final effectiveCount = shrimpCount * survivalRate;
    return (effectiveCount * abw) / 1000.0;
  }

  /// Get growth stage classification
  ///
  /// Returns human-readable growth stage based on DOC
  static String getGrowthStage(int doc) {
    if (doc <= 30) return 'Nursery';
    if (doc <= 60) return 'Early Grow-out';
    if (doc <= 90) return 'Mid Grow-out';
    if (doc <= 120) return 'Late Grow-out';
    return 'Finishing';
  }

  /// Calculate expected feed conversion ratio (FCR)
  ///
  /// Returns expected FCR based on growth stage
  static double getExpectedFCR(int doc) {
    if (doc <= 30) return 1.2; // Best FCR in nursery
    if (doc <= 60) return 1.3; // Good FCR in early grow-out
    if (doc <= 90) return 1.4; // Moderate FCR in mid grow-out
    if (doc <= 120) return 1.5; // Higher FCR in late grow-out
    return 1.6; // Highest FCR in finishing
  }

  /// Validate calculation parameters
  ///
  /// Returns validation result with error message if invalid
  static BaselineCalculationResult validateParameters({
    required int doc,
    required int shrimpCount,
    required double? sampledAbw,
    required double survivalRate,
  }) {
    // Check DOC
    if (doc <= 0) {
      return BaselineCalculationResult.invalid('DOC must be positive');
    }
    if (doc > 200) {
      return BaselineCalculationResult.invalid(
          'DOC exceeds reasonable limit (200 days)');
    }

    // Check shrimp count
    if (shrimpCount <= 0) {
      return BaselineCalculationResult.invalid('Shrimp count must be positive');
    }
    if (shrimpCount > 10000000) {
      return BaselineCalculationResult.invalid(
          'Shrimp count exceeds reasonable limit');
    }

    // Check sampled ABW if provided
    if (sampledAbw != null) {
      if (sampledAbw <= 0) {
        return BaselineCalculationResult.invalid(
            'Sampled ABW must be positive');
      }
      if (sampledAbw > 50) {
        return BaselineCalculationResult.invalid(
            'Sampled ABW exceeds reasonable limit (50g)');
      }
    }

    // Check survival rate
    if (survivalRate <= 0 || survivalRate > 1.0) {
      return BaselineCalculationResult.invalid(
          'Survival rate must be between 0 and 1');
    }

    return BaselineCalculationResult.valid();
  }
}

/// Result of baseline feed calculation
class BaselineCalculationResult {
  final bool isValid;
  final String? errorMessage;
  final double? baselineFeed;
  final double? abw;
  final double? biomass;
  final double? feedRate;

  const BaselineCalculationResult({
    required this.isValid,
    this.errorMessage,
    this.baselineFeed,
    this.abw,
    this.biomass,
    this.feedRate,
  });

  factory BaselineCalculationResult.valid({
    double? baselineFeed,
    double? abw,
    double? biomass,
    double? feedRate,
  }) {
    return BaselineCalculationResult(
      isValid: true,
      baselineFeed: baselineFeed,
      abw: abw,
      biomass: biomass,
      feedRate: feedRate,
    );
  }

  factory BaselineCalculationResult.invalid(String errorMessage) {
    return BaselineCalculationResult(
      isValid: false,
      errorMessage: errorMessage,
    );
  }
}
