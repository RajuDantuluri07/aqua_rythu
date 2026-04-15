import '../../../models/feed_result.dart';
import 'models/smart_feed_output.dart';

/// SmartFeedDecisionEngine
/// 
/// Encapsulates ALL decision intelligence for feed recommendations.
/// This is the SOURCE OF TRUTH for:
/// - Explanation generation
/// - Confidence scoring
/// - Recommendation generation
/// 
/// Philosophy: Engine decides everything, UI only renders
class SmartFeedDecisionEngine {
  /// Generate explanation for feed recommendation
  /// 
  /// Takes decision factors and builds human-readable explanation
  /// Explains WHY the recommendation was made
  static String buildExplanation({
    required FeedSource source,
    required double docFeed,
    required double finalFeed,
    double? fcrFactor,
    double? trayFactor,
    double? growthFactor,
    bool hasRecentSampling = false,
  }) {
    final parts = <String>[];

    // 1. Source explanation
    if (source == FeedSource.biomass) {
      parts.add("• Biomass data detected from recent sampling");
    } else {
      parts.add("• Using standard DOC-based calculation");
    }

    // 2. FCR explanation
    if (fcrFactor != null) {
      if (fcrFactor < 0.95) {
        final fcrValue = (1.0 / fcrFactor).toStringAsFixed(2);
        parts.add("• FCR = $fcrValue → Overfeeding risk detected");
      } else if (fcrFactor > 1.05) {
        final fcrValue = (1.0 / fcrFactor).toStringAsFixed(2);
        parts.add("• FCR = $fcrValue → Slight underfeeding");
      }
    }

    // 3. Feed adjustment explanation
    final feedDiff = finalFeed - docFeed;
    if (feedDiff.abs() > 0.1) {
      final adjustmentPct = ((feedDiff / docFeed) * 100).toStringAsFixed(0);
      if (feedDiff < 0) {
        parts.add("• Feed reduced by $adjustmentPct% for safety");
      } else {
        parts.add("• Feed increased by $adjustmentPct% for growth");
      }
    } else {
      parts.add("• Feed maintained at recommended level");
    }

    // 4. Tray explanation
    if (trayFactor != null) {
      if (trayFactor > 1.1) {
        parts.add("• Tray shows significant leftover → continue monitoring");
      } else if (trayFactor < 0.9) {
        parts.add("• Low tray leftover → ensure adequate feeding");
      }
    }

    // 5. Growth explanation
    if (growthFactor != null) {
      if (growthFactor > 1.05) {
        parts.add("• Growth trending UP → positive sign");
      } else if (growthFactor < 0.95) {
        parts.add("• Growth slower than expected → increase monitoring");
      }
    }

    return parts.join("\n");
  }

  /// Calculate real confidence score based on data availability
  /// 
  /// Confidence reflects:
  /// - Quality of input data
  /// - Recency of sampling
  /// - Number of active factors
  /// - Data consistency
  /// 
  /// Score interpretation:
  /// 0.9+ = Very confident (comprehensive data)
  /// 0.8+ = Confident (good data coverage)
  /// 0.7+ = Moderate-to-good (acceptable data)
  /// 0.6+ = Moderate (some uncertainty)
  /// < 0.6 = Low confidence (limited data)
  static double calculateConfidenceScore({
    required bool hasRecentSampling,
    int? samplingAgeDays,
    required bool hasFcrData,
    required bool hasTrayData,
    required bool hasGrowthData,
    required int doc,
  }) {
    double score = 0.50; // Base confidence

    // ── SAMPLING DATA QUALITY (0.0 - 0.30 points) ────────────────────────────

    if (hasRecentSampling) score += 0.15;

    if (samplingAgeDays != null) {
      if (samplingAgeDays <= 3) {
        score += 0.15; // Fresh data
      } else if (samplingAgeDays <= 7) {
        score += 0.10; // Recent
      } else if (samplingAgeDays <= 14) {
        score += 0.05; // Acceptable
      }
      // > 14 days: no bonus
    }

    // ── FACTOR AVAILABILITY (0.0 - 0.20 points) ─────────────────────────────

    int activeFactors = 0;
    if (hasFcrData) {
      score += 0.07;
      activeFactors++;
    }
    if (hasTrayData) {
      score += 0.07;
      activeFactors++;
    }
    if (hasGrowthData) {
      score += 0.06;
      activeFactors++;
    }

    // ── FEED PHASE ADJUSTMENT (0.0 - 0.10 points) ──────────────────────────

    // Smart phase (DOC > 30) gets different weight than early phases
    if (doc > 30) {
      // In smart phase, more data = higher baseline
      score += 0.05;
    } else if (doc > 15) {
      // Tray habit phase
      score += 0.02;
    }

    // ── CONSISTENCY BONUS (0.0 - 0.10 points) ──────────────────────────────

    // If multiple factors align, increase confidence
    if (activeFactors >= 3) {
      score += 0.05; // All factors agreeing
    }

    // ── CLAMP SCORE ────────────────────────────────────────────────────────

    return score.clamp(0.0, 1.0);
  }

