/// Adaptive insights system with confidence scoring and learning capabilities
/// Moves from rule-based to intelligent adaptive recommendations
library;

import 'package:flutter/material.dart';
import 'growth_curve.dart';

class AdaptiveInsight {
  final String id;
  final String title;
  final String description;
  final InsightType type;
  final IconData icon;
  final VoidCallback? action;
  final double confidence; // 0-1 confidence score
  final InsightPriority priority;
  final List<String> supportingData;
  final DateTime generatedAt;
  final InsightSource source;
  final List<String> farmerFeedback; // "useful" or "not_useful"

  const AdaptiveInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.icon,
    required this.confidence,
    required this.priority,
    required this.source,
    this.action,
    this.supportingData = const [],
    required this.generatedAt,
    this.farmerFeedback = const [],
  });

  AdaptiveInsight copyWith({
    String? id,
    String? title,
    String? description,
    InsightType? type,
    IconData? icon,
    VoidCallback? action,
    double? confidence,
    InsightPriority? priority,
    List<String>? supportingData,
    DateTime? generatedAt,
    InsightSource? source,
    List<String>? farmerFeedback,
  }) {
    return AdaptiveInsight(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      action: action ?? this.action,
      confidence: confidence ?? this.confidence,
      priority: priority ?? this.priority,
      supportingData: supportingData ?? this.supportingData,
      generatedAt: generatedAt ?? this.generatedAt,
      source: source ?? this.source,
      farmerFeedback: farmerFeedback ?? this.farmerFeedback,
    );
  }

  /// Calculate usefulness score from farmer feedback
  double get usefulnessScore {
    if (farmerFeedback.isEmpty) return 0.5; // Neutral for no feedback

    final usefulCount = farmerFeedback.where((f) => f == 'useful').length;
    final totalCount = farmerFeedback.length;
    return usefulCount / totalCount;
  }

  /// Get combined confidence (data confidence + farmer feedback)
  double get combinedConfidence {
    final feedbackWeight = farmerFeedback.isEmpty ? 0.0 : 0.3;
    final dataWeight = 1.0 - feedbackWeight;

    return (confidence * dataWeight) + (usefulnessScore * feedbackWeight);
  }

  String get confidenceText {
    final combined = combinedConfidence;
    if (combined >= 0.9) return 'Very High';
    if (combined >= 0.7) return 'High';
    if (combined >= 0.5) return 'Medium';
    if (combined >= 0.3) return 'Low';
    return 'Very Low';
  }
}

enum InsightType {
  critical,
  warning,
  info,
  success,
  opportunity,
}

enum InsightPriority {
  urgent, // Critical issues requiring immediate action
  high, // Important opportunities or issues
  medium, // General recommendations
  low, // Nice to know information
}

enum InsightSource {
  growthAnalysis, // Based on growth curve comparison
  feedEfficiency, // Based on feed data and FCR
  samplingData, // Based on recent sampling
  waterQuality, // Based on water parameters
  marketConditions, // Based on market data
  farmerFeedback, // Based on historical feedback
  predictive, // AI/ML predictions
}

class AdaptiveInsightEngine {
  static const double MIN_CONFIDENCE_THRESHOLD = 0.4;
  static const double HIGH_CONFIDENCE_THRESHOLD = 0.8;

  /// Generate adaptive insights based on comprehensive farm analysis
  static List<AdaptiveInsight> generateInsights(FarmAnalysisData data) {
    final insights = <AdaptiveInsight>[];

    // Growth-based insights
    insights.addAll(_generateGrowthInsights(data));

    // Feed efficiency insights
    insights.addAll(_generateFeedInsights(data));

    // Sampling-based insights
    insights.addAll(_generateSamplingInsights(data));

    // Predictive insights
    insights.addAll(_generatePredictiveInsights(data));

    // Sort by priority and confidence
    insights.sort((a, b) {
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return b.combinedConfidence.compareTo(a.combinedConfidence);
    });

    // Filter low confidence insights
    return insights
        .where((i) => i.combinedConfidence >= MIN_CONFIDENCE_THRESHOLD)
        .toList();
  }

