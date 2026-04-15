import '../../../models/feed_result.dart';
import 'models/feed_input.dart';
import 'models/smart_feed_output.dart';

/// SmartFeedDecisionEngine v2.3
///
/// Single source of truth for ALL feed decision logic:
/// - Feed source resolution
/// - DOC and biomass feed calculation
/// - FCR correction
/// - Explanation generation
/// - Confidence scoring
/// - Recommendation generation
/// - Decision trace (full audit trail)
///
/// Philosophy: Engine owns everything, UI only renders
class SmartFeedDecisionEngine {
  // ── MAIN ENTRY POINT ────────────────────────────────────────────────────────

  /// Run the full decision engine from raw input.
  ///
  /// This is the V2.3 single-source entry point. It:
  ///   1. Validates biomass data (including growth sanity)
  ///   2. Resolves feed source (DOC vs Biomass)
  ///   3. Calculates DOC feed
  ///   4. Calculates biomass feed (if applicable)
  ///   5. Selects the base feed
  ///   6. Applies FCR correction
  ///   7. Applies stage-based safety cap (overfeeding protection)
  ///   8. Applies minimum feed floor (underfeeding protection)
  ///   9. Builds decision trace, explanation, confidence, recommendations
  static SmartFeedOutput run(FeedInput input) {
    final trace = <String>[];

    // Step 1: Validate biomass data
    trace.add("DOC = ${input.doc}");

    final int? effectiveSamplingAge =
        input.sampleAgeDays > 0 ? input.sampleAgeDays : null;

    final bool growthOk =
        input.abw == null || isGrowthValid(input.abw!, input.doc);

    final bool validBiomass = isValidBiomass(
      abw: input.abw,
      count: input.seedCount,
      samplingAgeDays: effectiveSamplingAge,
      doc: input.doc,
    );

    if (!validBiomass && input.abw != null) {
      if (!growthOk) {
        trace.add("Biomass rejected → unrealistic growth for DOC");
      } else {
        trace.add("Biomass rejected → invalid or stale sampling");
      }
    }

    // Step 2: Resolve Feed Source
    final source = resolveFeedSource(
      doc: input.doc,
      abw: input.abw,
      count: input.seedCount,
      samplingAgeDays: effectiveSamplingAge,
    );

    if (source == FeedSource.biomass) {
      trace.add("Using biomass (ABW: ${input.abw}g)");
    } else {
      trace.add("Using DOC-based feeding");
    }

    // Step 3: Calculate DOC Feed
    final docFeed = _calculateDocFeed(
      doc: input.doc,
      seedCount: input.seedCount,
      stockingType: input.stockingType,
    );
    trace.add("DOC Feed = ${docFeed.toStringAsFixed(2)}");

    // Step 4: Calculate Biomass Feed
    double? biomassFeed;
    if (source == FeedSource.biomass) {
      biomassFeed = _calculateBiomassFeed(
        abw: input.abw!,
        seedCount: input.seedCount,
        survival: 0.9,
        feedPercent: 0.03,
      );
      trace.add("Biomass Feed = ${biomassFeed.toStringAsFixed(2)}");
    }

    // Step 5: Select Base Feed
    final double baseFeed =
        source == FeedSource.doc ? docFeed : biomassFeed!;

    // Step 6: Apply FCR Correction
    double finalFeed = baseFeed;
    if (input.lastFcr != null) {
      finalFeed = _applyFcrCorrection(
        feed: baseFeed,
        fcr: input.lastFcr!,
        fcrAgeDays: effectiveSamplingAge,
      );
      trace.add("FCR applied → ${input.lastFcr}");
    }

    // Step 7: Apply Stage-Based Safety Cap (overfeeding protection)
    final maxFeed = getMaxFeed(input.doc, input.seedCount);
    if (finalFeed > maxFeed) {
      trace.add(
          "Safety cap applied → limiting feed to ${maxFeed.toStringAsFixed(2)} kg");
      finalFeed = maxFeed;
    }

    // Step 8: Apply Minimum Feed Floor (underfeeding protection)
    final minFeed = getMinFeed(input.doc, input.seedCount);
    if (finalFeed < minFeed) {
      trace.add(
          "Minimum feed applied → raising to ${minFeed.toStringAsFixed(2)} kg");
      finalFeed = minFeed;
    }

    trace.add("Final Feed = ${finalFeed.toStringAsFixed(2)}");

    // Build explanation
    final explanation = buildExplanation(
      source: source,
      docFeed: docFeed,
      finalFeed: finalFeed,
      hasRecentSampling:
          effectiveSamplingAge != null && effectiveSamplingAge <= 7,
    );

    // Calculate confidence
    final confidence = calculateConfidence(
      hasSampling: input.abw != null && validBiomass,
      samplingAgeDays: effectiveSamplingAge,
      hasFcr: input.lastFcr != null,
      hasTray: input.trayStatuses.isNotEmpty,
    );

    // Generate recommendations
    final recommendations = generateRecommendations(
      fcrFactor: input.lastFcr != null ? _getFcrFactor(input.lastFcr!) : null,
      trayFactor: null,
      growthFactor: null,
      samplingAgeDays: effectiveSamplingAge,
      confidenceScore: confidence,
      source: source,
      biomassRejected: !validBiomass && input.abw != null,
    );

    return SmartFeedOutput(
      finalFeed: finalFeed,
      source: source,
      docFeed: docFeed,
      biomassFeed: biomassFeed,
      samplingAgeDays: effectiveSamplingAge,
      explanation: explanation,
      confidenceScore: confidence,
      recommendations: recommendations,
      decisionTrace: trace,
      engineVersion: "v2.3",
    );
  }

