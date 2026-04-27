/// Real-World Anchors System - grounds decisions in actual farm reality
/// Ensures decisions are safe, practical, and based on real farm data
library;


class RealWorldAnchors {
  static const double MAX_FEED_CHANGE_PERCENTAGE = 0.15; // 15% max change per decision
  static const double MIN_SAMPLE_SIZE = 30; // Minimum shrimp for reliable sampling
  static const int MAX_DAYS_WITHOUT_SAMPLE = 21; // Maximum age for sampling data
  static const double MIN_CONFIDENCE_FOR_ACTION = 0.6; // Minimum confidence for strong actions
  static const double TRAY_RESPONSE_THRESHOLD = 0.8; // Minimum tray response for feed decisions

  /// Validate decision against real-world constraints
  static DecisionValidation validateDecision({
    required DecisionType type,
    required Map<String, dynamic> decisionData,
    required FarmAnchors anchors,
  }) {
    switch (type) {
      case DecisionType.feedAdjustment:
        return _validateFeedDecision(decisionData, anchors);
      case DecisionType.harvestTiming:
        return _validateHarvestDecision(decisionData, anchors);
      case DecisionType.sampling:
        return _validateSamplingDecision(decisionData, anchors);
      case DecisionType.waterQuality:
        return _validateWaterQualityDecision(decisionData, anchors);
      default:
        return DecisionValidation.valid();
    }
  }

  /// Validate feed adjustment decisions
  static DecisionValidation _validateFeedDecision(Map<String, dynamic> data, FarmAnchors anchors) {
    final issues = <String>[];
    final warnings = <String>[];
    double safetyScore = 1.0;

    // Check 1: Recent sampling data available
    if (anchors.daysSinceLastSample > MAX_DAYS_WITHOUT_SAMPLE) {
      issues.add('Sampling data too old (${anchors.daysSinceLastSample} days)');
      safetyScore *= 0.3;
    }

    // Check 2: Minimum sample size
    if (anchors.lastSampleSize < MIN_SAMPLE_SIZE) {
      warnings.add('Sample size small (${anchors.lastSampleSize} shrimp)');
      safetyScore *= 0.8;
    }

    // Check 3: Tray response consistency
    if (anchors.trayResponseScore < TRAY_RESPONSE_THRESHOLD) {
      warnings.add('Low tray response score (${(anchors.trayResponseScore * 100).toStringAsFixed(0)}%)');
      safetyScore *= 0.7;
    }

    // Check 4: Feed change magnitude
    final feedChangePercentage = data['feedChangePercentage'] as double? ?? 0.0;
    if (feedChangePercentage.abs() > MAX_FEED_CHANGE_PERCENTAGE) {
      issues.add('Feed change too large (${(feedChangePercentage * 100).toStringAsFixed(1)}%)');
      safetyScore *= 0.2;
    }

    // Check 5: Recent mortality events
    if (anchors.hasRecentMortality) {
      warnings.add('Recent mortality detected - conservative approach');
      safetyScore *= 0.6;
    }

    // Check 6: Environmental stress indicators
    if (anchors.environmentalStressScore > 0.7) {
      warnings.add('Environmental stress detected');
      safetyScore *= 0.5;
    }

    // Check 7: Farmer confirmation for major changes
    if (feedChangePercentage.abs() > 0.1 && !anchors.farmerConfirmed) {
      issues.add('Farmer confirmation required for >10% feed changes');
      safetyScore *= 0.4;
    }

    final isValid = issues.isEmpty;
    final needsConfirmation = warnings.isNotEmpty || !isValid;

    return DecisionValidation(
      isValid: isValid,
      needsConfirmation: needsConfirmation,
      safetyScore: safetyScore,
      issues: issues,
      warnings: warnings,
      recommendedAction: _getRecommendedFeedAction(safetyScore, feedChangePercentage),
    );
  }

