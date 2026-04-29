// Feed Models - Enhanced models for baseline+ROI feed engine
//
// These models support the new baseline calculation, ROI tracking,
// confidence assessment, and explainable feed decisions.
//

// ── FEED STATUS ENUM ──────────────────────────────────────────────────────

enum FeedStatus { onTrack, overfeeding, underfeeding }

// ── CONFIDENCE LEVEL ENUM ────────────────────────────────────────────────

enum ConfidenceLevel { high, medium, low }

// ── CORE RESULT MODELS ───────────────────────────────────────────────────

/// Intelligence result for expected vs actual feed analysis
class IntelligenceResult {
  final double expectedFeed;
  final FeedStatus status;

  const IntelligenceResult({
    required this.expectedFeed,
    required this.status,
  });
}

/// Feed decision with action and reasoning
class FeedDecision {
  final String action;
  final double deltaKg;
  final String reason;
  final List<String> recommendations;
  final List<String> decisionTrace;
  final String confidence;
  final String confidenceReason;

  const FeedDecision({
    required this.action,
    required this.deltaKg,
    required this.reason,
    required this.recommendations,
    required this.decisionTrace,
    this.confidence = 'Normal',
    this.confidenceReason = 'Normal feeding confidence',
  });
}

/// Feed recommendation with timing and amounts
class FeedRecommendation {
  final double nextFeedKg;
  final DateTime nextFeedTime;
  final String instruction;

  FeedRecommendation({
    required this.nextFeedKg,
    required this.nextFeedTime,
    required this.instruction,
  });
}

// ── BASELINE+ROI MODELS ───────────────────────────────────────────────────

/// Baseline feed calculation result
class BaselineResult {
  final double baselineFeed;
  final double abw;
  final double biomass;
  final double feedRate;
  final bool isValid;
  final String? errorMessage;

  const BaselineResult({
    required this.baselineFeed,
    required this.abw,
    required this.biomass,
    required this.feedRate,
    required this.isValid,
    this.errorMessage,
  });
}

/// Smart feed adjustment result
class SmartAdjustmentResult {
  final double adjustedFeed;
  final double trayFactor;
  final double growthFactor;
  final double fcrFactor;
  final double waterQualityFactor;
  final bool wasClamped;
  final String? clampReason;

  const SmartAdjustmentResult({
    required this.adjustedFeed,
    required this.trayFactor,
    required this.growthFactor,
    required this.fcrFactor,
    required this.waterQualityFactor,
    required this.wasClamped,
    this.clampReason,
  });
}

/// ROI calculation result
class RoiResult {
  final double dailySavings;
  final double cumulativeSavings;
  final double feedEfficiency;
  final double costSavingsPercentage;
  final double roiPercentage;
  final double averageDailySavings;

  const RoiResult({
    required this.dailySavings,
    required this.cumulativeSavings,
    required this.feedEfficiency,
    required this.costSavingsPercentage,
    required this.roiPercentage,
    required this.averageDailySavings,
  });
}

/// Confidence assessment result
class ConfidenceResult {
  final ConfidenceLevel level;
  final int score;
  final bool hasTrayData;
  final bool hasSampling;
  final bool hasWaterQuality;
  final int dataRecencyHours;
  final double trayConsistency;
  final String explanation;

  const ConfidenceResult({
    required this.level,
    required this.score,
    required this.hasTrayData,
    required this.hasSampling,
    required this.hasWaterQuality,
    required this.dataRecencyHours,
    required this.trayConsistency,
    required this.explanation,
  });
}

/// Feed decision explanation
class FeedReason {
  final String primaryReason;
  final String detailedReason;
  final List<String> factors;
  final String adjustmentSummary;
  final String confidenceContext;

  const FeedReason({
    required this.primaryReason,
    required this.detailedReason,
    required this.factors,
    required this.adjustmentSummary,
    required this.confidenceContext,
  });
}

// ── COMPOSITE RESULT MODELS ─────────────────────────────────────────────

/// Complete feed calculation result (baseline+ROI)
class FeedCalculationResult {
  final String pondId;
  final int doc;
  final BaselineResult baseline;
  final SmartAdjustmentResult adjustment;
  final RoiResult roi;
  final ConfidenceResult confidence;
  final FeedReason reason;
  final DateTime timestamp;
  final bool isError;
  final String? error;

  const FeedCalculationResult({
    required this.pondId,
    required this.doc,
    required this.baseline,
    required this.adjustment,
    required this.roi,
    required this.confidence,
    required this.reason,
    required this.timestamp,
    this.error,
  }) : isError = error != null;

  FeedCalculationResult.error({
    required this.pondId,
    required this.doc,
    required this.error,
  })  : baseline = const BaselineResult(
          baselineFeed: 0.0,
          abw: 0.0,
          biomass: 0.0,
          feedRate: 0.0,
          isValid: false,
        ),
        adjustment = const SmartAdjustmentResult(
          adjustedFeed: 0.0,
          trayFactor: 1.0,
          growthFactor: 1.0,
          fcrFactor: 1.0,
          waterQualityFactor: 1.0,
          wasClamped: false,
        ),
        roi = const RoiResult(
          dailySavings: 0.0,
          cumulativeSavings: 0.0,
          feedEfficiency: 0.0,
          costSavingsPercentage: 0.0,
          roiPercentage: 0.0,
          averageDailySavings: 0.0,
        ),
        confidence = const ConfidenceResult(
          level: ConfidenceLevel.low,
          score: 0,
          hasTrayData: false,
          hasSampling: false,
          hasWaterQuality: false,
          dataRecencyHours: 0,
          trayConsistency: 0.0,
          explanation: 'Error occurred during calculation',
        ),
        reason = const FeedReason(
          primaryReason: 'Calculation Error',
          detailedReason: 'An error occurred during feed calculation',
          factors: [],
          adjustmentSummary: '',
          confidenceContext: 'Low confidence due to error',
        ),
        timestamp = DateTime.now(),
        isError = true;

  /// Convert to JSON for API responses (matches UI contract)
  Map<String, dynamic> toJson() {
    if (isError) {
      return {
        'error': error,
        'pondId': pondId,
        'doc': doc,
      };
    }

    return {
      'baseline_feed': baseline.baselineFeed,
      'actual_feed': adjustment.adjustedFeed,
      'daily_savings': roi.dailySavings,
      'total_savings': roi.cumulativeSavings,
      'confidence': level.toString(),
      'reason': reason.primaryReason,
      'abw': baseline.abw,
      'biomass': baseline.biomass,
      'feed_rate': baseline.feedRate,
      'feed_efficiency': roi.feedEfficiency,
      'cost_savings_percentage': roi.costSavingsPercentage,
      'roi_percentage': roi.roiPercentage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Get confidence level name
  String get level => confidence.level.name;
}

// ── LEGACY COMPATIBILITY MODELS ─────────────────────────────────────────

/// Legacy orchestrator result (for backward compatibility)
class LegacyOrchestratorResult {
  final double baseFeed;
  final double finalFeed;
  final String feedStage;
  final IntelligenceResult intelligence;
  final SmartAdjustmentResult correction;
  final FeedDecision decision;
  final FeedRecommendation recommendation;
  final String engineVersion;

  const LegacyOrchestratorResult({
    required this.baseFeed,
    required this.finalFeed,
    required this.feedStage,
    required this.intelligence,
    required this.correction,
    required this.decision,
    required this.recommendation,
    required this.engineVersion,
  });
}
