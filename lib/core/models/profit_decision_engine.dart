/// Profit Decision Engine - transforms data into actionable decisions
/// Moves from "insights" to "decisions" with economic optimization
library;

import 'dart:math';
import 'growth_curve.dart';
import 'farm_profile.dart';

class ProfitDecisionEngine {
  static const double FEED_COST_PER_KG = 35.0; // ₹35 per kg
  static const double MARKET_PRICE_PER_KG = 300.0; // ₹300 per kg
  static const double MIN_PROFIT_MARGIN = 0.2; // 20% minimum profit margin

  /// Generate comprehensive profit decisions for the farm
  static ProfitDecision generateProfitDecision({
    required FarmProfile farmProfile,
    required List<PondProfitData> pondData,
    required MarketConditions marketConditions,
  }) {
    final decisions = <ProfitDecisionType, ProfitRecommendation>{};

    // Feed optimization decisions
    decisions[ProfitDecisionType.feedOptimization] = _analyzeFeedOptimization(
      farmProfile,
      pondData,
      marketConditions,
    );

    // Harvest timing decisions
    decisions[ProfitDecisionType.harvestTiming] = _analyzeHarvestTiming(
      farmProfile,
      pondData,
      marketConditions,
    );

    // Cost-benefit analysis
    decisions[ProfitDecisionType.costBenefit] = _analyzeCostBenefit(
      farmProfile,
      pondData,
      marketConditions,
    );

    // Revenue optimization
    decisions[ProfitDecisionType.revenueOptimization] =
        _analyzeRevenueOptimization(
      farmProfile,
      pondData,
      marketConditions,
    );

    return ProfitDecision(
      farmProfile: farmProfile,
      decisions: decisions,
      generatedAt: DateTime.now(),
      overallConfidence: _calculateOverallConfidence(decisions),
    );
  }

  /// Analyze feed optimization decisions
  static ProfitRecommendation _analyzeFeedOptimization(
    FarmProfile farmProfile,
    List<PondProfitData> pondData,
    MarketConditions marketConditions,
  ) {
    final feedAnalysis = <String, dynamic>{};
    double totalPotentialSavings = 0;
    final recommendations = <String>[];

    for (final pond in pondData) {
      if (pond.currentFcr == null || pond.expectedFcr == null) continue;

      final currentFcr = pond.currentFcr!;
      final expectedFcr = pond.expectedFcr!;
      final fcrGap = currentFcr - expectedFcr;

      if (fcrGap > 0.2) {
        // Significant FCR improvement needed
        final feedReduction = _calculateOptimalFeedReduction(pond, fcrGap);
        final costSavings = feedReduction * FEED_COST_PER_KG;

        totalPotentialSavings += costSavings;

        feedAnalysis[pond.pondId] = {
          'currentFcr': currentFcr,
          'expectedFcr': expectedFcr,
          'fcrGap': fcrGap,
          'recommendedReduction': feedReduction,
          'potentialSavings': costSavings,
          'confidence': pond.dataConfidence,
        };

        if (fcrGap > 0.5) {
          recommendations.add(
              '${pond.pondName}: Reduce feed by ${feedReduction.toStringAsFixed(0)}kg/day (FCR gap: ${fcrGap.toStringAsFixed(2)})');
        }
      }
    }

    final priority = totalPotentialSavings > 5000
        ? DecisionPriority.urgent
        : totalPotentialSavings > 2000
            ? DecisionPriority.high
            : DecisionPriority.medium;

    return ProfitRecommendation(
      type: ProfitDecisionType.feedOptimization,
      title: 'Feed Optimization Decision',
      description: totalPotentialSavings > 0
          ? 'Potential savings: ₹${totalPotentialSavings.toStringAsFixed(0)} by optimizing feed across ${pondData.length} ponds'
          : 'Feed efficiency is optimal. Maintain current practices.',
      potentialSavings: totalPotentialSavings,
      confidence: _calculateFeedConfidence(pondData),
      priority: priority,
      actionItems: recommendations,
      analysis: feedAnalysis,
      implementationCost: 0, // No cost to reduce feed
      timeToImplement: const Duration(days: 1), // Immediate
    );
  }

