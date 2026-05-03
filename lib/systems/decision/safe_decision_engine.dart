/// Safe Decision Engine - ensures decisions are safe, practical, and trustworthy
/// Replaces exact numbers with ranges and implements strict safety constraints
library;

import 'dart:math';
import 'profit_decision_engine.dart';
import '../../core/models/real_world_anchors.dart';
import '../../core/models/growth_curve.dart';

class SafeDecisionEngine {
  static const double maxFeedChangePerDay = 0.10; // 10% max change per day
  static const double maxFeedChangePerWeek = 0.20; // 20% max change per week
  static const double minConfidenceForStrongAction = 0.8;
  static const double minConfidenceForModerateAction = 0.6;
  static const int maxDecisionsPerDay = 3; // Prevent decision fatigue

  /// Generate safe profit decisions with ranges and constraints
  static SafeProfitDecision generateSafeDecision({
    required FarmAnchors anchors,
    required List<PondProfitData> pondData,
    required MarketConditions marketConditions,
    required DecisionHistory history,
  }) {
    final decisions = <SafeDecisionType, SafeRecommendation>{};

    // Check if farm is stable enough for decisions
    if (!anchors.isStable) {
      return SafeProfitDecision(
        farmStability: anchors.overallStability,
        decisions: {},
        primaryDecision: const SafePrimaryDecision(
          type: SafeDecisionType.maintenance,
          title: '🔒 Farm Stability Mode',
          description:
              'Farm conditions require stabilization. Focus on basic operations.',
          confidenceRange: ConfidenceRange(0.3, 0.5),
          valueRange: ValueRange(0, 0),
          urgency: DecisionUrgency.low,
          actionItems: [
            'Monitor water quality daily',
            'Check shrimp health',
            'Maintain current feeding'
          ],
          safetyConstraints: ['No major changes until stability improves'],
          timeToImplement: Duration(days: 7),
        ),
        generatedAt: DateTime.now(),
        overallSafety: anchors.overallStability,
      );
    }

    // Generate safe feed decisions
    decisions[SafeDecisionType.feedOptimization] = _generateSafeFeedDecision(
      anchors,
      pondData,
      history,
    );

    // Generate safe harvest decisions
    decisions[SafeDecisionType.harvestTiming] = _generateSafeHarvestDecision(
      anchors,
      pondData,
      marketConditions,
      history,
    );

    // Generate safe cost-benefit decisions
    decisions[SafeDecisionType.costOptimization] = _generateSafeCostDecision(
      anchors,
      pondData,
      history,
    );

    // Select primary decision based on priority and safety
    final primaryDecision = _selectPrimarySafeDecision(decisions, anchors);

    return SafeProfitDecision(
      farmStability: anchors.overallStability,
      decisions: decisions,
      primaryDecision: primaryDecision,
      generatedAt: DateTime.now(),
      overallSafety: _calculateOverallSafety(decisions, anchors),
    );
  }

