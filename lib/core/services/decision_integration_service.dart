/// Decision Integration Service - transforms all data into actionable decisions
/// The final layer that moves from "insights" to "decisions"

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/farm_profile.dart';
import '../models/profit_decision_engine.dart';
import '../models/adaptive_insights.dart';
import '../services/farmer_feedback_service.dart';
import '../utils/logger.dart';

class DecisionIntegrationService {
  static DecisionIntegrationService? _instance;
  static DecisionIntegrationService get instance =>
      _instance ??= DecisionIntegrationService._();

  DecisionIntegrationService._();

  /// Generate comprehensive farm decisions
  Future<FarmDecision> generateFarmDecision({
    required String farmId,
    required String farmName,
    required List<PondDecisionData> pondData,
    required MarketConditions marketConditions,
  }) async {
    try {
      AppLogger.info('Generating farm decision for $farmName');

      // 1. Load or create farm profile
      final farmProfile =
          await _getOrCreateFarmProfile(farmId, farmName, pondData);

      // 2. Generate profit decisions
      final profitDecision = ProfitDecisionEngine.generateProfitDecision(
        farmProfile: farmProfile,
        pondData: _convertToPondProfitData(pondData),
        marketConditions: marketConditions,
      );

      // 3. Generate adaptive insights
      final adaptiveInsights = _generateAdaptiveInsights(farmProfile, pondData);

      // 4. Integrate feedback learning
      final feedbackAdjusted =
          await _applyFeedbackLearning(profitDecision, adaptiveInsights);

      // 5. Create final decision
      final finalDecision = FarmDecision(
        farmId: farmId,
        farmName: farmName,
        farmProfile: farmProfile,
        profitDecision: feedbackAdjusted.profitDecision,
        adaptiveInsights: feedbackAdjusted.adaptiveInsights,
        marketConditions: marketConditions,
        generatedAt: DateTime.now(),
        overallConfidence:
            _calculateOverallDecisionConfidence(feedbackAdjusted),
      );

      // 6. Update farm profile with new data
      await _updateFarmProfile(finalDecision);

      AppLogger.info('Farm decision generated successfully for $farmName');
      return finalDecision;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to generate farm decision', e, stackTrace);
      rethrow;
    }
  }

  /// Get primary decision for farmer
  PrimaryDecision getPrimaryDecision(FarmDecision decision) {
    // Priority order: Urgent profit decisions > High profit decisions > Critical insights

    // Check urgent profit decisions
    final urgentProfitDecisions = decision.profitDecision.decisions.values
        .where((d) =>
            d.priority == DecisionPriority.urgent && d.potentialSavings > 5000);

    if (urgentProfitDecisions.isNotEmpty) {
      final topDecision = urgentProfitDecisions
          .reduce((a, b) => a.potentialSavings > b.potentialSavings ? a : b);
      return PrimaryDecision(
        type: DecisionType.profitOptimization,
        title: topDecision.title,
        description: topDecision.description,
        potentialValue: topDecision.potentialSavings,
        confidence: topDecision.confidence,
        urgency: DecisionUrgency.urgent,
        actionItems: topDecision.actionItems,
        timeToImplement: topDecision.timeToImplement,
      );
    }

    // Check critical adaptive insights
    final criticalInsights = decision.adaptiveInsights
        .where((i) => i.type == InsightType.critical && i.confidence > 0.7);

    if (criticalInsights.isNotEmpty) {
      final topInsight = criticalInsights.first;
      return PrimaryDecision(
        type: DecisionType.criticalAction,
        title: topInsight.title,
        description: topInsight.description,
        potentialValue: 0, // Insights don't have direct monetary value
        confidence: topInsight.combinedConfidence,
        urgency: DecisionUrgency.urgent,
        actionItems: [topInsight.description],
        timeToImplement: const Duration(days: 1),
      );
    }

    // Check high-value profit opportunities
    final highValueDecisions = decision.profitDecision.decisions.values.where(
        (d) =>
            d.priority == DecisionPriority.high && d.potentialSavings > 10000);

    if (highValueDecisions.isNotEmpty) {
      final topDecision = highValueDecisions
          .reduce((a, b) => a.potentialSavings > b.potentialSavings ? a : b);
      return PrimaryDecision(
        type: DecisionType.profitOptimization,
        title: topDecision.title,
        description: topDecision.description,
        potentialValue: topDecision.potentialSavings,
        confidence: topDecision.confidence,
        urgency: DecisionUrgency.high,
        actionItems: topDecision.actionItems,
        timeToImplement: topDecision.timeToImplement,
      );
    }

    // Default to status/maintenance decision
    return PrimaryDecision(
      type: DecisionType.maintenance,
      title: '📊 Farm Operating Optimally',
      description: 'All systems performing well. Continue current practices.',
      potentialValue: 0,
      confidence: decision.overallConfidence,
      urgency: DecisionUrgency.low,
      actionItems: ['Continue monitoring', 'Maintain current practices'],
      timeToImplement: const Duration(days: 7),
    );
  }