  /// Analyze harvest timing decisions
  static ProfitRecommendation _analyzeHarvestTiming(
    FarmProfile farmProfile,
    List<PondProfitData> pondData,
    MarketConditions marketConditions,
  ) {
    final harvestAnalysis = <String, dynamic>{};
    double totalPotentialRevenue = 0;
    final recommendations = <String>[];

    for (final pond in pondData) {
      if (pond.currentAbw == null) continue;

      final currentAbw = pond.currentAbw!;
      final currentBiomass = pond.estimatedBiomass ?? 0;
      final daysToOptimal = _calculateDaysToOptimalHarvest(pond, farmProfile);

      // Calculate revenue curves
      final revenueNow = currentBiomass * marketConditions.currentPrice;
      final revenueOptimal = _calculateRevenueAtOptimalHarvest(
          pond, marketConditions, daysToOptimal);
      final revenueGap = revenueOptimal - revenueNow;

      if (revenueGap > 10000) {
        // Significant revenue gain by waiting
        totalPotentialRevenue += revenueGap;

        harvestAnalysis[pond.pondId] = {
          'currentAbw': currentAbw,
          'currentBiomass': currentBiomass,
          'daysToOptimal': daysToOptimal,
          'revenueNow': revenueNow,
          'revenueOptimal': revenueOptimal,
          'revenueGap': revenueGap,
          'confidence': pond.dataConfidence,
        };

        if (daysToOptimal <= 14) {
          recommendations.add(
              '${pond.pondName}: Harvest in $daysToOptimal days for +₹${(revenueGap / 1000).toStringAsFixed(1)}K revenue');
        } else if (daysToOptimal <= 30) {
          recommendations.add(
              '${pond.pondName}: Consider harvest in $daysToOptimal days for optimal revenue');
        }
      } else if (daysToOptimal <= 7 && currentAbw >= 18.0) {
        // Ready for harvest
        recommendations
            .add('${pond.pondName}: Harvest now - optimal size reached');
      }
    }

    final priority = totalPotentialRevenue > 100000
        ? DecisionPriority.urgent
        : totalPotentialRevenue > 50000
            ? DecisionPriority.high
            : DecisionPriority.medium;

    return ProfitRecommendation(
      type: ProfitDecisionType.harvestTiming,
      title: 'Harvest Timing Decision',
      description: totalPotentialRevenue > 0
          ? 'Additional revenue: ₹${(totalPotentialRevenue / 1000).toStringAsFixed(1)}K by optimizing harvest timing'
          : 'Harvest timing is optimal. Current market conditions are favorable.',
      potentialSavings: totalPotentialRevenue,
      confidence: _calculateHarvestConfidence(pondData),
      priority: priority,
      actionItems: recommendations,
      analysis: harvestAnalysis,
      implementationCost: 0,
      timeToImplement: Duration(
          days: recommendations.isNotEmpty
              ? recommendations.first.contains('now')
                  ? 0
                  : 7
              : 30),
    );
  }