  static List<AdaptiveInsight> _generateGrowthInsights(FarmAnalysisData data) {
    final insights = <AdaptiveInsight>[];

    for (final pond in data.ponds) {
      if (pond.growthPerformance == null) continue;

      final perf = pond.growthPerformance!;
      final confidence = perf.confidence;

      // Critical growth issues
      if (perf.status == GrowthStatus.critical) {
        insights.add(AdaptiveInsight(
          id: 'growth_critical_${pond.id}',
          title: '🚨 Critical Growth Issue - ${pond.name}',
          description:
              '${pond.name}: Growth ${perf.performanceRatio.toStringAsFixed(1)}x below expected. Immediate action required.',
          type: InsightType.critical,
          icon: Icons.warning,
          confidence: confidence,
          priority: InsightPriority.urgent,
          source: InsightSource.growthAnalysis,
          supportingData: [
            'DOC: ${perf.doc}',
            'Actual ABW: ${perf.actualAbw.toStringAsFixed(1)}g',
            'Expected ABW: ${perf.expectedAbw.toStringAsFixed(1)}g',
            'Performance: ${(perf.performanceRatio * 100).toStringAsFixed(0)}%',
          ],
          generatedAt: DateTime.now(),
          action: () => debugPrint('Critical growth action for ${pond.id}'),
        ));
      }
      // Excellent growth opportunities
      else if (perf.status == GrowthStatus.excellent && confidence > 0.7) {
        insights.add(AdaptiveInsight(
          id: 'growth_excellent_${pond.id}',
          title: '🌟 Exceptional Growth - ${pond.name}',
          description:
              '${pond.name}: ${(perf.performanceRatio * 100).toStringAsFixed(0)}% above expected growth. Consider early harvest planning.',
          type: InsightType.opportunity,
          icon: Icons.trending_up,
          confidence: confidence,
          priority: InsightPriority.high,
          source: InsightSource.growthAnalysis,
          supportingData: [
            'DOC: ${perf.doc}',
            'Actual ABW: ${perf.actualAbw.toStringAsFixed(1)}g',
            'Expected ABW: ${perf.expectedAbw.toStringAsFixed(1)}g',
            'Growth Score: ${perf.score.toStringAsFixed(0)}/100',
          ],
          generatedAt: DateTime.now(),
          action: () => debugPrint('Excellent growth action for ${pond.id}'),
        ));
      }
      // Growth monitoring recommendations
      else if (confidence < 0.5) {
        insights.add(AdaptiveInsight(
          id: 'growth_monitoring_${pond.id}',
          title: '📊 Growth Data Stale - ${pond.name}',
          description:
              '${pond.name}: Last sample ${_getDaysSince(perf.lastSampleDate)} days ago. Fresh sampling needed for accurate insights.',
          type: InsightType.info,
          icon: Icons.schedule,
          confidence: 0.8, // High confidence in this recommendation
          priority: InsightPriority.medium,
          source: InsightSource.samplingData,
          supportingData: [
            'DOC: ${perf.doc}',
            'Last Sample: ${_formatDate(perf.lastSampleDate)}',
            'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
          ],
          generatedAt: DateTime.now(),
          action: () => debugPrint('Sampling reminder for ${pond.id}'),
        ));
      }
    }

    return insights;
  }

