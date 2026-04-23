// ROI Calculator - Daily savings and cumulative tracking
//
// This service calculates return on investment from smart feed adjustments
// by comparing baseline feed amounts with actual feed amounts.
// Tracks both daily and cumulative savings in currency.

import 'dart:math';
import '../../core/utils/logger.dart';

/// ROI Calculator
///
/// Calculates return on investment from smart feed adjustments
/// by comparing baseline vs actual feed amounts and costs.
class RoiCalculator {
  static const String version = '1.0.0';

  /// Calculate daily savings from feed optimization
  ///
  /// [baselineFeed] The theoretical optimal feed amount in kg
  /// [actualFeed] The actual feed amount provided in kg
  /// [feedCost] Cost per kg of feed in currency units
  ///
  /// Returns daily savings amount (never negative)
  static double calculateDailySavings({
    required double baselineFeed,
    required double actualFeed,
    required double feedCost,
  }) {
    AppLogger.info(
      'RoiCalculator: calculating daily savings',
      {
        'baselineFeed': baselineFeed,
        'actualFeed': actualFeed,
        'feedCost': feedCost,
      },
    );

    // Validate inputs
    if (baselineFeed <= 0 || actualFeed <= 0 || feedCost <= 0) {
      AppLogger.warn('Invalid inputs for daily savings calculation');
      return 0.0;
    }

    // Calculate feed difference
    final double feedDifference = baselineFeed - actualFeed;

    // Only calculate savings if actual feed is less than baseline
    if (feedDifference <= 0) {
      AppLogger.info('No savings - actual feed >= baseline feed');
      return 0.0; // No negative savings displayed
    }

    // Calculate monetary savings
    final double dailySavings = feedDifference * feedCost;

    AppLogger.info(
      'RoiCalculator: daily savings calculated',
      {
        'feedDifference': feedDifference,
        'dailySavings': dailySavings,
      },
    );

    return dailySavings;
  }

  /// Update cumulative savings with today's savings
  ///
  /// [previousTotal] Previous cumulative savings amount
  /// [todaySavings] Today's savings amount
  ///
  /// Returns new cumulative savings total
  static double updateCumulativeSavings({
    required double previousTotal,
    required double todaySavings,
  }) {
    AppLogger.info(
      'RoiCalculator: updating cumulative savings',
      {
        'previousTotal': previousTotal,
        'todaySavings': todaySavings,
      },
    );

    // Validate inputs
    if (previousTotal < 0 || todaySavings < 0) {
      AppLogger.warn('Invalid inputs for cumulative savings update');
      return max(0.0, previousTotal); // Return previous total if invalid
    }

    final double newTotal = previousTotal + todaySavings;

    AppLogger.info(
      'RoiCalculator: cumulative savings updated',
      {
        'newTotal': newTotal,
      },
    );

    return newTotal;
  }

  /// Calculate feed cost efficiency percentage
  ///
  /// [baselineFeed] Baseline feed amount in kg
  /// [actualFeed] Actual feed amount in kg
  ///
  /// Returns efficiency percentage (0-100%)
  static double calculateFeedEfficiency({
    required double baselineFeed,
    required double actualFeed,
  }) {
    if (baselineFeed <= 0 || actualFeed <= 0) {
      return 0.0;
    }

    // Efficiency is how much of baseline feed was actually used
    final double efficiency = (actualFeed / baselineFeed) * 100;

    return efficiency.clamp(0.0, 100.0);
  }

  /// Calculate ROI percentage
  ///
  /// [totalSavings] Total savings amount
  /// [totalFeedCost] Total feed cost without optimization
  ///
  /// Returns ROI percentage
  static double calculateRoiPercentage({
    required double totalSavings,
    required double totalFeedCost,
  }) {
    if (totalFeedCost <= 0) {
      return 0.0;
    }

    final double roiPercentage = (totalSavings / totalFeedCost) * 100;

    return roiPercentage;
  }

  /// Calculate projected savings for remaining culture period
  ///
  /// [dailySavings] Current daily savings amount
  /// [remainingDays] Number of days remaining in culture
  ///
  /// Returns projected total savings
  static double calculateProjectedSavings({
    required double dailySavings,
    required int remainingDays,
  }) {
    if (dailySavings <= 0 || remainingDays <= 0) {
      return 0.0;
    }

    return dailySavings * remainingDays;
  }

