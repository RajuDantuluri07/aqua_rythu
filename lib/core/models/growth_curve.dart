/// Scientific growth curve model for shrimp farming
/// Based on Litopenaeus vannamei (Pacific white shrimp) industry standards
/// Temperature: 28-30°C, Salinity: 15-25 ppt, Stocking density: 50-100 PL/m²

import 'dart:math';

class GrowthCurve {
  final int doc;
  final double expectedAbw; // Expected Average Body Weight in grams
  final double minAbw; // Minimum acceptable ABW for healthy growth
  final double maxAbw; // Maximum expected ABW (upper range)
  final double growthRate; // Daily growth rate in grams
  final double fcr; // Expected Feed Conversion Ratio at this stage

  const GrowthCurve({
    required this.doc,
    required this.expectedAbw,
    required this.minAbw,
    required this.maxAbw,
    required this.growthRate,
    required this.fcr,
  });

  /// Get expected ABW for given DOC using interpolation
  static double getExpectedAbw(int doc) {
    if (doc <= 0) return 0.01; // PL size at stocking
    if (doc >= 120) return 25.0; // Maximum harvest size

    // Growth phases with different rates
    if (doc <= 30) {
      // Nursery phase: rapid growth
      return _interpolateGrowth(doc, 0.01, 1.0, 30);
    } else if (doc <= 60) {
      // Grow-out phase 1: steady growth
      return _interpolateGrowth(doc, 1.0, 8.0, 60);
    } else if (doc <= 90) {
      // Grow-out phase 2: moderate growth
      return _interpolateGrowth(doc, 8.0, 15.0, 90);
    } else {
      // Grow-out phase 3: slower growth approaching harvest
      return _interpolateGrowth(doc, 15.0, 25.0, 120);
    }
  }

  /// Get acceptable ABW range for given DOC
  static GrowthRange getAcceptableRange(int doc) {
    final expected = getExpectedAbw(doc);
    
    // Acceptable range: ±20% of expected for most stages
    // Wider range (±30%) for early stages due to higher variability
    final tolerance = doc <= 30 ? 0.30 : 0.20;
    
    return GrowthRange(
      min: max(0.01, expected * (1 - tolerance)),
      expected: expected,
      max: expected * (1 + tolerance),
    );
  }

  /// Get growth rate for given DOC (grams per day)
  static double getGrowthRate(int doc) {
    if (doc <= 0) return 0.01;
    if (doc >= 120) return 0.05;

    if (doc <= 30) {
      // Nursery: ~0.03g/day
      return 0.033;
    } else if (doc <= 60) {
      // Early grow-out: ~0.23g/day
      return 0.233;
    } else if (doc <= 90) {
      // Mid grow-out: ~0.23g/day
      return 0.233;
    } else {
      // Late grow-out: ~0.33g/day
      return 0.333;
    }
  }

  /// Get expected FCR for given DOC
  static double getExpectedFcr(int doc) {
    if (doc <= 0) return 1.0;
    if (doc >= 120) return 1.8;

    // FCR increases with size
    if (doc <= 30) return 1.0;  // Nursery phase
    if (doc <= 60) return 1.2;  // Early grow-out
    if (doc <= 90) return 1.4;  // Mid grow-out
    return 1.6;  // Late grow-out
  }

  /// Calculate growth performance score
  static GrowthPerformance calculatePerformance({
    required int doc,
    required double actualAbw,
    DateTime? lastSampleDate,
  }) {
    final range = getAcceptableRange(doc);
    final expected = range.expected;
    
    // Calculate performance ratio
    final performanceRatio = actualAbw / expected;
    
    // Determine growth status
    GrowthStatus status;
    double score;
    
    if (performanceRatio >= 1.2) {
      status = GrowthStatus.excellent;
      score = min(100, 80 + (performanceRatio - 1.2) * 100);
    } else if (performanceRatio >= 1.0) {
      status = GrowthStatus.good;
      score = 60 + (performanceRatio - 1.0) * 100;
    } else if (performanceRatio >= 0.8) {
      status = GrowthStatus.fair;
      score = 40 + (performanceRatio - 0.8) * 100;
    } else if (performanceRatio >= 0.6) {
      status = GrowthStatus.poor;
      score = 20 + (performanceRatio - 0.6) * 100;
    } else {
      status = GrowthStatus.critical;
      score = max(0, performanceRatio * 33.33);
    }

    // Calculate confidence based on data freshness
    double confidence = 1.0;
    if (lastSampleDate != null) {
      final daysSinceSample = DateTime.now().difference(lastSampleDate).inDays;
      if (daysSinceSample > 14) {
        confidence = max(0.3, 1.0 - (daysSinceSample - 14) * 0.05);
      }
    } else {
      confidence = 0.2; // No sampling data
    }

    return GrowthPerformance(
      doc: doc,
      actualAbw: actualAbw,
      expectedAbw: expected,
      performanceRatio: performanceRatio,
      status: status,
      score: score,
      confidence: confidence,
      lastSampleDate: lastSampleDate,
    );
  }