  /// Generate actionable recommendations for the farmer
  /// 
  /// Recommendations are specific, time-bound, and actionable
  /// Examples:
  /// - "Reduce feed slightly for next 2 days"
  /// - "Monitor tray carefully after next feeding"
  /// - "Take fresh sampling measurement today"
  static List<String> generateRecommendations({
    double? fcrFactor,
    double? trayFactor,
    double? growthFactor,
    int? samplingAgeDays,
    double confidenceScore,
    FeedSource source,
  }) {
    final recs = <String>[];

    // ── FCR-BASED RECOMMENDATIONS ──────────────────────────────────────────

    if (fcrFactor != null) {
      if (fcrFactor < 0.90) {
        recs.add("⚠️ Reduce feed by 5-10% for next 3 days");
      } else if (fcrFactor < 0.95) {
        recs.add("→ Slightly reduce feed for next 2 days");
      } else if (fcrFactor > 1.10) {
        recs.add("→ Consider increasing feed gradually");
      }
    }

    // ── TRAY-BASED RECOMMENDATIONS ──────────────────────────────────────────

    if (trayFactor != null) {
      if (trayFactor > 1.20) {
        recs.add("✓ Tray looks good - continue current feeding");
      } else if (trayFactor > 1.05) {
        recs.add("→ Monitor tray closely for overflow");
      } else if (trayFactor < 0.80) {
        recs.add("⚠️ Low tray consumption - check for diseases");
      }
    }

    // ── GROWTH-BASED RECOMMENDATIONS ───────────────────────────────────────

    if (growthFactor != null) {
      if (growthFactor > 1.05) {
        recs.add("✓ Growth tracking well - maintain current feeding");
      } else if (growthFactor < 0.95) {
        recs.add("⚠️ Growth slower than expected - increase feed carefully");
      }
    }

    // ── SAMPLING-BASED RECOMMENDATIONS ────────────────────────────────────

    if (samplingAgeDays != null) {
      if (samplingAgeDays > 10) {
        recs.add("📊 Sampling overdue - measure ABW today");
      } else if (samplingAgeDays > 7) {
        recs.add("📊 Plan sampling measurement within 2 days");
      }
    } else if (source == FeedSource.doc) {
      recs.add("📊 Take fresh ABW sampling to enable biomass-based recommendations");
    }

    // ── CONFIDENCE-BASED RECOMMENDATIONS ───────────────────────────────────

    if (confidenceScore < 0.6) {
      recs.add("⚠️ Limited data - verify recommendation with manual observation");
    }

    // ── ENSURE MINIMUM RECOMMENDATIONS ────────────────────────────────────

    if (recs.isEmpty) {
      recs.add("✓ Recommendation looks good - proceed with confidence");
    }

    return recs;
  }

  /// Determine feed source based on available data
  static FeedSource determineFeedSource({
    required double? abw,
    required int? samplingAgeDays,
  }) {
    // Use biomass if we have recent ABW measurement
    if (abw != null) {
      // Consider it "recent" if less than 14 days
      if (samplingAgeDays == null || samplingAgeDays <= 14) {
        return FeedSource.biomass;
      }
    }
    return FeedSource.doc;
  }

  /// Build complete SmartFeedOutput from calculation results
  /// 
  /// This is the main integration point for engines to produce
  /// intelligent output
  static SmartFeedOutput buildSmartFeedOutput({
    required double finalFeed,
    required double docFeed,
    double? biomassFeed,
    double? abw,
    required int doc,
    double? fcrFactor,
    double? trayFactor,
    double? growthFactor,
    int? samplingAgeDays,
  }) {
    // Determine source
    final source = determineFeedSource(
      abw: abw,
      samplingAgeDays: samplingAgeDays,
    );

    // Build explanation
    final explanation = buildExplanation(
      source: source,
      docFeed: docFeed,
      finalFeed: finalFeed,
      fcrFactor: fcrFactor,
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      hasRecentSampling: samplingAgeDays != null && samplingAgeDays <= 7,
    );

    // Calculate confidence
    final confidence = calculateConfidenceScore(
      hasRecentSampling: abw != null,
      samplingAgeDays: samplingAgeDays,
      hasFcrData: fcrFactor != null,
      hasTrayData: trayFactor != null,
      hasGrowthData: growthFactor != null,
      doc: doc,
    );

    // Generate recommendations
    final recommendations = generateRecommendations(
      fcrFactor: fcrFactor,
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      samplingAgeDays: samplingAgeDays,
      confidenceScore: confidence,
      source: source,
    );

    return SmartFeedOutput(
      finalFeed: finalFeed,
      source: source,
      docFeed: docFeed,
      biomassFeed: biomassFeed,
      fcrFactor: fcrFactor,
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      samplingAgeDays: samplingAgeDays,
      explanation: explanation,
      confidenceScore: confidence,
      recommendations: recommendations,
      engineVersion: "v2.1",
    );
  }
}