  /// Validate harvest timing decisions
  static DecisionValidation _validateHarvestDecision(Map<String, dynamic> data, FarmAnchors anchors) {
    final issues = <String>[];
    final warnings = <String>[];
    double safetyScore = 1.0;

    final currentAbw = data['currentAbw'] as double? ?? 0.0;
    final biomass = data['biomass'] as double? ?? 0.0;
    final marketPrice = data['marketPrice'] as double? ?? 0.0;

    // Check 1: Minimum size for harvest
    if (currentAbw < 15.0) {
      issues.add('Shrimp too small for harvest (${currentAbw.toStringAsFixed(1)}g)');
      safetyScore *= 0.1;
    } else if (currentAbw < 18.0) {
      warnings.add('Shrimp below optimal size (${currentAbw.toStringAsFixed(1)}g)');
      safetyScore *= 0.7;
    }

    // Check 2: Biomass reliability
    if (anchors.daysSinceLastSample > 14) {
      warnings.add('Biomass estimate based on old sampling data');
      safetyScore *= 0.8;
    }

    // Check 3: Market conditions
    if (marketPrice < 250) { // Below market rate
      warnings.add('Market price below optimal (₹${marketPrice.toStringAsFixed(0)}/kg)');
      safetyScore *= 0.6;
    }

    // Check 4: Farm capacity for harvest
    if (biomass > anchors.harvestCapacity && anchors.harvestCapacity > 0) {
      warnings.add('Biomass exceeds farm harvest capacity');
      safetyScore *= 0.5;
    }

    // Check 5: Labor availability
    if (!anchors.laborAvailable) {
      issues.add('Labor not available for harvest');
      safetyScore *= 0.2;
    }

    // Check 6: Market access
    if (!anchors.marketAccess) {
      warnings.add('Limited market access - confirm buyer availability');
      safetyScore *= 0.7;
    }

    final isValid = issues.isEmpty;
    final needsConfirmation = warnings.isNotEmpty || !isValid;

    return DecisionValidation(
      isValid: isValid,
      needsConfirmation: needsConfirmation,
      safetyScore: safetyScore,
      issues: issues,
      warnings: warnings,
      recommendedAction: _getRecommendedHarvestAction(safetyScore, currentAbw, biomass),
    );
  }

  /// Validate sampling decisions
  static DecisionValidation _validateSamplingDecision(Map<String, dynamic> data, FarmAnchors anchors) {
    final issues = <String>[];
    final warnings = <String>[];
    double safetyScore = 1.0;

    final samplingMethod = data['samplingMethod'] as String? ?? 'cast_net';
    final targetSampleSize = data['targetSampleSize'] as int? ?? 50;

    // Check 1: Weather conditions
    if (anchors.weatherConditions == 'storm' || anchors.weatherConditions == 'heavy_rain') {
      issues.add('Unsafe weather conditions for sampling');
      safetyScore *= 0.1;
    } else if (anchors.weatherConditions == 'rain') {
      warnings.add('Rainy weather - sampling may be difficult');
      safetyScore *= 0.7;
    }

    // Check 2: Time of day
    final currentHour = DateTime.now().hour;
    if (currentHour < 6 || currentHour > 18) {
      warnings.add('Sampling outside optimal hours (6AM-6PM)');
      safetyScore *= 0.8;
    }

    // Check 3: Equipment availability
    if (!anchors.samplingEquipmentReady) {
      issues.add('Sampling equipment not ready');
      safetyScore *= 0.3;
    }

    // Check 4: Sample size reasonableness
    if (targetSampleSize > 200) {
      warnings.add('Large sample size may stress shrimp');
      safetyScore *= 0.8;
    } else if (targetSampleSize < 20) {
      warnings.add('Small sample size may not be representative');
      safetyScore *= 0.7;
    }

    // Check 5: Recent feeding
    final minutesSinceLastFeed = anchors.minutesSinceLastFeeding;
    if (minutesSinceLastFeed < 30) {
      warnings.add('Recently fed - shrimp may not be active');
      safetyScore *= 0.6;
    }

    final isValid = issues.isEmpty;
    final needsConfirmation = warnings.isNotEmpty || !isValid;

    return DecisionValidation(
      isValid: isValid,
      needsConfirmation: needsConfirmation,
      safetyScore: safetyScore,
      issues: issues,
      warnings: warnings,
      recommendedAction: _getRecommendedSamplingAction(safetyScore, samplingMethod),
    );
  }