  /// Interpolate growth between two points
  static double _interpolateGrowth(int currentDoc, double startAbw, double endAbw, int endDoc) {
    final startDoc = endDoc - 30; // Assuming 30-day phases
    final progress = (currentDoc - startDoc) / (endDoc - startDoc);
    
    // Use logarithmic growth curve for more realistic modeling
    final logProgress = log(progress + 1) / log(2);
    return startAbw + (endAbw - startAbw) * logProgress;
  }

  /// Get growth phase description
  static String getGrowthPhase(int doc) {
    if (doc <= 15) return 'Nursery (Acclimation)';
    if (doc <= 30) return 'Nursery (Growth)';
    if (doc <= 60) return 'Grow-out (Early)';
    if (doc <= 90) return 'Grow-out (Mid)';
    if (doc <= 120) return 'Grow-out (Late)';
    return 'Harvest Ready';
  }

  /// Get recommended actions based on growth performance
  static List<String> getRecommendedActions(GrowthPerformance performance) {
    final actions = <String>[];
    
    switch (performance.status) {
      case GrowthStatus.critical:
        actions.addAll([
          'Urgent: Check water quality parameters',
          'Review feeding regime - may be underfeeding',
          'Consider emergency sampling to verify data',
          'Check for disease symptoms',
        ]);
        break;
      case GrowthStatus.poor:
        actions.addAll([
          'Increase feed quantity by 10-15%',
          'Check water quality (pH, ammonia, nitrite)',
          'Verify feed quality and storage',
          'Consider probiotic supplementation',
        ]);
        break;
      case GrowthStatus.fair:
        actions.addAll([
          'Monitor growth closely',
          'Optimize feeding schedule',
          'Consider slight feed adjustment',
          'Regular water quality testing',
        ]);
        break;
      case GrowthStatus.good:
        actions.addAll([
          'Maintain current practices',
          'Regular monitoring',
          'Plan for harvest timing',
          'Continue water quality management',
        ]);
        break;
      case GrowthStatus.excellent:
        actions.addAll([
          'Consider early harvest planning',
          'Maintain optimal conditions',
          'Prepare for market timing',
          'Document successful practices',
        ]);
        break;
    }

    // Add confidence-based actions
    if (performance.confidence < 0.5) {
      actions.insert(0, 'Low confidence: Recent sampling recommended');
    }

    return actions;
  }
}

class GrowthRange {
  final double min;
  final double expected;
  final double max;

  const GrowthRange({
    required this.min,
    required this.expected,
    required this.max,
  });

  bool isInRange(double abw) => abw >= min && abw <= max;
  double getRangeRatio(double abw) => (abw - min) / (max - min);
}

enum GrowthStatus {
  critical,
  poor,
  fair,
  good,
  excellent,
}

class GrowthPerformance {
  final int doc;
  final double actualAbw;
  final double expectedAbw;
  final double performanceRatio;
  final GrowthStatus status;
  final double score; // 0-100
  final double confidence; // 0-1
  final DateTime? lastSampleDate;

  const GrowthPerformance({
    required this.doc,
    required this.actualAbw,
    required this.expectedAbw,
    required this.performanceRatio,
    required this.status,
    required this.score,
    required this.confidence,
    this.lastSampleDate,
  });

  String get statusText {
    switch (status) {
      case GrowthStatus.critical: return 'Critical';
      case GrowthStatus.poor: return 'Poor';
      case GrowthStatus.fair: return 'Fair';
      case GrowthStatus.good: return 'Good';
      case GrowthStatus.excellent: return 'Excellent';
    }
  }

  String get confidenceText {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.4) return 'Low';
    return 'Very Low';
  }
}
