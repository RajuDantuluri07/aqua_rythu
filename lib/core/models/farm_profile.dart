/// Farm-specific profile system for personalized growth modeling
/// Each farm has unique characteristics that affect growth patterns
library;

import 'dart:math';
import 'growth_curve.dart';

class FarmProfile {
  final String farmId;
  final String farmName;
  final FarmCharacteristics characteristics;
  final GrowthAdjustmentFactors growthFactors;
  final HistoricalPerformance performance;
  final DateTime lastUpdated;

  const FarmProfile({
    required this.farmId,
    required this.farmName,
    required this.characteristics,
    required this.growthFactors,
    required this.performance,
    required this.lastUpdated,
  });

  factory FarmProfile.createDefault(String farmId, String farmName) {
    return FarmProfile(
      farmId: farmId,
      farmName: farmName,
      characteristics: FarmCharacteristics.defaultValues(),
      growthFactors: GrowthAdjustmentFactors.initial(),
      performance: HistoricalPerformance.empty(),
      lastUpdated: DateTime.now(),
    );
  }

  factory FarmProfile.fromJson(Map<String, dynamic> json) {
    return FarmProfile(
      farmId: json['farmId'] as String,
      farmName: json['farmName'] as String,
      characteristics: FarmCharacteristics.fromJson(json['characteristics']),
      growthFactors: GrowthAdjustmentFactors.fromJson(json['growthFactors']),
      performance: HistoricalPerformance.fromJson(json['performance']),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmId': farmId,
      'farmName': farmName,
      'characteristics': characteristics.toJson(),
      'growthFactors': growthFactors.toJson(),
      'performance': performance.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  FarmProfile copyWith({
    String? farmId,
    String? farmName,
    FarmCharacteristics? characteristics,
    GrowthAdjustmentFactors? growthFactors,
    HistoricalPerformance? performance,
    DateTime? lastUpdated,
  }) {
    return FarmProfile(
      farmId: farmId ?? this.farmId,
      farmName: farmName ?? this.farmName,
      characteristics: characteristics ?? this.characteristics,
      growthFactors: growthFactors ?? this.growthFactors,
      performance: performance ?? this.performance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Calculate farm-adjusted expected ABW for given DOC
  double getAdjustedExpectedAbw(int doc) {
    final baseAbw = GrowthCurve.getExpectedAbw(doc);
    final adjustment = growthFactors.getAdjustmentForDoc(doc);
    return baseAbw * adjustment;
  }

  /// Get confidence score based on data quality and farm-specific factors
  double getConfidenceScore({
    required int daysSinceLastSample,
    required int doc,
    int? sampleCount,
  }) {
    double confidence = 1.0;

    // Data freshness penalty
    if (daysSinceLastSample > 7) {
      confidence *= 0.8;
    }
    if (daysSinceLastSample > 14) {
      confidence *= 0.6;
    }
    if (daysSinceLastSample > 21) {
      confidence *= 0.4;
    }
    if (daysSinceLastSample > 30) {
      confidence *= 0.2;
    }

    // Sample count bonus
    if (sampleCount != null && sampleCount >= 5) {
      confidence *= 1.1;
    } else if (sampleCount != null && sampleCount < 3) {
      confidence *= 0.9;
    }

    // Farm-specific confidence based on historical performance
    final performanceConfidence = performance.getReliabilityScore();
    confidence *= performanceConfidence;

    // Growth phase confidence (higher confidence in established phases)
    final phaseConfidence = _getPhaseConfidence(doc);
    confidence *= phaseConfidence;

    return confidence.clamp(0.0, 1.0);
  }

  double _getPhaseConfidence(int doc) {
    if (doc <= 15) return 0.7; // Nursery - more variability
    if (doc <= 60) return 0.9; // Early grow-out - stable patterns
    if (doc <= 90) return 0.85; // Mid grow-out - some variability
    return 0.8; // Late grow-out - approaching harvest
  }

  /// Update farm profile with new performance data
  FarmProfile updateWithPerformanceData({
    required int doc,
    required double actualAbw,
    required double expectedAbw,
    required DateTime sampleDate,
    double? fcr,
    double? survivalRate,
  }) {
    final performanceRatio = actualAbw / expectedAbw;

    // Update growth factors based on actual performance
    final updatedFactors =
        growthFactors.updateWithPerformance(doc, performanceRatio);

    // Update historical performance
    final updatedPerformance = performance.addDataPoint(
      doc: doc,
      actualAbw: actualAbw,
      expectedAbw: expectedAbw,
      fcr: fcr,
      survivalRate: survivalRate,
      sampleDate: sampleDate,
    );

    return copyWith(
      growthFactors: updatedFactors,
      performance: updatedPerformance,
      lastUpdated: DateTime.now(),
    );
  }
}

class FarmCharacteristics {
  final double averageTemperature; // Celsius
  final double averageSalinity; // ppt
  final double stockingDensity; // PL/m²
  final String waterSource; // borewell, sea, mixed
  final String feedType; // commercial, custom, mixed
  final String managementStyle; // intensive, semi-intensive, extensive
  final double pondDepth; // meters
  final String aerationType; // paddlewheel, diffused, none

  const FarmCharacteristics({
    required this.averageTemperature,
    required this.averageSalinity,
    required this.stockingDensity,
    required this.waterSource,
    required this.feedType,
    required this.managementStyle,
    required this.pondDepth,
    required this.aerationType,
  });

  factory FarmCharacteristics.defaultValues() {
    return const FarmCharacteristics(
      averageTemperature: 29.0,
      averageSalinity: 20.0,
      stockingDensity: 75.0,
      waterSource: 'mixed',
      feedType: 'commercial',
      managementStyle: 'semi-intensive',
      pondDepth: 1.5,
      aerationType: 'paddlewheel',
    );
  }

  factory FarmCharacteristics.fromJson(Map<String, dynamic> json) {
    return FarmCharacteristics(
      averageTemperature: (json['averageTemperature'] as num).toDouble(),
      averageSalinity: (json['averageSalinity'] as num).toDouble(),
      stockingDensity: (json['stockingDensity'] as num).toDouble(),
      waterSource: json['waterSource'] as String,
      feedType: json['feedType'] as String,
      managementStyle: json['managementStyle'] as String,
      pondDepth: (json['pondDepth'] as num).toDouble(),
      aerationType: json['aerationType'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageTemperature': averageTemperature,
      'averageSalinity': averageSalinity,
      'stockingDensity': stockingDensity,
      'waterSource': waterSource,
      'feedType': feedType,
      'managementStyle': managementStyle,
      'pondDepth': pondDepth,
      'aerationType': aerationType,
    };
  }

  /// Calculate environmental adjustment factors
  Map<String, double> getEnvironmentalFactors() {
    final factors = <String, double>{};

    // Temperature adjustment (optimal 28-30°C)
    if (averageTemperature >= 28 && averageTemperature <= 30) {
      factors['temperature'] = 1.0;
    } else if (averageTemperature < 28) {
      factors['temperature'] = 0.85 + (averageTemperature - 25) * 0.05;
    } else {
      factors['temperature'] = 1.0 - (averageTemperature - 30) * 0.03;
    }

    // Salinity adjustment (optimal 15-25 ppt)
    if (averageSalinity >= 15 && averageSalinity <= 25) {
      factors['salinity'] = 1.0;
    } else if (averageSalinity < 15) {
      factors['salinity'] = 0.9 + (averageSalinity / 15) * 0.1;
    } else {
      factors['salinity'] = 1.0 - (averageSalinity - 25) * 0.02;
    }

    // Stocking density adjustment
    if (stockingDensity <= 50) {
      factors['stocking'] = 1.1; // Low density = better growth
    } else if (stockingDensity <= 100) {
      factors['stocking'] = 1.0; // Optimal range
    } else {
      factors['stocking'] = max(0.8, 1.0 - (stockingDensity - 100) * 0.002);
    }

    // Management style adjustment
    switch (managementStyle) {
      case 'intensive':
        factors['management'] = 1.05;
        break;
      case 'semi-intensive':
        factors['management'] = 1.0;
        break;
      case 'extensive':
        factors['management'] = 0.9;
        break;
      default:
        factors['management'] = 1.0;
    }

    return factors;
  }
}

class GrowthAdjustmentFactors {
  final Map<int, double> phaseAdjustments; // DOC-specific adjustments
  final double overallMultiplier; // Overall farm performance factor
  final double seasonalFactor; // Seasonal adjustment
  final double learningRate; // How quickly to adapt to new data

  const GrowthAdjustmentFactors({
    required this.phaseAdjustments,
    required this.overallMultiplier,
    required this.seasonalFactor,
    required this.learningRate,
  });

  factory GrowthAdjustmentFactors.initial() {
    return const GrowthAdjustmentFactors(
      phaseAdjustments: {
        30: 1.0, // Nursery end
        60: 1.0, // Early grow-out end
        90: 1.0, // Mid grow-out end
        120: 1.0, // Harvest size
      },
      overallMultiplier: 1.0,
      seasonalFactor: 1.0,
      learningRate: 0.1,
    );
  }

  factory GrowthAdjustmentFactors.fromJson(Map<String, dynamic> json) {
    final phaseAdjustments = <int, double>{};
    final phaseData = json['phaseAdjustments'] as Map<String, dynamic>;
    for (final entry in phaseData.entries) {
      phaseAdjustments[int.parse(entry.key)] = (entry.value as num).toDouble();
    }

    return GrowthAdjustmentFactors(
      phaseAdjustments: phaseAdjustments,
      overallMultiplier: (json['overallMultiplier'] as num).toDouble(),
      seasonalFactor: (json['seasonalFactor'] as num).toDouble(),
      learningRate: (json['learningRate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final phaseJson = <String, dynamic>{};
    for (final entry in phaseAdjustments.entries) {
      phaseJson[entry.key.toString()] = entry.value;
    }

    return {
      'phaseAdjustments': phaseJson,
      'overallMultiplier': overallMultiplier,
      'seasonalFactor': seasonalFactor,
      'learningRate': learningRate,
    };
  }

  /// Get adjustment factor for specific DOC
  double getAdjustmentForDoc(int doc) {
    // Find nearest phase adjustment
    final sortedPhases = phaseAdjustments.keys.toList()..sort();

    for (int i = 0; i < sortedPhases.length; i++) {
      final phaseDoc = sortedPhases[i];
      if (doc <= phaseDoc) {
        final phaseAdjustment = phaseAdjustments[phaseDoc]!;

        // Interpolate between phases if not at exact phase point
        if (i > 0) {
          final prevPhaseDoc = sortedPhases[i - 1];
          final prevPhaseAdjustment = phaseAdjustments[prevPhaseDoc]!;
          final progress = (doc - prevPhaseDoc) / (phaseDoc - prevPhaseDoc);
          return prevPhaseAdjustment +
              (phaseAdjustment - prevPhaseAdjustment) * progress;
        }

        return phaseAdjustment;
      }
    }

    // Beyond last phase
    return phaseAdjustments[sortedPhases.last]!;
  }

  /// Update adjustment factors based on performance data
  GrowthAdjustmentFactors updateWithPerformance(
      int doc, double performanceRatio) {
    final updatedPhaseAdjustments = Map<int, double>.from(phaseAdjustments);

    // Update the nearest phase adjustment
    final sortedPhases = phaseAdjustments.keys.toList()..sort();
    int? nearestPhase;
    double? nearestDistance;

    for (final phase in sortedPhases) {
      final distance = (phase - doc).abs();
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance.toDouble();
        nearestPhase = phase;
      }
    }

    if (nearestPhase != null) {
      final currentAdjustment = updatedPhaseAdjustments[nearestPhase]!;
      final targetAdjustment =
          currentAdjustment + (performanceRatio - 1.0) * learningRate;
      updatedPhaseAdjustments[nearestPhase] =
          targetAdjustment.clamp(0.7, 1.3); // Limit adjustments
    }

    // Update overall multiplier based on recent performance
    final updatedOverallMultiplier =
        overallMultiplier + (performanceRatio - 1.0) * learningRate * 0.5;

    return GrowthAdjustmentFactors(
      phaseAdjustments: updatedPhaseAdjustments,
      overallMultiplier: updatedOverallMultiplier.clamp(0.8, 1.2),
      seasonalFactor: seasonalFactor,
      learningRate: learningRate,
    );
  }
}

class HistoricalPerformance {
  final List<PerformanceDataPoint> dataPoints;
  final Map<int, double>
      averagePerformanceByDoc; // DOC -> average performance ratio
  final double overallReliability; // How reliable the farm's data is

  const HistoricalPerformance({
    required this.dataPoints,
    required this.averagePerformanceByDoc,
    required this.overallReliability,
  });

  factory HistoricalPerformance.empty() {
    return const HistoricalPerformance(
      dataPoints: [],
      averagePerformanceByDoc: {},
      overallReliability: 0.5,
    );
  }

  factory HistoricalPerformance.fromJson(Map<String, dynamic> json) {
    final dataPoints = (json['dataPoints'] as List)
        .map((e) => PerformanceDataPoint.fromJson(e))
        .toList();

    final averagePerformanceJson =
        json['averagePerformanceByDoc'] as Map<String, dynamic>;
    final averagePerformanceByDoc = <int, double>{};
    for (final entry in averagePerformanceJson.entries) {
      averagePerformanceByDoc[int.parse(entry.key)] =
          (entry.value as num).toDouble();
    }

    return HistoricalPerformance(
      dataPoints: dataPoints,
      averagePerformanceByDoc: averagePerformanceByDoc,
      overallReliability: (json['overallReliability'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final averagePerformanceJson = <String, dynamic>{};
    for (final entry in averagePerformanceByDoc.entries) {
      averagePerformanceJson[entry.key.toString()] = entry.value;
    }

    return {
      'dataPoints': dataPoints.map((dp) => dp.toJson()).toList(),
      'averagePerformanceByDoc': averagePerformanceJson,
      'overallReliability': overallReliability,
    };
  }

  /// Add new performance data point
  HistoricalPerformance addDataPoint({
    required int doc,
    required double actualAbw,
    required double expectedAbw,
    required DateTime sampleDate,
    double? fcr,
    double? survivalRate,
  }) {
    final performanceRatio = actualAbw / expectedAbw;
    final newDataPoint = PerformanceDataPoint(
      doc: doc,
      actualAbw: actualAbw,
      expectedAbw: expectedAbw,
      performanceRatio: performanceRatio,
      fcr: fcr,
      survivalRate: survivalRate,
      sampleDate: sampleDate,
    );

    final updatedDataPoints = [...dataPoints, newDataPoint];

    // Keep only last 100 data points
    if (updatedDataPoints.length > 100) {
      updatedDataPoints.removeRange(0, updatedDataPoints.length - 100);
    }

    // Update average performance by DOC
    final updatedAveragePerformance =
        Map<int, double>.from(averagePerformanceByDoc);
    updatedAveragePerformance[doc] =
        _calculateAverageForDoc(updatedDataPoints, doc);

    // Calculate overall reliability
    final updatedReliability = _calculateReliability(updatedDataPoints);

    return HistoricalPerformance(
      dataPoints: updatedDataPoints,
      averagePerformanceByDoc: updatedAveragePerformance,
      overallReliability: updatedReliability,
    );
  }

  double _calculateAverageForDoc(List<PerformanceDataPoint> points, int doc) {
    final docPoints = points.where((p) => p.doc == doc);
    if (docPoints.isEmpty) return 1.0;

    final total =
        docPoints.fold<double>(0.0, (sum, p) => sum + p.performanceRatio);
    return total / docPoints.length;
  }

  double _calculateReliability(List<PerformanceDataPoint> points) {
    if (points.length < 5) return 0.5; // Not enough data

    // Calculate consistency of performance
    final performances = points.map((p) => p.performanceRatio).toList();
    final mean = performances.reduce((a, b) => a + b) / performances.length;
    final variance = performances.fold<double>(
            0.0, (sum, p) => sum + (p - mean) * (p - mean)) /
        performances.length;
    final standardDeviation = variance > 0 ? sqrt(variance) : 0.0;

    // Lower variance = higher reliability
    final reliability = max(0.3, 1.0 - (standardDeviation / mean));
    return reliability.clamp(0.0, 1.0);
  }

  double getReliabilityScore() {
    return overallReliability;
  }

  /// Get expected performance ratio for given DOC based on history
  double getExpectedPerformanceRatio(int doc) {
    return averagePerformanceByDoc[doc] ?? 1.0;
  }
}

class PerformanceDataPoint {
  final int doc;
  final double actualAbw;
  final double expectedAbw;
  final double performanceRatio;
  final double? fcr;
  final double? survivalRate;
  final DateTime sampleDate;

  const PerformanceDataPoint({
    required this.doc,
    required this.actualAbw,
    required this.expectedAbw,
    required this.performanceRatio,
    this.fcr,
    this.survivalRate,
    required this.sampleDate,
  });

  factory PerformanceDataPoint.fromJson(Map<String, dynamic> json) {
    return PerformanceDataPoint(
      doc: json['doc'] as int,
      actualAbw: (json['actualAbw'] as num).toDouble(),
      expectedAbw: (json['expectedAbw'] as num).toDouble(),
      performanceRatio: (json['performanceRatio'] as num).toDouble(),
      fcr: json['fcr'] as double?,
      survivalRate: json['survivalRate'] as double?,
      sampleDate: DateTime.parse(json['sampleDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doc': doc,
      'actualAbw': actualAbw,
      'expectedAbw': expectedAbw,
      'performanceRatio': performanceRatio,
      'fcr': fcr,
      'survivalRate': survivalRate,
      'sampleDate': sampleDate.toIso8601String(),
    };
  }
}
