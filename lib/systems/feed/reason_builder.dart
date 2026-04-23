// Reason Builder - Explainable feed decisions
//
// This service generates human-readable explanations for feed decisions
// based on tray observations, growth patterns, and other factors.
// Makes the feed engine transparent and explainable.

import '../../core/utils/logger.dart';
import '../../features/tray/enums/tray_status.dart';

/// Reason Builder
///
/// Generates human-readable explanations for feed decisions
/// based on various factors and data sources
class ReasonBuilder {
  static const String version = '1.0.0';

  /// Build reason for feed decision (supports BOTH increase & decrease)
  ///
  /// [baseline] Baseline feed amount
  /// [actual] Actual feed amount after adjustments
  /// [trayLeftover] Whether trays show leftover feed
  /// [growthSlow] Whether growth is below expected
  /// [confidenceLevel] Current confidence level
  ///
  /// Returns clear reason string for both directions
  static String buildReason({
    required double baseline,
    required double actual,
    required bool trayLeftover,
    required bool growthSlow,
    required String confidenceLevel,
  }) {
    if (actual < baseline) {
      // Feed reduction case
      if (trayLeftover) {
        return 'Tray leftover detected → reduced feed to prevent waste';
      }
      return 'Optimization applied → reducing excess feeding';
      reasons.add('Growth below expected → adjusted feed');
    } else if (fcrHigh) {
      reasons.add('High FCR detected → optimized feed');
    } else if (waterQualityPoor) {
      reasons.add('Water quality concerns → conservative feeding');
    }

    // If no primary factors, use standard optimization
    if (reasons.isEmpty) {
      reasons.add('Standard optimization applied');
    }

    // Add confidence context if low
    if (confidenceLevel == 'low') {
      reasons.add('(Limited data - conservative approach)');
    }

    final String finalReason = reasons.join('; ');

    AppLogger.info('ReasonBuilder: reason built', {'reason': finalReason});

    return finalReason;
  }

  /// Build detailed reason with specific factors
  ///
  /// Returns comprehensive explanation
  static String buildDetailedReason({
    List<TrayStatus>? trayStatuses,
    double? currentAbw,
    double? expectedAbw,
    double? currentFcr,
    double? targetFcr,
    double? dissolvedOxygen,
    double? temperature,
    double? ammonia,
    String confidenceLevel = 'medium',
  }) {
    final List<String> factors = [];

    // Tray analysis
    if (trayStatuses != null && trayStatuses.isNotEmpty) {}

    // Growth analysis
    final String growthPattern = analyzeGrowthPattern(currentAbw, expectedAbw);
    if (growthPattern.isNotEmpty) {
      reasons.add(growthPattern);
    }

    // FCR analysis
    final String fcrPattern = analyzeFcrPattern(currentFcr, targetFcr, trend);
    if (fcrPattern.isNotEmpty) {
      reasons.add(fcrPattern);
    }

    // Water quality analysis
    final String waterPattern = analyzeWaterQualityPattern(confidenceLevel);
    if (waterPattern.isNotEmpty) {
      reasons.add(waterPattern);
    }

    // Build final reason
    if (reasons.isEmpty) {
      return 'Standard optimization applied';
    }

    return reasons.join('; ');
  }

  /// Analyze tray pattern for reasoning
  ///
  /// [trayStatuses] List of current tray statuses
  ///
  /// Returns analysis string
  static String analyzeTrayPattern(List<TrayStatus> trayStatuses) {
    if (trayStatuses.isEmpty) {
      return '';
    }

    final fullCount = trayStatuses.where((s) => s == TrayStatus.full).length;
    final emptyCount = trayStatuses.where((s) => s == TrayStatus.empty).length;
    final totalCount = trayStatuses.length;

    if (fullCount > totalCount * 0.6) {
      return 'Poor appetite observed - most trays full';
    } else if (emptyCount > totalCount * 0.6) {
      return 'Good appetite observed - most trays empty';
    } else if (fullCount > emptyCount) {
      return 'Mixed appetite observed - some trays full';
    } else {
      return 'Balanced appetite observed - equal full/empty';
    }
  }