  /// Calculate feed cost savings percentage
  ///
  /// [baselineCost] Cost of baseline feed
  /// [actualCost] Cost of actual feed
  ///
  /// Returns cost savings percentage (0-100%)
  static double calculateCostSavingsPercentage({
    required double baselineCost,
    required double actualCost,
  }) {
    if (baselineCost <= 0 || actualCost <= 0) {
      return 0.0;
    }

    final double costDifference = baselineCost - actualCost;

    if (costDifference <= 0) {
      return 0.0; // No cost savings
    }

    final double savingsPercentage = (costDifference / baselineCost) * 100;

    return savingsPercentage.clamp(0.0, 100.0);
  }

  /// Generate ROI summary for reporting
  ///
  /// [dailySavings] Today's savings
  /// [cumulativeSavings] Total savings to date
  /// [baselineFeed] Baseline feed amount
  /// [actualFeed] Actual feed amount
  /// [feedCost] Cost per kg
  /// [cultureDays] Days in culture so far
  ///
  /// Returns formatted ROI summary
  static RoiSummary generateRoiSummary({
    required double dailySavings,
    required double cumulativeSavings,
    required double baselineFeed,
    required double actualFeed,
    required double feedCost,
    required int cultureDays,
  }) {
    // Calculate derived metrics
    final double feedEfficiency = calculateFeedEfficiency(
      baselineFeed: baselineFeed,
      actualFeed: actualFeed,
    );

    final double baselineCost = baselineFeed * feedCost;
    final double actualCost = actualFeed * feedCost;

    final double costSavingsPercentage = calculateCostSavingsPercentage(
      baselineCost: baselineCost,
      actualCost: actualCost,
    );

    final double averageDailySavings =
        cultureDays > 0 ? cumulativeSavings / cultureDays : 0.0;

    // Calculate ROI percentage
    final double roiPercentage = calculateRoiPercentage(
      totalSavings: cumulativeSavings,
      totalFeedCost: baselineCost * cultureDays,
    );

    return RoiSummary(
      dailySavings: dailySavings,
      cumulativeSavings: cumulativeSavings,
      feedEfficiency: feedEfficiency,
      costSavingsPercentage: costSavingsPercentage,
      averageDailySavings: averageDailySavings,
      roiPercentage: roiPercentage,
      baselineCost: baselineCost,
      actualCost: actualCost,
    );
  }

  /// Validate ROI calculation inputs
  ///
  /// Returns validation result
  static RoiValidation validateInputs({
    required double baselineFeed,
    required double actualFeed,
    required double feedCost,
  }) {
    final List<String> errors = [];

    if (baselineFeed <= 0) {
      errors.add('Baseline feed must be positive');
    }

    if (actualFeed <= 0) {
      errors.add('Actual feed must be positive');
    }

    if (feedCost <= 0) {
      errors.add('Feed cost must be positive');
    }

    if (baselineFeed > 1000) {
      errors.add('Baseline feed exceeds reasonable limit (1000 kg)');
    }

    if (actualFeed > 1000) {
      errors.add('Actual feed exceeds reasonable limit (1000 kg)');
    }

    if (feedCost > 1000) {
      errors.add('Feed cost exceeds reasonable limit (1000 per kg)');
    }

    return RoiValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// ROI summary data model
class RoiSummary {
  final double dailySavings;
  final double cumulativeSavings;
  final double feedEfficiency;
  final double costSavingsPercentage;
  final double averageDailySavings;
  final double roiPercentage;
  final double baselineCost;
  final double actualCost;

  const RoiSummary({
    required this.dailySavings,
    required this.cumulativeSavings,
    required this.feedEfficiency,
    required this.costSavingsPercentage,
    required this.averageDailySavings,
    required this.roiPercentage,
    required this.baselineCost,
    required this.actualCost,
  });

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() {
    return {
      'dailySavings': dailySavings,
      'cumulativeSavings': cumulativeSavings,
      'feedEfficiency': feedEfficiency,
      'costSavingsPercentage': costSavingsPercentage,
      'averageDailySavings': averageDailySavings,
      'roiPercentage': roiPercentage,
      'baselineCost': baselineCost,
      'actualCost': actualCost,
    };
  }

  /// Get formatted summary string
  String getSummaryString() {
    return '''
ROI Summary:
- Daily Savings: ₹${dailySavings.toStringAsFixed(2)}
- Cumulative Savings: ₹${cumulativeSavings.toStringAsFixed(2)}
- Feed Efficiency: ${feedEfficiency.toStringAsFixed(1)}%
- Cost Savings: ${costSavingsPercentage.toStringAsFixed(1)}%
- Average Daily Savings: ₹${averageDailySavings.toStringAsFixed(2)}
- ROI: ${roiPercentage.toStringAsFixed(1)}%
''';
  }
}

/// ROI validation result
class RoiValidation {
  final bool isValid;
  final List<String> errors;

  const RoiValidation({
    required this.isValid,
    required this.errors,
  });
}
