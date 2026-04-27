// Confidence Service - Data quality assessment
//
// This service evaluates the confidence level of feed calculations
// based on data availability, quality, and recency.
// Returns confidence levels: high, medium, low

import '../../core/utils/logger.dart';
import '../../features/tray/enums/tray_status.dart';

/// Confidence Service
/// 
/// Evaluates data quality and availability for feed calculations
/// Returns confidence levels based on input data completeness
class ConfidenceService {
  static const String version = '1.0.0';

  /// Get confidence level based on data availability
  /// 
  /// [hasTrayData] Whether tray observation data is available
  /// [hasSampling] Whether ABW sampling data is available
  /// [hasWaterQuality] Whether water quality data is available
  /// [dataRecencyHours] How recent the data is (in hours)
  /// [trayConsistency] How consistent tray observations are (0.0-1.0)
  /// 
  /// Returns confidence level: 'high', 'medium', or 'low'
  static String getConfidence({
    required bool hasTrayData,
    required bool hasSampling,
    bool hasWaterQuality = false,
    int dataRecencyHours = 0,
    double trayConsistency = 1.0,
  }) {
    AppLogger.info(
      'ConfidenceService: evaluating confidence level',
      {
        'hasTrayData': hasTrayData,
        'hasSampling': hasSampling,
        'hasWaterQuality': hasWaterQuality,
        'dataRecencyHours': dataRecencyHours,
        'trayConsistency': trayConsistency,
      },
    );

    int confidenceScore = 0;

    // Primary data sources (highest weight)
    if (hasTrayData) confidenceScore += 30;
    if (hasSampling) confidenceScore += 30;

    // Secondary data sources (medium weight)
    if (hasWaterQuality) confidenceScore += 15;

    // Data recency (important for confidence)
    if (dataRecencyHours <= 2) {
      confidenceScore += 15; // Very recent data
    } else if (dataRecencyHours <= 6) {
      confidenceScore += 10; // Recent data
    } else if (dataRecencyHours <= 24) {
      confidenceScore += 5; // Same day data
    }

    // Tray consistency (bonus points)
    if (trayConsistency >= 0.8) {
      confidenceScore += 10; // Highly consistent
    } else if (trayConsistency >= 0.6) {
      confidenceScore += 5; // Moderately consistent
    }

    // Determine confidence level
    String confidenceLevel;
    if (confidenceScore >= 80) {
      confidenceLevel = 'high';
    } else if (confidenceScore >= 50) {
      confidenceLevel = 'medium';
    } else {
      confidenceLevel = 'low';
    }

    AppLogger.info(
      'ConfidenceService: confidence level determined',
      {
        'confidenceScore': confidenceScore,
        'confidenceLevel': confidenceLevel,
      },
    );

    return confidenceLevel;
  }

  /// Calculate tray consistency score
  /// 
  /// [trayStatuses] List of tray observations
  /// 
  /// Returns consistency score (0.0-1.0)
  static double calculateTrayConsistency(List<TrayStatus>? trayStatuses) {
    if (trayStatuses == null || trayStatuses.length < 3) {
      return 0.0; // Not enough data for consistency check
    }

    // Count occurrences of each status
    int full = 0;
    int empty = 0;
    int partial = 0;

    for (final status in trayStatuses) {
      switch (status) {
        case TrayStatus.full:
          full++;
          break;
        case TrayStatus.empty:
          empty++;
          break;
        case TrayStatus.partial:
          partial++;
          break;
      }
    }

    final int total = full + empty + partial;
    if (total == 0) return 0.0;

    // Calculate consistency based on dominance of one status
    final double maxRatio = [full, empty, partial]
        .reduce((a, b) => a > b ? a : b) / total;

    return maxRatio;
  }

  /// Evaluate data recency
  /// 
  /// [lastUpdate] When the data was last updated
  /// 
  /// Returns recency score (0.0-1.0)
  static double evaluateDataRecency(DateTime lastUpdate) {
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(lastUpdate);
    final int hoursAgo = difference.inHours;

    if (hoursAgo <= 2) return 1.0; // Excellent recency
    if (hoursAgo <= 6) return 0.8; // Good recency
    if (hoursAgo <= 12) return 0.6; // Fair recency
    if (hoursAgo <= 24) return 0.4; // Poor recency
    if (hoursAgo <= 48) return 0.2; // Very poor recency
    return 0.0; // Stale data
  }