  /// Get decision summary for quick overview
  DecisionSummary getDecisionSummary(FarmDecision decision) {
    final primaryDecision = getPrimaryDecision(decision);
    final totalOpportunity = decision.profitDecision.totalPotentialSavings;
    final criticalIssues = decision.adaptiveInsights
        .where((i) => i.type == InsightType.critical)
        .length;
    final highValueOpportunities = decision.profitDecision.decisions.values
        .where((d) => d.potentialSavings > 10000)
        .length;

    return DecisionSummary(
      primaryDecision: primaryDecision,
      totalOpportunity: totalOpportunity,
      criticalIssues: criticalIssues,
      highValueOpportunities: highValueOpportunities,
      overallHealth: _calculateFarmHealth(decision),
      nextReviewDate: DateTime.now().add(const Duration(days: 7)),
    );
  }

  // Private helper methods

  Future<FarmProfile> _getOrCreateFarmProfile(
      String farmId, String farmName, List<PondDecisionData> pondData) async {
    // In a real implementation, this would load from database
    // For now, create default profile with learned adjustments

    final profile = FarmProfile.createDefault(farmId, farmName);

    // Apply learned adjustments from pond data
    FarmProfile updatedProfile = profile;
    for (final pond in pondData) {
      if (pond.actualAbw != null && pond.expectedAbw != null) {
        updatedProfile = updatedProfile.updateWithPerformanceData(
          doc: pond.doc,
          actualAbw: pond.actualAbw!,
          expectedAbw: pond.expectedAbw!,
          sampleDate: pond.lastSampleDate ?? DateTime.now(),
          fcr: pond.currentFcr,
        );
      }
    }

    return updatedProfile;
  }

  List<PondProfitData> _convertToPondProfitData(
      List<PondDecisionData> pondData) {
    return pondData
        .map((pond) => PondProfitData(
              pondId: pond.pondId,
              pondName: pond.pondName,
              doc: pond.doc,
              currentAbw: pond.actualAbw,
              currentFcr: pond.currentFcr,
              expectedFcr: pond.expectedFcr,
              todayFeed: pond.todayFeed,
              estimatedBiomass: pond.estimatedBiomass,
              dataConfidence: _calculateDataConfidence(pond),
            ))
        .toList();
  }

  double _calculateDataConfidence(PondDecisionData pond) {
    double confidence = 1.0;

    // Sampling data freshness
    if (pond.lastSampleDate != null) {
      final daysSinceSample =
          DateTime.now().difference(pond.lastSampleDate!).inDays;
      if (daysSinceSample > 7) confidence *= 0.8;
      if (daysSinceSample > 14) confidence *= 0.6;
      if (daysSinceSample > 21) confidence *= 0.4;
      if (daysSinceSample > 30) confidence *= 0.2;
    } else {
      confidence *= 0.3; // No sampling data
    }

    // Data completeness
    if (pond.actualAbw == null) confidence *= 0.5;
    if (pond.currentFcr == null) confidence *= 0.7;
    if (pond.todayFeed == null) confidence *= 0.8;

    return confidence.clamp(0.0, 1.0);
  }