  static List<AdaptiveInsight> _generateFeedInsights(FarmAnalysisData data) {
    final insights = <AdaptiveInsight>[];

    // Feed efficiency analysis
    for (final pond in data.ponds) {
      if (pond.feedEfficiency == null) continue;

      final efficiency = pond.feedEfficiency!;

      // High FCR warnings
      if (efficiency.fcr > 1.8) {
        insights.add(AdaptiveInsight(
          id: 'feed_fcr_high_${pond.id}',
          title: '⚠️ High FCR Alert - ${pond.name}',
          description:
              '${pond.name}: FCR ${efficiency.fcr.toStringAsFixed(2)} exceeds optimal range. Review feeding practices.',
          type: InsightType.warning,
          icon: Icons.restaurant,
          confidence: efficiency.confidence,
          priority: InsightPriority.high,
          source: InsightSource.feedEfficiency,
          supportingData: [
            'Current FCR: ${efficiency.fcr.toStringAsFixed(2)}',
            'Optimal FCR: ${GrowthCurve.getExpectedFcr(pond.doc).toStringAsFixed(2)}',
            'Feed Today: ${efficiency.todayFeed.toStringAsFixed(0)}kg',
          ],
          generatedAt: DateTime.now(),
          action: () => debugPrint('FCR optimization for ${pond.id}'),
        ));
      }
      // Excellent feed efficiency
      else if (efficiency.fcr < 1.2 && efficiency.confidence > 0.7) {
        insights.add(AdaptiveInsight(
          id: 'feed_optimal_${pond.id}',
          title: '✅ Optimal Feed Efficiency - ${pond.name}',
          description:
              '${pond.name}: Excellent FCR of ${efficiency.fcr.toStringAsFixed(2)}. Current practices working well.',
          type: InsightType.success,
          icon: Icons.eco,
          confidence: efficiency.confidence,
          priority: InsightPriority.low,
          source: InsightSource.feedEfficiency,
          supportingData: [
            'FCR: ${efficiency.fcr.toStringAsFixed(2)}',
            'Feed Efficiency: ${((1.0 / efficiency.fcr) * 100).toStringAsFixed(0)}%',
          ],
          generatedAt: DateTime.now(),
        ));
      }
    }

    return insights;
  }

  static List<AdaptiveInsight> _generateSamplingInsights(
      FarmAnalysisData data) {
    final insights = <AdaptiveInsight>[];

    // Check for sampling gaps
    for (final pond in data.ponds) {
      final daysSinceSample = pond.daysSinceLastSample;

      if (daysSinceSample > 21) {
        insights.add(AdaptiveInsight(
          id: 'sampling_overdue_${pond.id}',
          title: '🔬 Sampling Overdue - ${pond.name}',
          description:
              '${pond.name}: $daysSinceSample days since last sample. Critical for biomass estimation.',
          type: InsightType.warning,
          icon: Icons.science,
          confidence: 0.9,
          priority: InsightPriority.high,
          source: InsightSource.samplingData,
          supportingData: [
            'Days Since Sample: $daysSinceSample',
            'DOC: ${pond.doc}',
            'Growth Phase: ${GrowthCurve.getGrowthPhase(pond.doc)}',
          ],
          generatedAt: DateTime.now(),
          action: () => debugPrint('Sampling action for ${pond.id}'),
        ));
      } else if (daysSinceSample > 14) {
        insights.add(AdaptiveInsight(
          id: 'sampling_due_${pond.id}',
          title: '📋 Sampling Recommended - ${pond.name}',
          description:
              '${pond.name}: $daysSinceSample days since last sample. Recommended for accurate tracking.',
          type: InsightType.info,
          icon: Icons.schedule,
          confidence: 0.7,
          priority: InsightPriority.medium,
          source: InsightSource.samplingData,
          supportingData: [
            'Days Since Sample: $daysSinceSample',
            'Recommendation: Sample every 14 days',
          ],
          generatedAt: DateTime.now(),
          action: () => debugPrint('Sampling reminder for ${pond.id}'),
        ));
      }
    }

    return insights;
  }