  /// Validate water quality decisions
  static DecisionValidation _validateWaterQualityDecision(Map<String, dynamic> data, FarmAnchors anchors) {
    final issues = <String>[];
    final warnings = <String>[];
    double safetyScore = 1.0;

    final parameter = data['parameter'] as String? ?? '';
    final currentValue = data['currentValue'] as double? ?? 0.0;
    final targetValue = data['targetValue'] as double? ?? 0.0;

    // Check 1: Critical parameter ranges
    switch (parameter.toLowerCase()) {
      case 'do':
        if (currentValue < 3.0) {
          issues.add('Dissolved oxygen critically low (${currentValue.toStringAsFixed(1)} ppm)');
          safetyScore *= 0.1;
        } else if (currentValue < 4.0) {
          warnings.add('Dissolved oxygen low (${currentValue.toStringAsFixed(1)} ppm)');
          safetyScore *= 0.6;
        }
        break;
      case 'ph':
        if (currentValue < 6.5 || currentValue > 9.0) {
          issues.add('pH outside safe range (${currentValue.toStringAsFixed(1)})');
          safetyScore *= 0.2;
        } else if (currentValue < 7.0 || currentValue > 8.5) {
          warnings.add('pH approaching limits (${currentValue.toStringAsFixed(1)})');
          safetyScore *= 0.7;
        }
        break;
      case 'ammonia':
        if (currentValue > 1.0) {
          issues.add('Ammonia critically high (${currentValue.toStringAsFixed(2)} ppm)');
          safetyScore *= 0.1;
        } else if (currentValue > 0.5) {
          warnings.add('Ammonia elevated (${currentValue.toStringAsFixed(2)} ppm)');
          safetyScore *= 0.6;
        }
        break;
    }

    // Check 2: Treatment availability
    if (!anchors.treatmentChemicalsAvailable) {
      warnings.add('Treatment chemicals not readily available');
      safetyScore *= 0.5;
    }

    // Check 3: Recent treatment
    if (anchors.hoursSinceLastTreatment < 24) {
      warnings.add('Recent treatment - wait for full effect');
      safetyScore *= 0.7;
    }

    final isValid = issues.isEmpty;
    final needsConfirmation = warnings.isNotEmpty || !isValid;

    return DecisionValidation(
      isValid: isValid,
      needsConfirmation: needsConfirmation,
      safetyScore: safetyScore,
      issues: issues,
      warnings: warnings,
      recommendedAction: _getRecommendedWaterQualityAction(safetyScore, parameter, currentValue, targetValue),
    );
  }

  /// Get recommended action based on safety score
  static String _getRecommendedFeedAction(double safetyScore, double feedChangePercentage) {
    if (safetyScore < 0.3) {
      return 'POSTPONE: Insufficient data for safe feed adjustment';
    } else if (safetyScore < 0.6) {
      return 'CONSERVATIVE: Reduce feed change to ${MAX_FEED_CHANGE_PERCENTAGE * 50}% and monitor closely';
    } else if (feedChangePercentage.abs() > 0.1) {
      return 'CONFIRM: Get farmer confirmation before implementing ${(feedChangePercentage * 100).toStringAsFixed(1)}% change';
    } else {
      return 'PROCEED: Safe to implement ${(feedChangePercentage * 100).toStringAsFixed(1)}% feed adjustment';
    }
  }

  static String _getRecommendedHarvestAction(double safetyScore, double currentAbw, double biomass) {
    if (safetyScore < 0.3) {
      return 'POSTPONE: Address critical issues before harvest';
    } else if (safetyScore < 0.6) {
      return 'CONDITIONAL: Harvest possible but address warnings first';
    } else if (currentAbw < 18.0) {
      return 'WAIT: Consider waiting for optimal size (18-20g)';
    } else {
      return 'PROCEED: Harvest conditions favorable';
    }
  }

  static String _getRecommendedSamplingAction(double safetyScore, String samplingMethod) {
    if (safetyScore < 0.3) {
      return 'POSTPONE: Unsafe conditions for sampling';
    } else if (safetyScore < 0.6) {
      return 'CAUTION: Proceed with care and additional safety measures';
    } else {
      return 'PROCEED: Safe to conduct $samplingMethod sampling';
    }
  }

  static String _getRecommendedWaterQualityAction(double safetyScore, String parameter, double current, double target) {
    if (safetyScore < 0.3) {
      return 'URGENT: Critical parameter - immediate action required';
    } else if (safetyScore < 0.6) {
      return 'MONITOR: Parameter needs attention - gradual adjustment recommended';
    } else {
      return 'MAINTAIN: Parameter within acceptable range';
    }
  }
}