  /// Generate safe feed optimization decision
  static SafeRecommendation _generateSafeFeedDecision(
    FarmAnchors anchors,
    List<PondProfitData> pondData,
    DecisionHistory history,
  ) {
    final feedAnalysis = <String, dynamic>{};
    final recommendations = <String>[];
    final safetyConstraints = <String>[];

    double totalPotentialSavings = 0;
    const confidenceRange = ConfidenceRange(0.4, 0.8);

    for (final pond in pondData) {
      if (pond.currentFcr == null || pond.expectedFcr == null) continue;

      final currentFcr = pond.currentFcr!;
      final expectedFcr = pond.expectedFcr!;
      final fcrGap = currentFcr - expectedFcr;

      if (fcrGap > 0.2) {
        // Significant FCR improvement needed
        // Calculate safe feed reduction range
        final currentFeed = pond.todayFeed ?? 0;
        final maxReduction = currentFeed * maxFeedChangePerDay;
        final targetReduction = min(maxReduction, currentFeed * fcrGap * 0.5);

        final minSavings = targetReduction * 0.5 * 35; // Conservative estimate
        final maxSavings = targetReduction * 35;

        totalPotentialSavings += (minSavings + maxSavings) / 2;

        feedAnalysis[pond.pondId] = {
          'currentFcr': currentFcr,
          'expectedFcr': expectedFcr,
          'fcrGap': fcrGap,
          'currentFeed': currentFeed,
          'recommendedReduction':
              ValueRange(targetReduction * 0.5, targetReduction.toDouble()),
          'potentialSavings': ValueRange(minSavings, maxSavings),
        };

        // Add safety constraints
        safetyConstraints.addAll([
          'Monitor shrimp response for 48 hours',
          'Check tray response before further reduction',
          'Stop reduction if mortality observed',
          'Maintain minimum 3% body weight feed per day',
        ]);

        if (targetReduction > 0) {
          recommendations.add(
              '${pond.pondName}: Reduce feed by ${(targetReduction * 0.5).toStringAsFixed(0)}-${targetReduction.toStringAsFixed(0)}kg/day');
        }
      }
    }

    // Adjust confidence based on farm stability
    final adjustedConfidence =
        confidenceRange.adjustForStability(anchors.overallStability);

    return SafeRecommendation(
      type: SafeDecisionType.feedOptimization,
      title: 'Safe Feed Optimization',
      description: totalPotentialSavings > 0
          ? 'Potential savings: ₹${(totalPotentialSavings / 1000).toStringAsFixed(0)}-${((totalPotentialSavings * 1.5) / 1000).toStringAsFixed(0)}K through gradual feed optimization'
          : 'Feed efficiency is within acceptable range. Monitor current practices.',
      confidenceRange: adjustedConfidence,
      valueRange:
          ValueRange(totalPotentialSavings * 0.7, totalPotentialSavings * 1.3),
      urgency: totalPotentialSavings > 5000
          ? DecisionUrgency.high
          : DecisionUrgency.medium,
      actionItems: recommendations,
      safetyConstraints: safetyConstraints,
      implementationCost: 0,
      timeToImplement: const Duration(days: 7), // Gradual implementation
    );
  }

  /// Generate safe harvest timing decision
  static SafeRecommendation _generateSafeHarvestDecision(
    FarmAnchors anchors,
    List<PondProfitData> pondData,
    MarketConditions marketConditions,
    DecisionHistory history,
  ) {
    final harvestAnalysis = <String, dynamic>{};
    final recommendations = <String>[];
    final safetyConstraints = <String>[];

    double totalPotentialRevenue = 0;
    const confidenceRange = ConfidenceRange(0.5, 0.9);

    for (final pond in pondData) {
      if (pond.currentAbw == null) continue;

      final currentAbw = pond.currentAbw!;
      final currentBiomass = pond.estimatedBiomass ?? 0;

      // Calculate safe harvest window (not exact timing)
      final minDaysToHarvest =
          max(0, _calculateDaysToTargetSize(pond, 18.0) - 3);
      final maxDaysToHarvest = _calculateDaysToTargetSize(pond, 22.0) + 3;

      // Calculate revenue range
      final minRevenue = currentBiomass *
          marketConditions.currentPrice *
          0.95; // 5% market fluctuation
      final maxRevenue = currentBiomass * marketConditions.forecastPrice * 1.05;

      totalPotentialRevenue += (minRevenue + maxRevenue) / 2;

      harvestAnalysis[pond.pondId] = {
        'currentAbw': currentAbw,
        'currentBiomass': currentBiomass,
        'harvestWindow': ValueRange(
            minDaysToHarvest.toDouble(), maxDaysToHarvest.toDouble()),
        'revenueRange': ValueRange(minRevenue, maxRevenue),
      };

      // Add harvest safety constraints
      safetyConstraints.addAll([
        'Confirm buyer availability before harvest',
        'Check market prices on harvest day',
        'Ensure labor and equipment ready',
        'Have backup buyer in case of issues',
      ]);

      if (currentAbw >= 18.0 && minDaysToHarvest <= 7) {
        recommendations.add(
            '${pond.pondName}: Harvest ready - window $minDaysToHarvest-$maxDaysToHarvest days');
      } else if (minDaysToHarvest <= 21) {
        recommendations.add(
            '${pond.pondName}: Consider harvest in $minDaysToHarvest-${maxDaysToHarvest > 14 ? 14 : maxDaysToHarvest} days');
      }
    }

    // Adjust confidence based on market volatility
    final marketVolatility =
        (marketConditions.forecastPrice - marketConditions.currentPrice) /
            marketConditions.currentPrice;
    final adjustedConfidence = marketVolatility > 0.1
        ? ConfidenceRange(confidenceRange.min * 0.8, confidenceRange.max * 0.8)
        : confidenceRange;

    return SafeRecommendation(
      type: SafeDecisionType.harvestTiming,
      title: 'Safe Harvest Planning',
      description: totalPotentialRevenue > 0
          ? 'Revenue opportunity: ₹${(totalPotentialRevenue / 100000).toStringAsFixed(1)}-${((totalPotentialRevenue * 1.2) / 100000).toStringAsFixed(1)}L with optimal timing'
          : 'Monitor growth for optimal harvest timing.',
      confidenceRange: adjustedConfidence,
      valueRange:
          ValueRange(totalPotentialRevenue * 0.8, totalPotentialRevenue * 1.2),
      urgency: recommendations.isNotEmpty
          ? DecisionUrgency.medium
          : DecisionUrgency.low,
      actionItems: recommendations,
      safetyConstraints: safetyConstraints,
      implementationCost: 5000, // Harvest preparation costs
      timeToImplement: const Duration(days: 14),
    );
  }

