// Water Insight Service - Separate water analysis from feed calculations
//
// This service provides water quality insights and recommendations
// WITHOUT affecting feed calculations. Feed engine uses water only for safety stops.
//
// Responsibilities:
// - Analyze water data trends
// - Generate actionable recommendations
// - Provide insights for farm management
// - NO connection to feed engine (read-only)

import 'package:aqua_rythu/core/utils/logger.dart';

// ── WATER INSIGHT MODELS ────────────────────────────────────────────────────────

/// Water quality status classification
enum WaterStatus {
  excellent,
  good,
  fair,
  poor,
  critical,
}

/// Water insight with recommendations
class WaterInsight {
  final WaterStatus status;
  final List<String> recommendations;
  final List<String> alerts;
  final String summary;
  final Map<String, dynamic> metrics;

  const WaterInsight({
    required this.status,
    required this.recommendations,
    required this.alerts,
    required this.summary,
    required this.metrics,
  });
}

/// Water parameters for analysis
class WaterParameters {
  final double dissolvedOxygen;
  final double ammonia;
  final double temperature;
  final double pH;
  final double nitrite;
  final double nitrate;
  final DateTime timestamp;

  const WaterParameters({
    required this.dissolvedOxygen,
    required this.ammonia,
    required this.temperature,
    required this.pH,
    this.nitrite = 0.0,
    this.nitrate = 0.0,
    required this.timestamp,
  });
}

// ── WATER INSIGHT SERVICE ───────────────────────────────────────────────────────

class WaterInsightService {
  static const String version = 'v1.0.0';

  // ── THRESHOLDS ────────────────────────────────────────────────────────────────

  static const double kCriticalDOLow = 2.0;      // mg/L - Stop feeding
  static const double kWarningDOLow = 3.5;       // mg/L - Alert
  static const double kGoodDOMin = 5.0;          // mg/L - Good

  static const double kCriticalAmmoniaHigh = 2.0; // ppm - Stop feeding  
  static const double kWarningAmmoniaHigh = 0.5;  // ppm - Alert
  static const double kGoodAmmoniaMax = 0.2;      // ppm - Good

  static const double kOptimalTempMin = 26.0;     // °C
  static const double kOptimalTempMax = 32.0;     // °C

  static const double kOptimalPHMin = 7.0;        // pH
  static const double kOptimalPHMax = 8.5;        // pH

  // ── ANALYSIS METHODS ───────────────────────────────────────────────────────────

  /// Analyze current water parameters and generate insights
  /// 
  /// This method ONLY provides insights - it does NOT affect feed calculations
  static WaterInsight analyzeWater(WaterParameters params) {
    AppLogger.info('WaterInsightService: Analyzing water parameters');
    
    final recommendations = <String>[];
    final alerts = <String>[];
    final metrics = <String, dynamic>{};
    
    // Analyze Dissolved Oxygen
    final doStatus = _analyzeDissolvedOxygen(params.dissolvedOxygen, recommendations, alerts);
    metrics['do_status'] = doStatus.name;
    metrics['do_value'] = params.dissolvedOxygen;
    
    // Analyze Ammonia
    final ammoniaStatus = _analyzeAmmonia(params.ammonia, recommendations, alerts);
    metrics['ammonia_status'] = ammoniaStatus.name;
    metrics['ammonia_value'] = params.ammonia;
    
    // Analyze Temperature
    final tempStatus = _analyzeTemperature(params.temperature, recommendations, alerts);
    metrics['temp_status'] = tempStatus.name;
    metrics['temp_value'] = params.temperature;
    
    // Analyze pH
    final phStatus = _analyzePH(params.pH, recommendations, alerts);
    metrics['ph_status'] = phStatus.name;
    metrics['ph_value'] = params.pH;
    
    // Determine overall status
    final overallStatus = _determineOverallStatus(doStatus, ammoniaStatus, tempStatus, phStatus);
    
    // Generate summary
    final summary = _generateSummary(overallStatus, params);
    
    return WaterInsight(
      status: overallStatus,
      recommendations: recommendations,
      alerts: alerts,
      summary: summary,
      metrics: metrics,
    );
  }