class FarmAnchors {
  final int daysSinceLastSample;
  final int lastSampleSize;
  final double trayResponseScore;
  final bool hasRecentMortality;
  final double environmentalStressScore;
  final bool farmerConfirmed;
  final double harvestCapacity;
  final bool laborAvailable;
  final bool marketAccess;
  final String weatherConditions;
  final bool samplingEquipmentReady;
  final int minutesSinceLastFeeding;
  final bool treatmentChemicalsAvailable;
  final int hoursSinceLastTreatment;

  const FarmAnchors({
    required this.daysSinceLastSample,
    required this.lastSampleSize,
    required this.trayResponseScore,
    required this.hasRecentMortality,
    required this.environmentalStressScore,
    required this.farmerConfirmed,
    required this.harvestCapacity,
    required this.laborAvailable,
    required this.marketAccess,
    required this.weatherConditions,
    required this.samplingEquipmentReady,
    required this.minutesSinceLastFeeding,
    required this.treatmentChemicalsAvailable,
    required this.hoursSinceLastTreatment,
  });

  factory FarmAnchors.current() {
    return const FarmAnchors(
      daysSinceLastSample: 7,
      lastSampleSize: 50,
      trayResponseScore: 0.85,
      hasRecentMortality: false,
      environmentalStressScore: 0.2,
      farmerConfirmed: false,
      harvestCapacity: 5000, // kg
      laborAvailable: true,
      marketAccess: true,
      weatherConditions: 'clear',
      samplingEquipmentReady: true,
      minutesSinceLastFeeding: 120,
      treatmentChemicalsAvailable: true,
      hoursSinceLastTreatment: 72,
    );
  }

  /// Get overall farm stability score
  double get overallStability {
    double score = 1.0;

    // Data freshness
    if (daysSinceLastSample > 14) score *= 0.7;
    if (daysSinceLastSample > 21) score *= 0.4;

    // Biological stability
    if (hasRecentMortality) score *= 0.5;
    if (environmentalStressScore > 0.7) score *= 0.6;

    // Operational readiness
    if (!laborAvailable) score *= 0.3;
    if (!marketAccess) score *= 0.7;
    if (!samplingEquipmentReady) score *= 0.5;

    return score.clamp(0.0, 1.0);
  }

  /// Check if farm is in stable condition for decisions
  bool get isStable => overallStability >= 0.7;

  /// Get confidence level for decisions
  ConfidenceLevel get confidenceLevel {
    if (overallStability >= 0.9) return ConfidenceLevel.high;
    if (overallStability >= 0.7) return ConfidenceLevel.medium;
    if (overallStability >= 0.5) return ConfidenceLevel.low;
    return ConfidenceLevel.very_low;
  }
}

class DecisionValidation {
  final bool isValid;
  final bool needsConfirmation;
  final double safetyScore;
  final List<String> issues;
  final List<String> warnings;
  final String recommendedAction;

  const DecisionValidation({
    required this.isValid,
    required this.needsConfirmation,
    required this.safetyScore,
    required this.issues,
    required this.warnings,
    required this.recommendedAction,
  });

  factory DecisionValidation.valid() {
    return const DecisionValidation(
      isValid: true,
      needsConfirmation: false,
      safetyScore: 1.0,
      issues: [],
      warnings: [],
      recommendedAction: 'PROCEED',
    );
  }

  /// Get validation status
  ValidationStatus get status {
    if (!isValid) return ValidationStatus.invalid;
    if (needsConfirmation) return ValidationStatus.needs_confirmation;
    if (warnings.isNotEmpty) return ValidationStatus.caution;
    return ValidationStatus.valid;
  }

  /// Get status text
  String get statusText {
    switch (status) {
      case ValidationStatus.valid: return 'Valid';
      case ValidationStatus.needs_confirmation: return 'Needs Confirmation';
      case ValidationStatus.caution: return 'Caution';
      case ValidationStatus.invalid: return 'Invalid';
    }
  }

  /// Get status color
  String get statusColor {
    switch (status) {
      case ValidationStatus.valid: return '#006A3A';
      case ValidationStatus.needs_confirmation: return '#FFC107';
      case ValidationStatus.caution: return '#FF8F00';
      case ValidationStatus.invalid: return '#E53935';
    }
  }
}

enum DecisionType {
  feedAdjustment,
  harvestTiming,
  sampling,
  waterQuality,
}

enum ValidationStatus {
  valid,
  needs_confirmation,
  caution,
  invalid,
}

enum ConfidenceLevel {
  very_low,
  low,
  medium,
  high,
}