  List<AdaptiveInsight> _generateAdaptiveInsights(
      FarmProfile farmProfile, List<PondDecisionData> pondData) {
    final insights = <AdaptiveInsight>[];

    for (final pond in pondData) {
      if (pond.actualAbw != null && pond.expectedAbw != null) {
        final performanceRatio = pond.actualAbw! / pond.expectedAbw!;
        final confidence = _calculateDataConfidence(pond);

        // Growth performance insights
        if (performanceRatio < 0.6 && confidence > 0.5) {
          insights.add(AdaptiveInsight(
            id: 'growth_critical_${pond.pondId}',
            title: '🚨 Critical Growth Issue - ${pond.pondName}',
            description:
                'Growth at ${(performanceRatio * 100).toStringAsFixed(0)}% of expected. Immediate intervention required.',
            type: InsightType.critical,
            icon: Icons.warning,
            confidence: confidence,
            priority: InsightPriority.urgent,
            source: InsightSource.growthAnalysis,
            generatedAt: DateTime.now(),
          ));
        } else if (performanceRatio > 1.2 && confidence > 0.7) {
          insights.add(AdaptiveInsight(
            id: 'growth_excellent_${pond.pondId}',
            title: '🌟 Exceptional Growth - ${pond.pondName}',
            description:
                'Growth ${(performanceRatio * 100).toStringAsFixed(0)}% above expected. Consider early harvest.',
            type: InsightType.opportunity,
            icon: Icons.trending_up,
            confidence: confidence,
            priority: InsightPriority.high,
            source: InsightSource.growthAnalysis,
            generatedAt: DateTime.now(),
          ));
        }
      }

      // FCR insights
      if (pond.currentFcr != null && pond.expectedFcr != null) {
        final fcrGap = pond.currentFcr! - pond.expectedFcr!;
        if (fcrGap > 0.3) {
          insights.add(AdaptiveInsight(
            id: 'fcr_high_${pond.pondId}',
            title: '⚠️ High FCR Alert - ${pond.pondName}',
            description:
                'FCR ${pond.currentFcr!.toStringAsFixed(2)} exceeds optimal ${pond.expectedFcr!.toStringAsFixed(2)}. Optimize feeding.',
            type: InsightType.warning,
            icon: Icons.restaurant,
            confidence: _calculateDataConfidence(pond),
            priority: InsightPriority.high,
            source: InsightSource.feedEfficiency,
            generatedAt: DateTime.now(),
          ));
        }
      }

      // Sampling reminders
      if (pond.lastSampleDate != null) {
        final daysSinceSample =
            DateTime.now().difference(pond.lastSampleDate!).inDays;
        if (daysSinceSample > 21) {
          insights.add(AdaptiveInsight(
            id: 'sampling_overdue_${pond.pondId}',
            title: '🔬 Sampling Overdue - ${pond.pondName}',
            description:
                '$daysSinceSample days since last sample. Critical for accurate decisions.',
            type: InsightType.warning,
            icon: Icons.science,
            confidence: 0.9,
            priority: InsightPriority.high,
            source: InsightSource.samplingData,
            generatedAt: DateTime.now(),
          ));
        }
      }
    }

    return insights;
  }

  Future<FeedbackAdjustedDecision> _applyFeedbackLearning(
    ProfitDecision profitDecision,
    List<AdaptiveInsight> adaptiveInsights,
  ) async {
    // Get feedback patterns
    final feedbackService = FarmerFeedbackService.instance;
    final patterns = await feedbackService.analyzeFeedbackPatterns();
    final typePerformance = patterns.getTypePerformance();

    // Adjust confidence based on historical feedback
    final adjustedInsights = adaptiveInsights.map((insight) {
      final insightType = _extractInsightType(insight.id);
      final historicalPerformance = typePerformance[insightType] ?? 0.5;

      // Blend current confidence with historical performance
      final adjustedConfidence =
          (insight.confidence * 0.7) + (historicalPerformance * 0.3);

      return insight.copyWith(confidence: adjustedConfidence);
    }).toList();

    // Adjust profit decision confidence based on feedback
    final adjustedProfitConfidence =
        _adjustProfitDecisionConfidence(profitDecision, typePerformance);

    return FeedbackAdjustedDecision(
      profitDecision:
          profitDecision.copyWith(overallConfidence: adjustedProfitConfidence),
      adaptiveInsights: adjustedInsights,
    );
  }

  String _extractInsightType(String insightId) {
    if (insightId.startsWith('growth_')) return 'growth';
    if (insightId.startsWith('feed_') || insightId.startsWith('fcr_'))
      return 'feed';
    if (insightId.startsWith('sampling_')) return 'sampling';
    if (insightId.startsWith('harvest_')) return 'harvest';
    return 'other';
  }

  double _adjustProfitDecisionConfidence(
      ProfitDecision profitDecision, Map<String, double> typePerformance) {
    // Get average performance for relevant decision types
    final feedPerformance = typePerformance['feed'] ?? 0.5;
    final harvestPerformance = typePerformance['harvest'] ?? 0.5;

    // Weight by decision importance
    final avgPerformance = (feedPerformance * 0.6) + (harvestPerformance * 0.4);

    // Blend with current confidence
    return (profitDecision.overallConfidence * 0.8) + (avgPerformance * 0.2);
  }

  double _calculateOverallDecisionConfidence(
      FeedbackAdjustedDecision adjusted) {
    final profitConfidence = adjusted.profitDecision.overallConfidence;
    final insightConfidence = adjusted.adaptiveInsights.isEmpty
        ? 0.5
        : adjusted.adaptiveInsights
                .fold<double>(0, (sum, i) => sum + i.confidence) /
            adjusted.adaptiveInsights.length;

    return (profitConfidence * 0.7) + (insightConfidence * 0.3);
  }

  Future<void> _updateFarmProfile(FarmDecision decision) async {
    // In a real implementation, this would save to database
    AppLogger.info('Farm profile updated for ${decision.farmName}');
  }