  /// Analyze growth pattern for reasoning
  ///
  /// [currentAbw] Current average body weight
  /// [expectedAbw] Expected ABW for current DOC
  ///
  /// Returns analysis string
  static String analyzeGrowthPattern(double currentAbw, double expectedAbw) {
    if (currentAbw <= 0 || expectedAbw <= 0) {
      return 'Growth data unavailable';
    }

    final double growthRatio = currentAbw / expectedAbw;

    if (growthRatio < 0.8) {
      return 'Growth significantly behind target';
    } else if (growthRatio < 0.9) {
      return 'Growth slightly behind target';
    } else if (growthRatio > 1.2) {
      return 'Growth significantly ahead of target';
    } else if (growthRatio > 1.1) {
      return 'Growth slightly ahead of target';
    } else {
      return 'Growth on target';
    }
  }

  /// Analyze FCR pattern for reasoning
  ///
  /// [currentFcr] Current Feed Conversion Ratio
  /// [targetFcr] Target FCR for current DOC
  /// [trend] FCR trend ('improving', 'stable', 'worsening')
  ///
  /// Returns analysis string
  static String analyzeFcrPattern(
      double currentFcr, double targetFcr, String trend) {
    if (currentFcr <= 0 || targetFcr <= 0) {
      return 'FCR data unavailable';
    }

    final double fcrRatio = currentFcr / targetFcr;

    if (fcrRatio > 1.3) {
      return 'FCR significantly above target';
    } else if (fcrRatio > 1.1) {
      return 'FCR slightly above target';
    } else if (fcrRatio < 0.9) {
      return 'FCR below target';
    } else {
      return 'FCR on target';
    }
  }

  /// Analyze water quality pattern for reasoning
  ///
  /// [confidenceLevel] Current confidence level
  ///
  /// Returns analysis string
  static String analyzeWaterQualityPattern(String confidenceLevel) {
    switch (confidenceLevel.toLowerCase()) {
      case 'high':
        return 'Good water quality indicators';
      case 'medium':
        return 'Some water quality concerns';
      case 'low':
        return 'Poor water quality data';
      default:
        return 'Water quality data unavailable';
    }
  }

  /// Analyze FCR pattern and return explanation
  static String analyzeFcrPattern(double currentFcr, double targetFcr) {
    if (currentFcr <= 0 || targetFcr <= 0) {
      return 'FCR data unavailable';
    }

    final double fcrEfficiency = targetFcr / currentFcr;

    if (fcrEfficiency < 0.8) {
      return 'Poor FCR efficiency (${currentFcr.toStringAsFixed(2)} vs ${targetFcr.toStringAsFixed(2)}) → reduced feeding';
    } else if (fcrEfficiency < 0.9) {
      return 'Suboptimal FCR (${currentFcr.toStringAsFixed(2)} vs ${targetFcr.toStringAsFixed(2)}) → moderate reduction';
    } else if (fcrEfficiency > 1.2) {
      return 'Excellent FCR (${currentFcr.toStringAsFixed(2)} vs ${targetFcr.toStringAsFixed(2)}) → increased feeding';
    } else if (fcrEfficiency > 1.1) {
      return 'Good FCR (${currentFcr.toStringAsFixed(2)} vs ${targetFcr.toStringAsFixed(2)}) → slight increase';
    } else {
      return 'Normal FCR (${currentFcr.toStringAsFixed(2)}) → standard feeding';
    }
  }