  /// Analyze cost-benefit decisions
  static ProfitRecommendation _analyzeCostBenefit(
    FarmProfile farmProfile,
    List<PondProfitData> pondData,
    MarketConditions marketConditions,
  ) {
    var costBenefitAnalysis = <String, dynamic>{};
    final recommendations = <String>[];
    double totalNetBenefit = 0;

    // Calculate current cost structure
    double totalFeedCost = 0;
    double totalRevenue = 0;
    double totalOtherCosts = 0;

    for (final pond in pondData) {
      totalFeedCost += (pond.todayFeed ?? 0) * FEED_COST_PER_KG;
      totalRevenue +=
          (pond.estimatedBiomass ?? 0) * marketConditions.currentPrice;
      totalOtherCosts += _calculateOtherCosts(pond);
    }

    final currentProfit = totalRevenue - totalFeedCost - totalOtherCosts;
    final profitMargin = totalRevenue > 0 ? currentProfit / totalRevenue : 0;

    // Analyze cost optimization opportunities
    if (profitMargin < MIN_PROFIT_MARGIN) {
      // Need to improve profitability
      final feedOptimization = _calculateFeedOptimizationBenefit(pondData);
      final harvestOptimization =
          _calculateHarvestOptimizationBenefit(pondData, marketConditions);

      totalNetBenefit = feedOptimization + harvestOptimization;

      if (feedOptimization > 1000) {
        recommendations.add(
            'Reduce feed costs by ₹${(feedOptimization / 1000).toStringAsFixed(1)}K through FCR optimization');
      }

      if (harvestOptimization > 5000) {
        recommendations.add(
            'Optimize harvest timing for additional ₹${(harvestOptimization / 1000).toStringAsFixed(1)}K revenue');
      }

      if (totalOtherCosts > totalFeedCost * 0.3) {
        recommendations.add(
            'Review other operational costs - currently ${(totalOtherCosts / 1000).toStringAsFixed(1)}K');
      }
    }

    costBenefitAnalysis = {
      'totalRevenue': totalRevenue,
      'totalFeedCost': totalFeedCost,
      'totalOtherCosts': totalOtherCosts,
      'currentProfit': currentProfit,
      'profitMargin': profitMargin,
      'targetMargin': MIN_PROFIT_MARGIN,
      'totalNetBenefit': totalNetBenefit,
    };

    final priority = profitMargin < 0.1
        ? DecisionPriority.urgent
        : profitMargin < MIN_PROFIT_MARGIN
            ? DecisionPriority.high
            : DecisionPriority.low;

    return ProfitRecommendation(
      type: ProfitDecisionType.costBenefit,
      title: 'Cost-Benefit Analysis',
      description: profitMargin >= MIN_PROFIT_MARGIN
          ? 'Profit margin ${(profitMargin * 100).toStringAsFixed(1)}% is healthy. Maintain current operations.'
          : 'Profit margin ${(profitMargin * 100).toStringAsFixed(1)}% below target ${(MIN_PROFIT_MARGIN * 100).toStringAsFixed(0)}%. Optimization needed.',
      potentialSavings: totalNetBenefit,
      confidence: _calculateCostBenefitConfidence(pondData),
      priority: priority,
      actionItems: recommendations,
      analysis: costBenefitAnalysis,
      implementationCost:
          recommendations.length * 500, // Estimated implementation cost
      timeToImplement: const Duration(days: 7),
    );
  }

  /// Analyze revenue optimization decisions
  static ProfitRecommendation _analyzeRevenueOptimization(
    FarmProfile farmProfile,
    List<PondProfitData> pondData,
    MarketConditions marketConditions,
  ) {
    var revenueAnalysis = <String, dynamic>{};
    final recommendations = <String>[];
    double totalRevenueOpportunity = 0;

    // Market timing analysis
    if (marketConditions.priceTrend == PriceTrend.increasing &&
        marketConditions.forecastPrice > marketConditions.currentPrice * 1.05) {
      final priceIncrease =
          (marketConditions.forecastPrice - marketConditions.currentPrice) *
              pondData.fold<double>(
                  0, (sum, pond) => sum + (pond.estimatedBiomass ?? 0));
      totalRevenueOpportunity += priceIncrease;

      recommendations.add(
          'Delay harvest by 7-14 days to benefit from price increase to ₹${marketConditions.forecastPrice.toStringAsFixed(0)}/kg');
    }

    // Size premium analysis
    for (final pond in pondData) {
      if (pond.currentAbw != null &&
          pond.currentAbw! >= 15.0 &&
          pond.currentAbw! < 20.0) {
        final daysToSize20 =
            _calculateDaysToTargetSize(pond, 20.0, farmProfile);
        if (daysToSize20 <= 21) {
          final sizePremium = _calculateSizePremium(pond, marketConditions);
          totalRevenueOpportunity += sizePremium;

          recommendations.add(
              '${pond.pondName}: Grow to 20g in $daysToSize20 days for size premium +₹${(sizePremium / 1000).toStringAsFixed(1)}K');
        }
      }
    }

    revenueAnalysis = {
      'currentPrice': marketConditions.currentPrice,
      'forecastPrice': marketConditions.forecastPrice,
      'priceTrend': marketConditions.priceTrend.toString(),
      'totalRevenueOpportunity': totalRevenueOpportunity,
    };

    final priority = totalRevenueOpportunity > 20000
        ? DecisionPriority.high
        : totalRevenueOpportunity > 10000
            ? DecisionPriority.medium
            : DecisionPriority.low;

    return ProfitRecommendation(
      type: ProfitDecisionType.revenueOptimization,
      title: 'Revenue Optimization Decision',
      description: totalRevenueOpportunity > 0
          ? 'Revenue opportunity: ₹${(totalRevenueOpportunity / 1000).toStringAsFixed(1)}K through strategic timing and size optimization'
          : 'Current revenue strategy is optimal. Market conditions are favorable.',
      potentialSavings: totalRevenueOpportunity,
      confidence: _calculateRevenueConfidence(pondData, marketConditions),
      priority: priority,
      actionItems: recommendations,
      analysis: revenueAnalysis,
      implementationCost: 0,
      timeToImplement: const Duration(days: 14),
    );
  }