  FarmHealthStatus _calculateFarmHealth(FarmDecision decision) {
    final criticalIssues = decision.adaptiveInsights
        .where((i) => i.type == InsightType.critical)
        .length;
    final warnings = decision.adaptiveInsights
        .where((i) => i.type == InsightType.warning)
        .length;
    final opportunities = decision.adaptiveInsights
        .where((i) => i.type == InsightType.opportunity)
        .length;

    if (criticalIssues > 0) return FarmHealthStatus.critical;
    if (warnings > 2) return FarmHealthStatus.poor;
    if (warnings > 0) return FarmHealthStatus.fair;
    if (opportunities > 0) return FarmHealthStatus.good;
    return FarmHealthStatus.excellent;
  }
}

class FarmDecision {
  final String farmId;
  final String farmName;
  final FarmProfile farmProfile;
  final ProfitDecision profitDecision;
  final List<AdaptiveInsight> adaptiveInsights;
  final MarketConditions marketConditions;
  final DateTime generatedAt;
  final double overallConfidence;

  const FarmDecision({
    required this.farmId,
    required this.farmName,
    required this.farmProfile,
    required this.profitDecision,
    required this.adaptiveInsights,
    required this.marketConditions,
    required this.generatedAt,
    required this.overallConfidence,
  });

  /// Get decision confidence text
  String get confidenceText {
    if (overallConfidence >= 0.9) return 'Very High';
    if (overallConfidence >= 0.7) return 'High';
    if (overallConfidence >= 0.5) return 'Medium';
    if (overallConfidence >= 0.3) return 'Low';
    return 'Very Low';
  }

  /// Get total value opportunity
  double get totalValueOpportunity {
    return profitDecision.totalPotentialSavings;
  }
}

class PrimaryDecision {
  final DecisionType type;
  final String title;
  final String description;
  final double potentialValue; // Monetary value in rupees
  final double confidence;
  final DecisionUrgency urgency;
  final List<String> actionItems;
  final Duration timeToImplement;

  const PrimaryDecision({
    required this.type,
    required this.title,
    required this.description,
    required this.potentialValue,
    required this.confidence,
    required this.urgency,
    required this.actionItems,
    required this.timeToImplement,
  });

  /// Get formatted value text
  String get valueText {
    if (potentialValue >= 100000) {
      return '₹${(potentialValue / 100000).toStringAsFixed(1)}L';
    } else if (potentialValue >= 1000) {
      return '₹${(potentialValue / 1000).toStringAsFixed(1)}K';
    } else if (potentialValue > 0) {
      return '₹${potentialValue.toStringAsFixed(0)}';
    } else {
      return 'No direct value';
    }
  }
}

class DecisionSummary {
  final PrimaryDecision primaryDecision;
  final double totalOpportunity;
  final int criticalIssues;
  final int highValueOpportunities;
  final FarmHealthStatus overallHealth;
  final DateTime nextReviewDate;

  const DecisionSummary({
    required this.primaryDecision,
    required this.totalOpportunity,
    required this.criticalIssues,
    required this.highValueOpportunities,
    required this.overallHealth,
    required this.nextReviewDate,
  });

  /// Get health status text
  String get healthText {
    switch (overallHealth) {
      case FarmHealthStatus.excellent:
        return 'Excellent';
      case FarmHealthStatus.good:
        return 'Good';
      case FarmHealthStatus.fair:
        return 'Fair';
      case FarmHealthStatus.poor:
        return 'Poor';
      case FarmHealthStatus.critical:
        return 'Critical';
    }
  }

  /// Get health color
  String get healthColor {
    switch (overallHealth) {
      case FarmHealthStatus.excellent:
        return '#006A3A';
      case FarmHealthStatus.good:
        return '#006A3A';
      case FarmHealthStatus.fair:
        return '#FFC107';
      case FarmHealthStatus.poor:
        return '#FF8F00';
      case FarmHealthStatus.critical:
        return '#E53935';
    }
  }
}

class FeedbackAdjustedDecision {
  final ProfitDecision profitDecision;
  final List<AdaptiveInsight> adaptiveInsights;

  const FeedbackAdjustedDecision({
    required this.profitDecision,
    required this.adaptiveInsights,
  });
}

class PondDecisionData {
  final String pondId;
  final String pondName;
  final int doc;
  final double? actualAbw;
  final double? expectedAbw;
  final double? currentFcr;
  final double? expectedFcr;
  final double? todayFeed;
  final double? estimatedBiomass;
  final DateTime? lastSampleDate;

  const PondDecisionData({
    required this.pondId,
    required this.pondName,
    required this.doc,
    this.actualAbw,
    this.expectedAbw,
    this.currentFcr,
    this.expectedFcr,
    this.todayFeed,
    this.estimatedBiomass,
    this.lastSampleDate,
  });
}

enum DecisionType {
  profitOptimization,
  criticalAction,
  maintenance,
  opportunity,
}

enum DecisionUrgency {
  urgent,
  high,
  medium,
  low,
}

enum FarmHealthStatus {
  excellent,
  good,
  fair,
  poor,
  critical,
}