  /// Analyze water trends over time
  static WaterInsight analyzeTrends(List<WaterParameters> history) {
    if (history.isEmpty) {
      return const WaterInsight(
        status: WaterStatus.good,
        recommendations: ['No water data available'],
        alerts: [],
        summary: 'No water history to analyze',
        metrics: {},
      );
    }

    final current = history.last;
    final recent = history.length > 1 ? history[history.length - 2] : current;
    
    // Calculate trends
    final doTrend = current.dissolvedOxygen - recent.dissolvedOxygen;
    final ammoniaTrend = current.ammonia - recent.ammonia;
    final tempTrend = current.temperature - recent.temperature;
    
    final recommendations = <String>[];
    final alerts = <String>[];
    
    // Analyze trends
    if (doTrend < -0.5) {
      alerts.add('DO dropping rapidly (-${doTrend.toStringAsFixed(1)} mg/L)');
      recommendations.add('Increase aeration immediately');
    } else if (doTrend > 0.5) {
      recommendations.add('DO improving - maintain current aeration');
    }
    
    if (ammoniaTrend > 0.1) {
      alerts.add('Ammonia rising (+${ammoniaTrend.toStringAsFixed(2)} ppm)');
      recommendations.add('Check feeding rates and consider water exchange');
    } else if (ammoniaTrend < -0.1) {
      recommendations.add('Ammonia decreasing - good water quality trend');
    }
    
    if (tempTrend > 2.0) {
      alerts.add('Temperature rising rapidly (+${tempTrend.toStringAsFixed(1)}°C)');
      recommendations.add('Monitor for oxygen stress');
    } else if (tempTrend < -2.0) {
      recommendations.add('Temperature dropping - monitor shrimp activity');
    }
    
    // Get current analysis
    final currentInsight = analyzeWater(current);
    
    return WaterInsight(
      status: currentInsight.status,
      recommendations: [...currentInsight.recommendations, ...recommendations],
      alerts: [...currentInsight.alerts, ...alerts],
      summary: _generateTrendSummary(currentInsight.status, doTrend, ammoniaTrend, tempTrend),
      metrics: {
        ...currentInsight.metrics,
        'do_trend': doTrend,
        'ammonia_trend': ammoniaTrend,
        'temp_trend': tempTrend,
      },
    );
  }

  // ── PRIVATE ANALYSIS HELPERS ─────────────────────────────────────────────────────

  static WaterStatus _analyzeDissolvedOxygen(double doValue, List<String> recommendations, List<String> alerts) {
    if (doValue < kCriticalDOLow) {
      alerts.add('CRITICAL: DO below $kCriticalDOLow mg/L - shrimp stress');
      recommendations.add('EMERGENCY: Increase aeration immediately');
      recommendations.add('Consider partial water exchange');
      return WaterStatus.critical;
    } else if (doValue < kWarningDOLow) {
      alerts.add('WARNING: DO below $kWarningDOLow mg/L');
      recommendations.add('Increase aeration');
      recommendations.add('Monitor shrimp behavior closely');
      return WaterStatus.poor;
    } else if (doValue < kGoodDOMin) {
      recommendations.add('Moderate aeration recommended');
      return WaterStatus.fair;
    } else {
      recommendations.add('DO levels are good');
      return WaterStatus.good;
    }
  }

  static WaterStatus _analyzeAmmonia(double ammoniaValue, List<String> recommendations, List<String> alerts) {
    if (ammoniaValue > kCriticalAmmoniaHigh) {
      alerts.add('CRITICAL: Ammonia above $kCriticalAmmoniaHigh ppm - toxic levels');
      recommendations.add('EMERGENCY: Stop feeding temporarily');
      recommendations.add('Immediate water exchange required');
      recommendations.add('Check for dead shrimp');
      return WaterStatus.critical;
    } else if (ammoniaValue > kWarningAmmoniaHigh) {
      alerts.add('WARNING: Ammonia above $kWarningAmmoniaHigh ppm');
      recommendations.add('Reduce feeding slightly');
      recommendations.add('Increase water exchange');
      recommendations.add('Add beneficial bacteria');
      return WaterStatus.poor;
    } else if (ammoniaValue > kGoodAmmoniaMax) {
      recommendations.add('Consider slight feeding reduction');
      recommendations.add('Monitor ammonia trends');
      return WaterStatus.fair;
    } else {
      recommendations.add('Ammonia levels are good');
      return WaterStatus.good;
    }
  }