  /// Generate safe cost optimization decision
  static SafeRecommendation _generateSafeCostDecision(
    FarmAnchors anchors,
    List<PondProfitData> pondData,
    DecisionHistory history,
  ) {
    final costAnalysis = <String, dynamic>{};
    final recommendations = <String>[];
    final safetyConstraints = <String>[];

    double totalPotentialSavings = 0;
    const confidenceRange = ConfidenceRange(0.3, 0.7);

    // Calculate current cost structure
    double totalFeedCost = 0;
    double totalOtherCosts = 0;

    for (final pond in pondData) {
      totalFeedCost += (pond.todayFeed ?? 0) * 35;
      totalOtherCosts += _calculateOtherCosts(pond);
    }

    // Analyze cost optimization opportunities with safety constraints
    if (totalOtherCosts > totalFeedCost * 0.4) {
      final potentialSavings =
          totalOtherCosts * 0.1; // Conservative 10% reduction
      totalPotentialSavings += potentialSavings;

      costAnalysis['otherCosts'] = {
        'current': totalOtherCosts,
        'potentialSavings':
            ValueRange(potentialSavings * 0.5, potentialSavings * 1.5),
      };

      safetyConstraints.addAll([
        'Do not reduce essential treatments',
        'Maintain water quality monitoring',
        'Keep emergency fund for unexpected costs',
        'Review labor contracts before changes',
      ]);

      recommendations.add(
          'Review operational costs for ${((potentialSavings / 1000).toStringAsFixed(0))}-${(((potentialSavings * 1.5) / 1000).toStringAsFixed(0))}K potential savings');
    }

    return SafeRecommendation(
      type: SafeDecisionType.costOptimization,
      title: 'Safe Cost Management',
      description: totalPotentialSavings > 0
          ? 'Cost optimization opportunity: ₹${(totalPotentialSavings / 1000).toStringAsFixed(0)}-${((totalPotentialSavings * 1.5) / 1000).toStringAsFixed(0)}K'
          : 'Cost structure is optimal. Maintain current operations.',
      confidenceRange: confidenceRange,
      valueRange:
          ValueRange(totalPotentialSavings * 0.6, totalPotentialSavings * 1.4),
      urgency: totalPotentialSavings > 3000
          ? DecisionUrgency.medium
          : DecisionUrgency.low,
      actionItems: recommendations,
      safetyConstraints: safetyConstraints,
      implementationCost: 1000, // Analysis and planning costs
      timeToImplement: const Duration(days: 21),
    );
  }