  /// Get detailed confidence breakdown
  /// 
  /// Returns detailed confidence analysis
  static ConfidenceBreakdown getConfidenceBreakdown({
    required bool hasTrayData,
    required bool hasSampling,
    bool hasWaterQuality = false,
    DateTime? lastTrayUpdate,
    DateTime? lastSamplingUpdate,
    DateTime? lastWaterQualityUpdate,
    List<TrayStatus>? trayStatuses,
  }) {
    // Calculate individual scores
    final int trayScore = hasTrayData ? 30 : 0;
    final int samplingScore = hasSampling ? 30 : 0;
    final int waterQualityScore = hasWaterQuality ? 15 : 0;

    // Calculate recency scores
    final DateTime now = DateTime.now();
    int recencyScore = 0;
    
    if (lastTrayUpdate != null) {
      final int hoursAgo = now.difference(lastTrayUpdate).inHours;
      if (hoursAgo <= 2) {
        recencyScore += 5;
      } else if (hoursAgo <= 6) recencyScore += 3;
      else if (hoursAgo <= 24) recencyScore += 1;
    }

    if (lastSamplingUpdate != null) {
      final int hoursAgo = now.difference(lastSamplingUpdate).inHours;
      if (hoursAgo <= 2) {
        recencyScore += 5;
      } else if (hoursAgo <= 6) recencyScore += 3;
      else if (hoursAgo <= 24) recencyScore += 1;
    }

    // Calculate consistency score
    double consistencyScore = 0.0;
    if (trayStatuses != null) {
      consistencyScore = calculateTrayConsistency(trayStatuses);
    }

    final int consistencyBonus = (consistencyScore * 10).round();

    // Total score
    final int totalScore = trayScore + samplingScore + waterQualityScore + recencyScore + consistencyBonus;

    // Determine confidence level
    String confidenceLevel;
    if (totalScore >= 80) {
      confidenceLevel = 'high';
    } else if (totalScore >= 50) {
      confidenceLevel = 'medium';
    } else {
      confidenceLevel = 'low';
    }

    return ConfidenceBreakdown(
      confidenceLevel: confidenceLevel,
      totalScore: totalScore,
      trayScore: trayScore,
      samplingScore: samplingScore,
      waterQualityScore: waterQualityScore,
      recencyScore: recencyScore,
      consistencyScore: consistencyScore,
      consistencyBonus: consistencyBonus,
      hasTrayData: hasTrayData,
      hasSampling: hasSampling,
      hasWaterQuality: hasWaterQuality,
    );
  }

  /// Get confidence explanation
  /// 
  /// Returns human-readable explanation of confidence level
  static String getConfidenceExplanation(String confidenceLevel, {
    bool hasTrayData = false,
    bool hasSampling = false,
    bool hasWaterQuality = false,
  }) {
    switch (confidenceLevel) {
      case 'high':
        final List<String> reasons = ['Comprehensive data available'];
        if (hasTrayData) reasons.add('Tray observations');
        if (hasSampling) reasons.add('ABW sampling');
        if (hasWaterQuality) reasons.add('Water quality monitoring');
        return 'High confidence: ${reasons.join(', ')}';
      
      case 'medium':
        final List<String> availableData = [];
        if (hasTrayData) availableData.add('tray data');
        if (hasSampling) availableData.add('sampling data');
        if (hasWaterQuality) availableData.add('water quality');
        
        if (availableData.isEmpty) {
          return 'Medium confidence: Limited data sources';
        }
        return 'Medium confidence: ${availableData.join(', ')} available';
      
      case 'low':
        final List<String> missingData = [];
        if (!hasTrayData) missingData.add('tray observations');
        if (!hasSampling) missingData.add('ABW sampling');
        if (!hasWaterQuality) missingData.add('water quality');
        
        return 'Low confidence: Missing ${missingData.join(', ')}';
      
      default:
        return 'Unknown confidence level';
    }
  }

  /// Validate confidence inputs
  /// 
  /// Returns validation result
  static ConfidenceValidation validateInputs({
    required bool hasTrayData,
    required bool hasSampling,
    int dataRecencyHours = 0,
    double trayConsistency = 1.0,
  }) {
    final List<String> errors = [];

    if (dataRecencyHours < 0) {
      errors.add('Data recency hours cannot be negative');
    }

    if (trayConsistency < 0.0 || trayConsistency > 1.0) {
      errors.add('Tray consistency must be between 0.0 and 1.0');
    }

    return ConfidenceValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Confidence breakdown data model
class ConfidenceBreakdown {
  final String confidenceLevel;
  final int totalScore;
  final int trayScore;
  final int samplingScore;
  final int waterQualityScore;
  final int recencyScore;
  final double consistencyScore;
  final int consistencyBonus;
  final bool hasTrayData;
  final bool hasSampling;
  final bool hasWaterQuality;

  const ConfidenceBreakdown({
    required this.confidenceLevel,
    required this.totalScore,
    required this.trayScore,
    required this.samplingScore,
    required this.waterQualityScore,
    required this.recencyScore,
    required this.consistencyScore,
    required this.consistencyBonus,
    required this.hasTrayData,
    required this.hasSampling,
    required this.hasWaterQuality,
  });

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() {
    return {
      'confidenceLevel': confidenceLevel,
      'totalScore': totalScore,
      'trayScore': trayScore,
      'samplingScore': samplingScore,
      'waterQualityScore': waterQualityScore,
      'recencyScore': recencyScore,
      'consistencyScore': consistencyScore,
      'consistencyBonus': consistencyBonus,
      'hasTrayData': hasTrayData,
      'hasSampling': hasSampling,
      'hasWaterQuality': hasWaterQuality,
    };
  }

  /// Get detailed breakdown string
  String getBreakdownString() {
    return '''
Confidence Breakdown (${confidenceLevel.toUpperCase()}):
- Total Score: $totalScore/100
- Tray Data: ${hasTrayData ? '✓' : '✗'} ($trayScore/30)
- Sampling Data: ${hasSampling ? '✓' : '✗'} ($samplingScore/30)
- Water Quality: ${hasWaterQuality ? '✓' : '✗'} ($waterQualityScore/15)
- Data Recency: $recencyScore/15
- Tray Consistency: ${(consistencyScore * 100).toStringAsFixed(0)}% ($consistencyBonus/10)
''';
  }
}

/// Confidence validation result
class ConfidenceValidation {
  final bool isValid;
  final List<String> errors;

  const ConfidenceValidation({
    required this.isValid,
    required this.errors,
  });
}