  /// Analyze water quality and return explanation
  static String analyzeWaterQuality({
    double? dissolvedOxygen,
    double? temperature,
    double? ammonia,
  }) {
    final List<String> issues = [];

    // Check dissolved oxygen
    if (dissolvedOxygen != null) {
      if (dissolvedOxygen < 3.0) {
        issues.add('Critical DO (${dissolvedOxygen.toStringAsFixed(1)} mg/L)');
      } else if (dissolvedOxygen < 4.0) {
        issues.add('Low DO (${dissolvedOxygen.toStringAsFixed(1)} mg/L)');
      } else if (dissolvedOxygen < 5.0) {
        issues
            .add('Suboptimal DO (${dissolvedOxygen.toStringAsFixed(1)} mg/L)');
      }
    }

    // Check temperature
    if (temperature != null) {
      if (temperature < 25.0 || temperature > 32.0) {
        issues.add(
            'Temperature outside optimal range (${temperature.toStringAsFixed(1)}°C)');
      } else if (temperature < 26.0 || temperature > 31.0) {
        issues.add(
            'Temperature near optimal edge (${temperature.toStringAsFixed(1)}°C)');
      }
    }

    // Check ammonia
    if (ammonia != null) {
      if (ammonia > 1.0) {
        issues.add('High ammonia (${ammonia.toStringAsFixed(2)} ppm)');
      } else if (ammonia > 0.5) {
        issues.add('Moderate ammonia (${ammonia.toStringAsFixed(2)} ppm)');
      }
    }

    if (issues.isEmpty) {
      return '';
    }

    return 'Water quality concerns: ${issues.join(', ')} → conservative feeding';
  }

  /// Get adjustment summary
  ///
  /// Returns summary of all adjustments applied
  static String getAdjustmentSummary({
    double trayFactor = 1.0,
    double growthFactor = 1.0,
    double fcrFactor = 1.0,
    double waterQualityFactor = 1.0,
  }) {
    final List<String> adjustments = [];

    if (trayFactor != 1.0) {
      final String direction = trayFactor < 1.0 ? 'reduced' : 'increased';
      final String percentage =
          ((trayFactor - 1.0) * 100).abs().toStringAsFixed(0);
      adjustments.add('Tray: $direction by $percentage%');
    }

    if (growthFactor != 1.0) {
      final String direction = growthFactor < 1.0 ? 'reduced' : 'increased';
      final String percentage =
          ((growthFactor - 1.0) * 100).abs().toStringAsFixed(0);
      adjustments.add('Growth: $direction by $percentage%');
    }

    if (fcrFactor != 1.0) {
      final String direction = fcrFactor < 1.0 ? 'reduced' : 'increased';
      final String percentage =
          ((fcrFactor - 1.0) * 100).abs().toStringAsFixed(0);
      adjustments.add('FCR: $direction by $percentage%');
    }

    if (waterQualityFactor != 1.0) {
      final String direction =
          waterQualityFactor < 1.0 ? 'reduced' : 'increased';
      final String percentage =
          ((waterQualityFactor - 1.0) * 100).abs().toStringAsFixed(0);
      adjustments.add('Water quality: $direction by $percentage%');
    }

    if (adjustments.isEmpty) {
      return 'No adjustments applied';
    }

    return 'Adjustments: ${adjustments.join(', ')}';
  }

  /// Get confidence explanation
  ///
  /// Returns explanation of confidence level
  static String getConfidenceExplanation(String confidenceLevel) {
    switch (confidenceLevel) {
      case 'high':
        return 'High confidence: Comprehensive data with recent tray observations and sampling';
      case 'medium':
        return 'Medium confidence: Partial data available - using conservative estimates';
      case 'low':
        return 'Low confidence: Limited data - using baseline calculations with minimal adjustments';
      default:
        return 'Unknown confidence level';
    }
  }

  /// Validate reason inputs
  ///
  /// Returns validation result
  static ReasonValidation validateInputs({
    required bool trayLeftover,
    required bool growthSlow,
    String confidenceLevel = 'medium',
  }) {
    final List<String> errors = [];

    if (!['high', 'medium', 'low'].contains(confidenceLevel)) {
      errors.add('Confidence level must be high, medium, or low');
    }

    return ReasonValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Reason validation result
class ReasonValidation {
  final bool isValid;
  final List<String> errors;

  const ReasonValidation({
    required this.isValid,
    required this.errors,
  });
}