  // Helper methods for calculations

  static double _calculateOptimalFeedReduction(
      PondProfitData pond, double fcrGap) {
    // Calculate feed reduction needed to close FCR gap
    final currentFeed = pond.todayFeed ?? 0;
    final reductionRatio = min(0.3, fcrGap * 0.5); // Max 30% reduction
    return currentFeed * reductionRatio;
  }

  static int _calculateDaysToOptimalHarvest(
      PondProfitData pond, FarmProfile farmProfile) {
    if (pond.currentAbw == null) return 999;

    final currentAbw = pond.currentAbw!;
    const targetAbw = 20.0; // Optimal harvest size

    // Use farm-specific growth rates
    final growthRate = _getFarmSpecificGrowthRate(farmProfile, pond.doc);

    if (growthRate <= 0) return 999;
    return ((targetAbw - currentAbw) / growthRate).ceil();
  }

  static double _getFarmSpecificGrowthRate(FarmProfile farmProfile, int doc) {
    final baseRate = GrowthCurve.getGrowthRate(doc);
    final adjustment = farmProfile.growthFactors.getAdjustmentForDoc(doc);
    return baseRate * adjustment;
  }

  static double _calculateRevenueAtOptimalHarvest(
      PondProfitData pond, MarketConditions market, int daysToOptimal) {
    if (pond.currentAbw == null) return 0;

    final currentAbw = pond.currentAbw!;
    final currentBiomass = pond.estimatedBiomass ?? 0;

    // Calculate projected biomass at optimal harvest
    final growthRate =
        _getFarmSpecificGrowthRate(FarmProfile.createDefault('', ''), pond.doc);
    final projectedAbw = currentAbw + (growthRate * daysToOptimal);
    final biomassGrowthRatio = projectedAbw / currentAbw;
    final projectedBiomass = currentBiomass * biomassGrowthRatio;

    return projectedBiomass * market.forecastPrice;
  }

  static double _calculateOtherCosts(PondProfitData pond) {
    // Estimate other operational costs (labor, electricity, etc.)
    final biomass = pond.estimatedBiomass ?? 0;
    return biomass * 10.0; // ₹10 per kg for other costs
  }

  static double _calculateFeedOptimizationBenefit(
      List<PondProfitData> pondData) {
    double totalBenefit = 0;

    for (final pond in pondData) {
      if (pond.currentFcr != null && pond.expectedFcr != null) {
        final fcrGap = pond.currentFcr! - pond.expectedFcr!;
        if (fcrGap > 0.2) {
          final feedReduction = _calculateOptimalFeedReduction(pond, fcrGap);
          totalBenefit += feedReduction * FEED_COST_PER_KG;
        }
      }
    }

    return totalBenefit;
  }