  // ── BIOMASS VALIDATION ──────────────────────────────────────────────────────

  /// Validate whether ABW is physiologically plausible for a given DOC.
  ///
  /// Shrimp at DOC d should weigh roughly 0.2d – 0.5d grams.
  /// Values outside this window indicate a data-entry error or sample mix-up.
  static bool isGrowthValid(double abw, int doc) {
    final minExpected = doc * 0.2;
    final maxExpected = doc * 0.5;
    return abw >= minExpected && abw <= maxExpected;
  }

  /// Validate whether biomass data is usable for feed calculation.
  ///
  /// Rejects stale, missing, physiologically unrealistic, or growth-invalid
  /// values. Pass [doc] to also apply the growth sanity check.
  static bool isValidBiomass({
    required double? abw,
    required int? count,
    required int? samplingAgeDays,
    int? doc,
  }) {
    if (abw == null || count == null) return false;
    if (abw <= 0 || count <= 0) return false;

    // Reject unrealistic ABW values
    if (abw < 0.5 || abw > 50) return false;

    // Reject stale or missing sampling age
    if (samplingAgeDays == null || samplingAgeDays > 10) return false;

    // Reject physiologically implausible growth (requires doc)
    if (doc != null && !isGrowthValid(abw, doc)) return false;

    return true;
  }

  // ── STAGE-BASED FEED BOUNDS ─────────────────────────────────────────────────

  /// Maximum feed (kg) for the current culture stage, scaled by density.
  ///
  /// Replaces the old static safety cap with a DOC-aware upper bound:
  /// - DOC ≤ 30 (early stage): 10 kg per lakh
  /// - DOC ≤ 60 (mid stage):   25 kg per lakh
  /// - DOC  > 60 (late stage):  40 kg per lakh
  static double getMaxFeed(int doc, int density) {
    final double baseCap;
    if (doc <= 30) {
      baseCap = 10;
    } else if (doc <= 60) {
      baseCap = 25;
    } else {
      baseCap = 40;
    }
    return baseCap * (density / 100000);
  }

  /// Minimum feed (kg) for the current culture stage, scaled by density.
  ///
  /// Ensures the engine never recommends dangerously low feed that would
  /// starve the shrimp. Formula: doc × 0.05 kg per lakh.
  static double getMinFeed(int doc, int density) {
    final baseMin = doc * 0.05;
    return baseMin * (density / 100000);
  }

  // ── FEED SOURCE RESOLUTION ──────────────────────────────────────────────────

  /// Resolve whether to use DOC-based or biomass-based feeding.
  ///
  /// When [samplingAgeDays] is provided the full [isValidBiomass] check is
  /// applied (rejects stale / unrealistic data). When omitted the legacy
  /// check (abw > 0 && count > 0) is used for backward compatibility.
  static FeedSource resolveFeedSource({
    required int doc,
    required double? abw,
    required int count,
    int? samplingAgeDays,
  }) {
    if (samplingAgeDays != null) {
      if (isValidBiomass(
          abw: abw, count: count, samplingAgeDays: samplingAgeDays, doc: doc)) {
        return FeedSource.biomass;
      }
      return FeedSource.doc;
    }

    // Legacy path: used by callers that do not supply samplingAgeDays
    if (abw != null && abw > 0 && count > 0) {
      return FeedSource.biomass;
    }
    return FeedSource.doc;
  }

  // ── INTERNAL CALCULATIONS ───────────────────────────────────────────────────

  /// DOC-based feed ramp (kg), scaled by stocking density.
  static double _calculateDocFeed({
    required int doc,
    required int seedCount,
    required String stockingType,
  }) {
    final double baseFeed = stockingType == 'hatchery'
        ? 2.0 + (doc - 1) * 0.15
        : 4.0 + (doc - 1) * 0.25;
    return baseFeed * (seedCount / 100000);
  }