  /// Select primary safe decision based on priority and safety
  static SafePrimaryDecision _selectPrimarySafeDecision(
    Map<SafeDecisionType, SafeRecommendation> decisions,
    FarmAnchors anchors,
  ) {
    // Priority order with safety consideration
    final priorityOrder = [
      SafeDecisionType.feedOptimization,
      SafeDecisionType.harvestTiming,
      SafeDecisionType.costOptimization,
    ];

    for (final type in priorityOrder) {
      final decision = decisions[type];
      if (decision != null &&
          decision.confidenceRange.min >= minConfidenceForModerateAction) {
        return SafePrimaryDecision(
          type: type,
          title: decision.title,
          description: decision.description,
          confidenceRange: decision.confidenceRange,
          valueRange: decision.valueRange,
          urgency: decision.urgency,
          actionItems: decision.actionItems,
          safetyConstraints: decision.safetyConstraints,
          timeToImplement: decision.timeToImplement,
        );
      }
    }

    // Default to maintenance decision
    return const SafePrimaryDecision(
      type: SafeDecisionType.maintenance,
      title: '📊 Monitor Farm Performance',
      description:
          'All parameters within safe ranges. Continue current practices with regular monitoring.',
      confidenceRange: ConfidenceRange(0.7, 0.9),
      valueRange: ValueRange(0, 0),
      urgency: DecisionUrgency.low,
      actionItems: [
        'Continue regular monitoring',
        'Maintain current practices',
        'Watch for changes'
      ],
      safetyConstraints: ['No major changes without consultation'],
      timeToImplement: Duration(days: 7),
    );
  }

  /// Calculate overall safety score
  static double _calculateOverallSafety(
    Map<SafeDecisionType, SafeRecommendation> decisions,
    FarmAnchors anchors,
  ) {
    double safetyScore = anchors.overallStability;

    // Adjust based on decision confidence
    if (decisions.isNotEmpty) {
      final avgConfidence = decisions.values
          .fold<double>(0, (sum, d) => sum + d.confidenceRange.average);
      safetyScore = (safetyScore + avgConfidence) / 2;
    }

    return safetyScore.clamp(0.0, 1.0);
  }

  // Helper methods
  static int _calculateDaysToTargetSize(
      PondProfitData pond, double targetSize) {
    if (pond.currentAbw == null) return 999;

    final currentAbw = pond.currentAbw!;
    final growthRate = GrowthCurve.getGrowthRate(pond.doc);

    if (growthRate <= 0) return 999;
    return ((targetSize - currentAbw) / growthRate).ceil();
  }

  static double _calculateOtherCosts(PondProfitData pond) {
    final biomass = pond.estimatedBiomass ?? 0;
    return biomass * 10.0; // ₹10 per kg for other costs
  }
}

class SafeProfitDecision {
  final double farmStability;
  final Map<SafeDecisionType, SafeRecommendation> decisions;
  final SafePrimaryDecision primaryDecision;
  final DateTime generatedAt;
  final double overallSafety;

  const SafeProfitDecision({
    required this.farmStability,
    required this.decisions,
    required this.primaryDecision,
    required this.generatedAt,
    required this.overallSafety,
  });

  /// Get safety level text
  String get safetyLevelText {
    if (overallSafety >= 0.9) return 'Very Safe';
    if (overallSafety >= 0.7) return 'Safe';
    if (overallSafety >= 0.5) return 'Moderate';
    if (overallSafety >= 0.3) return 'Cautious';
    return 'Risky';
  }

  /// Get safety color
  String get safetyColor {
    if (overallSafety >= 0.7) return '#006A3A';
    if (overallSafety >= 0.5) return '#FFC107';
    if (overallSafety >= 0.3) return '#FF8F00';
    return '#E53935';
  }
}