  static double _calculateHarvestOptimizationBenefit(
      List<PondProfitData> pondData, MarketConditions market) {
    double totalBenefit = 0;

    for (final pond in pondData) {
      if (pond.currentAbw != null) {
        final daysToOptimal = _calculateDaysToOptimalHarvest(
            pond, FarmProfile.createDefault('', ''));
        if (daysToOptimal <= 30) {
          final revenueNow = (pond.estimatedBiomass ?? 0) * market.currentPrice;
          final revenueOptimal =
              _calculateRevenueAtOptimalHarvest(pond, market, daysToOptimal);
          totalBenefit += revenueOptimal - revenueNow;
        }
      }
    }

    return totalBenefit;
  }

  static int _calculateDaysToTargetSize(
      PondProfitData pond, double targetSize, FarmProfile farmProfile) {
    if (pond.currentAbw == null) return 999;

    final growthRate = _getFarmSpecificGrowthRate(farmProfile, pond.doc);
    if (growthRate <= 0) return 999;

    return ((targetSize - pond.currentAbw!) / growthRate).ceil();
  }

  static double _calculateSizePremium(
      PondProfitData pond, MarketConditions market) {
    // Calculate additional revenue from growing to larger size
    final currentBiomass = pond.estimatedBiomass ?? 0;
    const sizePremiumRate = 0.05; // 5% premium for 20g vs 15-18g
    return currentBiomass * market.currentPrice * sizePremiumRate;
  }

  // Confidence calculation methods
  static double _calculateFeedConfidence(List<PondProfitData> pondData) {
    final validPonds =
        pondData.where((p) => p.currentFcr != null && p.expectedFcr != null);
    if (validPonds.isEmpty) return 0.3;

    final avgConfidence =
        validPonds.fold<double>(0, (sum, p) => sum + p.dataConfidence) /
            validPonds.length;
    return avgConfidence;
  }

  static double _calculateHarvestConfidence(List<PondProfitData> pondData) {
    final validPonds = pondData.where((p) => p.currentAbw != null);
    if (validPonds.isEmpty) return 0.3;

    final avgConfidence =
        validPonds.fold<double>(0, (sum, p) => sum + p.dataConfidence) /
            validPonds.length;
    return avgConfidence * 0.9; // Slightly lower confidence for predictions
  }

  static double _calculateCostBenefitConfidence(List<PondProfitData> pondData) {
    return _calculateFeedConfidence(pondData) *
        0.8; // More complex analysis = lower confidence
  }

  static double _calculateRevenueConfidence(
      List<PondProfitData> pondData, MarketConditions market) {
    final baseConfidence = _calculateHarvestConfidence(pondData);
    final marketConfidence = market.priceVolatility < 0.1 ? 0.9 : 0.7;
    return baseConfidence * marketConfidence;
  }

  static double _calculateOverallConfidence(
      Map<ProfitDecisionType, ProfitRecommendation> decisions) {
    if (decisions.isEmpty) return 0.5;

    final totalConfidence =
        decisions.values.fold<double>(0, (sum, d) => sum + d.confidence);
    return totalConfidence / decisions.length;
  }
}

class ProfitDecision {
  final FarmProfile farmProfile;
  final Map<ProfitDecisionType, ProfitRecommendation> decisions;
  final DateTime generatedAt;
  final double overallConfidence;

  const ProfitDecision({
    required this.farmProfile,
    required this.decisions,
    required this.generatedAt,
    required this.overallConfidence,
  });

  /// Get the most urgent decision
  ProfitRecommendation? get mostUrgentDecision {
    final urgentDecisions =
        decisions.values.where((d) => d.priority == DecisionPriority.urgent);
    if (urgentDecisions.isNotEmpty) {
      return urgentDecisions
          .reduce((a, b) => a.potentialSavings > b.potentialSavings ? a : b);
    }

    final highDecisions =
        decisions.values.where((d) => d.priority == DecisionPriority.high);
    if (highDecisions.isNotEmpty) {
      return highDecisions
          .reduce((a, b) => a.potentialSavings > b.potentialSavings ? a : b);
    }

    return null;
  }