  /// Biomass-based feed (kg) = feedPercent % of total live biomass.
  static double _calculateBiomassFeed({
    required double abw,
    required int seedCount,
    required double survival,
    required double feedPercent,
  }) {
    final double biomassKg = (abw * seedCount * survival) / 1000;
    return biomassKg * feedPercent;
  }

  /// Apply FCR correction factor to a base feed value.
  static double _applyFcrCorrection({
    required double feed,
    required double fcr,
    required int? fcrAgeDays,
  }) {
    if (fcrAgeDays != null && fcrAgeDays > 10) return feed;
    return feed * _getFcrFactor(fcr);
  }

  /// Map FCR value to an adjustment factor.
  static double _getFcrFactor(double fcr) {
    if (fcr <= 1.0) return 1.15;
    if (fcr <= 1.2) return 1.10;
    if (fcr <= 1.3) return 1.05;
    if (fcr <= 1.4) return 1.00;
    if (fcr <= 1.5) return 0.90;
    return 0.85;
  }

  // ── LEGACY: Kept for backward-compat with buildSmartFeedOutput callers ──────
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
      if (trayFactor >= 1.1) {
        parts.add("• Tray shows significant leftover → continue monitoring");
      } else if (trayFactor < 0.9) {
        parts.add("• Low tray leftover → ensure adequate feeding");
      }
    }

    // 5. Growth explanation
    if (growthFactor != null) {
      if (growthFactor >= 1.05) {
        parts.add("• Growth trending UP → positive sign");
      } else if (growthFactor < 0.95) {
        parts.add("• Growth slower than expected → increase monitoring");
      }
    }

    return parts.join("\n");
  }

  /// Confidence model used by [run] — V2.3.
  ///
  /// Scores reflect real data quality and freshness:
  /// - 0.4  base (DOC-only, no factors)
  /// - +0.3 fresh sampling (≤ 5 days)
  /// - +0.15 acceptable sampling (6–10 days)
  /// - +0.15 FCR data present
  /// - +0.15 tray data present
  ///
  /// Max achievable: 1.0 (clamped)
  static double calculateConfidence({
    required bool hasSampling,
    required int? samplingAgeDays,
    required bool hasFcr,
    required bool hasTray,
  }) {
    double score = 0.4;

    if (hasSampling) {
      if (samplingAgeDays != null && samplingAgeDays <= 5) {
        score += 0.3;
      } else if (samplingAgeDays != null && samplingAgeDays <= 10) {
        score += 0.15;
      }
    }

    if (hasFcr) score += 0.15;
    if (hasTray) score += 0.15;

    return score.clamp(0.0, 1.0);
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
    required double confidenceScore,
    required FeedSource source,
    bool biomassRejected = false,
  }) {
    final recs = <String>[];

    // ── FCR-BASED RECOMMENDATIONS ──────────────────────────────────────────

    if (fcrFactor != null) {
      if (fcrFactor < 0.90) {
        recs.add("⚠️ Reduce feed for next 2 days and monitor tray");
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

    if (biomassRejected) {
      recs.add("📊 Re-sample shrimp immediately (data outdated)");
    } else if (samplingAgeDays != null) {
      if (samplingAgeDays > 10) {
        recs.add("📊 Sampling overdue - measure ABW today");
      } else if (samplingAgeDays > 7) {
        recs.add("📊 Schedule sampling within 2 days");
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

  /// Determine feed source based on available data (legacy helper).
  static FeedSource determineFeedSource({
    required double? abw,
    required int? samplingAgeDays,
  }) {
    if (abw != null) {
      if (samplingAgeDays == null || samplingAgeDays <= 14) {
        return FeedSource.biomass;
      }
    }
    return FeedSource.doc;
  }

  /// Build complete SmartFeedOutput from pre-computed results.
  ///
  /// Prefer [run] for new call sites — this method exists for callers that
  /// already computed docFeed / biomassFeed externally.
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
    List<String> decisionTrace = const [],
  }) {
    final source = determineFeedSource(
      abw: abw,
      samplingAgeDays: samplingAgeDays,
    );

    final explanation = buildExplanation(
      source: source,
      docFeed: docFeed,
      finalFeed: finalFeed,
      fcrFactor: fcrFactor,
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      hasRecentSampling: samplingAgeDays != null && samplingAgeDays <= 7,
    );

    final confidence = calculateConfidenceScore(
      hasRecentSampling: abw != null,
      samplingAgeDays: samplingAgeDays,
      hasFcrData: fcrFactor != null,
      hasTrayData: trayFactor != null,
      hasGrowthData: growthFactor != null,
      doc: doc,
    );

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
      decisionTrace: decisionTrace,
      engineVersion: "v2.1",
    );
  }
}