class SafeRecommendation {
  final SafeDecisionType type;
  final String title;
  final String description;
  final ConfidenceRange confidenceRange;
  final ValueRange valueRange;
  final DecisionUrgency urgency;
  final List<String> actionItems;
  final List<String> safetyConstraints;
  final double implementationCost;
  final Duration timeToImplement;

  const SafeRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.confidenceRange,
    required this.valueRange,
    required this.urgency,
    required this.actionItems,
    required this.safetyConstraints,
    required this.implementationCost,
    required this.timeToImplement,
  });

  /// Get net benefit range
  ValueRange get netBenefitRange {
    return ValueRange(
      valueRange.min - implementationCost,
      valueRange.max - implementationCost,
    );
  }

  /// Get ROI range
  ValueRange get roiRange {
    if (implementationCost <= 0) {
      return const ValueRange(0, 0);
    }
    return ValueRange(
      (valueRange.min / implementationCost) * 100,
      (valueRange.max / implementationCost) * 100,
    );
  }
}

class SafePrimaryDecision {
  final SafeDecisionType type;
  final String title;
  final String description;
  final ConfidenceRange confidenceRange;
  final ValueRange valueRange;
  final DecisionUrgency urgency;
  final List<String> actionItems;
  final List<String> safetyConstraints;
  final Duration timeToImplement;

  const SafePrimaryDecision({
    required this.type,
    required this.title,
    required this.description,
    required this.confidenceRange,
    required this.valueRange,
    required this.urgency,
    required this.actionItems,
    required this.safetyConstraints,
    required this.timeToImplement,
  });

  /// Get formatted value range text
  String get valueRangeText {
    if (valueRange.max <= 0) return 'No direct value';

    final min = valueRange.min;
    final max = valueRange.max;

    if (min >= 100000) {
      return '₹${(min / 100000).toStringAsFixed(1)}-${(max / 100000).toStringAsFixed(1)}L';
    } else if (min >= 1000) {
      return '₹${(min / 1000).toStringAsFixed(1)}-${(max / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${min.toStringAsFixed(0)}-${max.toStringAsFixed(0)}';
    }
  }

  /// Get confidence range text
  String get confidenceRangeText {
    return '${(confidenceRange.min * 100).toStringAsFixed(0)}-${(confidenceRange.max * 100).toStringAsFixed(0)}%';
  }
}

class ConfidenceRange {
  final double min;
  final double max;

  const ConfidenceRange(this.min, this.max);

  double get average => (min + max) / 2;

  ConfidenceRange adjustForStability(double stability) {
    final adjustment = stability * 0.3; // Stability affects confidence
    return ConfidenceRange(
      (min * (1 - adjustment)).clamp(0.0, 1.0),
      (max * (1 - adjustment * 0.5)).clamp(0.0, 1.0),
    );
  }
}

class ValueRange {
  final double min;
  final double max;

  const ValueRange(this.min, this.max);

  double get average => (min + max) / 2;
}

class DecisionHistory {
  final List<HistoricalDecision> decisions;
  final int decisionsToday;

  const DecisionHistory({
    required this.decisions,
    required this.decisionsToday,
  });

  bool get canMakeMoreDecisions =>
      decisionsToday < SafeDecisionEngine.maxDecisionsPerDay;

  factory DecisionHistory.empty() {
    return const DecisionHistory(decisions: [], decisionsToday: 0);
  }
}

class HistoricalDecision {
  final DateTime timestamp;
  final SafeDecisionType type;
  final String description;
  final double confidence;
  final bool wasImplemented;

  const HistoricalDecision({
    required this.timestamp,
    required this.type,
    required this.description,
    required this.confidence,
    required this.wasImplemented,
  });
}

enum SafeDecisionType {
  feedOptimization,
  harvestTiming,
  costOptimization,
  maintenance,
}

enum DecisionUrgency {
  urgent,
  high,
  medium,
  low,
}