  /// Get total potential savings across all decisions
  double get totalPotentialSavings {
    return decisions.values
        .fold<double>(0, (sum, d) => sum + d.potentialSavings);
  }

  /// Get implementation summary
  String get implementationSummary {
    final buffer = StringBuffer();
    buffer.writeln('Profit Decision Summary:');
    buffer.writeln(
        'Overall Confidence: ${(overallConfidence * 100).toStringAsFixed(0)}%');
    buffer.writeln(
        'Total Opportunity: ₹${(totalPotentialSavings / 1000).toStringAsFixed(1)}K');

    final urgent = mostUrgentDecision;
    if (urgent != null) {
      buffer.writeln('Most Urgent: ${urgent.title}');
      buffer.writeln('Priority: ${urgent.priority.toString().split('.').last}');
    }

    return buffer.toString();
  }

  /// Create a copy with updated values
  ProfitDecision copyWith({
    FarmProfile? farmProfile,
    Map<ProfitDecisionType, ProfitRecommendation>? decisions,
    DateTime? generatedAt,
    double? overallConfidence,
  }) {
    return ProfitDecision(
      farmProfile: farmProfile ?? this.farmProfile,
      decisions: decisions ?? this.decisions,
      generatedAt: generatedAt ?? this.generatedAt,
      overallConfidence: overallConfidence ?? this.overallConfidence,
    );
  }
}

class ProfitRecommendation {
  final ProfitDecisionType type;
  final String title;
  final String description;
  final double potentialSavings;
  final double confidence;
  final DecisionPriority priority;
  final List<String> actionItems;
  final Map<String, dynamic> analysis;
  final double implementationCost;
  final Duration timeToImplement;

  const ProfitRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.potentialSavings,
    required this.confidence,
    required this.priority,
    required this.actionItems,
    required this.analysis,
    required this.implementationCost,
    required this.timeToImplement,
  });

  /// Get net benefit (savings minus implementation cost)
  double get netBenefit => potentialSavings - implementationCost;

  /// Get ROI percentage
  double get roi => implementationCost > 0
      ? (potentialSavings / implementationCost) * 100
      : 0;

  /// Get confidence level text
  String get confidenceText {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.7) return 'High';
    if (confidence >= 0.5) return 'Medium';
    if (confidence >= 0.3) return 'Low';
    return 'Very Low';
  }
}

enum ProfitDecisionType {
  feedOptimization,
  harvestTiming,
  costBenefit,
  revenueOptimization,
}

enum DecisionPriority {
  urgent,
  high,
  medium,
  low,
}

class PondProfitData {
  final String pondId;
  final String pondName;
  final int doc;
  final double? currentAbw;
  final double? currentFcr;
  final double? expectedFcr;
  final double? todayFeed;
  final double? estimatedBiomass;
  final double dataConfidence;

  const PondProfitData({
    required this.pondId,
    required this.pondName,
    required this.doc,
    this.currentAbw,
    this.currentFcr,
    this.expectedFcr,
    this.todayFeed,
    this.estimatedBiomass,
    required this.dataConfidence,
  });
}

class MarketConditions {
  final double currentPrice;
  final double forecastPrice;
  final PriceTrend priceTrend;
  final double priceVolatility;
  final double demandIndex;

  const MarketConditions({
    required this.currentPrice,
    required this.forecastPrice,
    required this.priceTrend,
    required this.priceVolatility,
    required this.demandIndex,
  });

  factory MarketConditions.current() {
    return const MarketConditions(
      currentPrice: 300.0,
      forecastPrice: 315.0,
      priceTrend: PriceTrend.stable,
      priceVolatility: 0.05,
      demandIndex: 0.8,
    );
  }
}

enum PriceTrend {
  increasing,
  stable,
  decreasing,
}