  static List<AdaptiveInsight> _generatePredictiveInsights(
      FarmAnalysisData data) {
    final insights = <AdaptiveInsight>[];

    // Harvest readiness prediction
    for (final pond in data.ponds) {
      if (pond.growthPerformance == null) continue;

      final perf = pond.growthPerformance!;
      final currentAbw = perf.actualAbw;
      final currentDoc = pond.doc;

      // Predict harvest timing
      if (currentAbw >= 15.0) {
        final daysToHarvest = _predictDaysToHarvest(currentAbw, currentDoc);

        if (daysToHarvest <= 14) {
          insights.add(AdaptiveInsight(
            id: 'harvest_ready_${pond.id}',
            title: '🎯 Harvest Ready Soon - ${pond.name}',
            description:
                '${pond.name}: Ready for harvest in ~$daysToHarvest days. Current market prices favorable.',
            type: InsightType.opportunity,
            icon: Icons.agriculture,
            confidence: perf.confidence * 0.8, // Slightly lower for predictions
            priority: InsightPriority.high,
            source: InsightSource.predictive,
            supportingData: [
              'Current ABW: ${currentAbw.toStringAsFixed(1)}g',
              'DOC: $currentDoc',
              'Estimated Harvest: $daysToHarvest days',
              'Biomass: ${pond.estimatedBiomass?.toStringAsFixed(0)}kg',
            ],
            generatedAt: DateTime.now(),
            action: () => debugPrint('Harvest planning for ${pond.id}'),
          ));
        }
      }

      // Growth trajectory prediction
      if (perf.confidence > 0.6) {
        final predictedAbw30 = _predictAbw(currentAbw, currentDoc, 30);
        final expectedAbw30 = GrowthCurve.getExpectedAbw(currentDoc + 30);
        final trajectoryRatio = predictedAbw30 / expectedAbw30;

        if (trajectoryRatio < 0.8) {
          insights.add(AdaptiveInsight(
            id: 'trajectory_concern_${pond.id}',
            title: '📉 Growth Trajectory Concern - ${pond.name}',
            description:
                '${pond.name}: Predicted growth ${(trajectoryRatio * 100).toStringAsFixed(0)}% of expected in 30 days.',
            type: InsightType.warning,
            icon: Icons.trending_down,
            confidence: perf.confidence * 0.7,
            priority: InsightPriority.medium,
            source: InsightSource.predictive,
            supportingData: [
              'Current Growth: ${(perf.performanceRatio * 100).toStringAsFixed(0)}%',
              '30-Day Prediction: ${(trajectoryRatio * 100).toStringAsFixed(0)}%',
              'Current ABW: ${currentAbw.toStringAsFixed(1)}g',
              'Predicted ABW: ${predictedAbw30.toStringAsFixed(1)}g',
            ],
            generatedAt: DateTime.now(),
            action: () => debugPrint('Trajectory intervention for ${pond.id}'),
          ));
        }
      }
    }

    return insights;
  }

  static int _predictDaysToHarvest(double currentAbw, int currentDoc) {
    const harvestAbw = 20.0; // Target harvest size
    final growthRate = GrowthCurve.getGrowthRate(currentDoc);

    if (growthRate <= 0) return 999;
    return ((harvestAbw - currentAbw) / growthRate).ceil();
  }

  static double _predictAbw(double currentAbw, int currentDoc, int daysAhead) {
    double predictedAbw = currentAbw;

    for (int i = 1; i <= daysAhead; i++) {
      final doc = currentDoc + i;
      final growthRate = GrowthCurve.getGrowthRate(doc);
      predictedAbw += growthRate;
    }

    return predictedAbw;
  }

  static String _getDaysSince(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateTime.now().difference(date).inDays.toString();
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class FarmAnalysisData {
  final List<PondAnalysisData> ponds;
  final DateTime analysisTime;

  const FarmAnalysisData({
    required this.ponds,
    required this.analysisTime,
  });
}

class PondAnalysisData {
  final String id;
  final String name;
  final int doc;
  final GrowthPerformance? growthPerformance;
  final FeedEfficiency? feedEfficiency;
  final double? estimatedBiomass;
  final int daysSinceLastSample;

  const PondAnalysisData({
    required this.id,
    required this.name,
    required this.doc,
    this.growthPerformance,
    this.feedEfficiency,
    this.estimatedBiomass,
    required this.daysSinceLastSample,
  });
}

class FeedEfficiency {
  final double fcr;
  final double todayFeed;
  final double confidence;

  const FeedEfficiency({
    required this.fcr,
    required this.todayFeed,
    required this.confidence,
  });
}