  static WaterStatus _analyzeTemperature(double tempValue, List<String> recommendations, List<String> alerts) {
    if (tempValue < 20.0) {
      alerts.add('WARNING: Low temperature - reduced metabolism');
      recommendations.add('Reduce feeding accordingly');
      recommendations.add('Monitor for disease');
      return WaterStatus.fair;
    } else if (tempValue >= kOptimalTempMin && tempValue <= kOptimalTempMax) {
      recommendations.add('Temperature is optimal for growth');
      return WaterStatus.excellent;
    } else if (tempValue > 35.0) {
      alerts.add('WARNING: High temperature - increased oxygen demand');
      recommendations.add('Increase aeration');
      recommendations.add('Monitor DO levels closely');
      return WaterStatus.poor;
    } else {
      recommendations.add('Temperature is acceptable');
      return WaterStatus.good;
    }
  }

  static WaterStatus _analyzePH(double pHValue, List<String> recommendations, List<String> alerts) {
    if (pHValue < 6.5) {
      alerts.add('WARNING: Low pH - affects shrimp health');
      recommendations.add('Consider pH buffering');
      recommendations.add('Monitor for ammonia toxicity increase');
      return WaterStatus.poor;
    } else if (pHValue >= kOptimalPHMin && pHValue <= kOptimalPHMax) {
      recommendations.add('pH is optimal');
      return WaterStatus.excellent;
    } else if (pHValue > 9.0) {
      alerts.add('WARNING: High pH - ammonia toxicity risk');
      recommendations.add('Monitor ammonia levels closely');
      recommendations.add('Consider pH reduction');
      return WaterStatus.poor;
    } else {
      recommendations.add('pH is acceptable');
      return WaterStatus.good;
    }
  }

  static WaterStatus _determineOverallStatus(
    WaterStatus doStatus,
    WaterStatus ammoniaStatus,
    WaterStatus tempStatus,
    WaterStatus phStatus,
  ) {
    final statuses = [doStatus, ammoniaStatus, tempStatus, phStatus];
    
    // If any parameter is critical, overall is critical
    if (statuses.contains(WaterStatus.critical)) {
      return WaterStatus.critical;
    }
    
    // If any parameter is poor, overall is poor
    if (statuses.contains(WaterStatus.poor)) {
      return WaterStatus.poor;
    }
    
    // If any parameter is fair, overall is fair
    if (statuses.contains(WaterStatus.fair)) {
      return WaterStatus.fair;
    }
    
    // If any parameter is excellent and none are below good
    if (statuses.contains(WaterStatus.excellent)) {
      return WaterStatus.excellent;
    }
    
    // Default to good
    return WaterStatus.good;
  }

  static String _generateSummary(WaterStatus status, WaterParameters params) {
    switch (status) {
      case WaterStatus.critical:
        return 'CRITICAL: Immediate action required - water quality dangerous';
      case WaterStatus.poor:
        return 'Poor water quality - intervention needed soon';
      case WaterStatus.fair:
        return 'Fair water quality - monitoring and minor adjustments recommended';
      case WaterStatus.good:
        return 'Good water quality - normal operations';
      case WaterStatus.excellent:
        return 'Excellent water quality - optimal for shrimp growth';
    }
  }

  static String _generateTrendSummary(WaterStatus status, double doTrend, double ammoniaTrend, double tempTrend) {
    final trends = <String>[];
    
    if (doTrend.abs() > 0.5) {
      trends.add('DO ${doTrend > 0 ? 'improving' : 'declining'}');
    }
    
    if (ammoniaTrend.abs() > 0.1) {
      trends.add('Ammonia ${ammoniaTrend > 0 ? 'rising' : 'falling'}');
    }
    
    if (tempTrend.abs() > 2.0) {
      trends.add('Temp ${tempTrend > 0 ? 'warming' : 'cooling'}');
    }
    
    final trendText = trends.isNotEmpty ? ' (${trends.join(', ')})' : '';
    
    switch (status) {
      case WaterStatus.critical:
        return 'CRITICAL: Water quality deteriorating$trendText - immediate action required';
      case WaterStatus.poor:
        return 'Poor water quality$trendText - intervention needed';
      case WaterStatus.fair:
        return 'Fair water quality$trendText - monitoring recommended';
      case WaterStatus.good:
        return 'Good water quality$trendText - maintain current practices';
      case WaterStatus.excellent:
        return 'Excellent water quality$trendText - optimal conditions';
    }
  }
}
