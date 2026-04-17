/// Smart Feed Engine V2 - Hybrid Intelligent Feeding System
///
/// This engine powers the core intelligence of Aqua Rythu:
/// - Evolves from DOC-based → Biomass-based → FCR-optimized
/// - Uses sampling data when available
/// - Applies efficiency corrections
/// - Returns fully debuggable results
///
/// BUSINESS LOGIC:
/// Stage 1 (DOC 1-30):   Blind feeding (no sampling expected)
/// Stage 2 (DOC > 30):   Smart feeding (sampling drives decisions)
/// Stage 3 (Sampling):   Biomass overrides DOC
/// Stage 4 (FCR):        Efficiency corrections applied

import 'package:flutter/foundation.dart';

/// Feed mode resolution
enum FeedMode {
  doc,      // DOC-only (early stage, no data)
  biomass,  // Biomass-based (sampling present)
  smart;    // Hybrid (DOC + biomass + FCR)

  bool get isDoc => this == FeedMode.doc;
  bool get isBiomass => this == FeedMode.biomass;
  bool get isSmart => this == FeedMode.smart;
}

/// Complete feed calculation result with full transparency
class FeedResult {
  // Core outputs
  final double finalFeed;
  final FeedMode mode;

  // Component feeds (for debugging/display)
  final double? docFeed;
  final double? biomassFeed;
  final double? fcrAdjustedFeed;

  // Factor breakdown
  final double fcrFactor;
  final double trayFactor;
  final double growthFactor;
  final double samplingAgeFactor;

  // Debug/audit trail
  final String debugTrace;
  final bool hasValidSampling;
  final bool hasValidFcr;
  final List<String> warnings;

  FeedResult({
    required this.finalFeed,
    required this.mode,
    this.docFeed,
    this.biomassFeed,
    this.fcrAdjustedFeed,
    this.fcrFactor = 1.0,
    this.trayFactor = 1.0,
    this.growthFactor = 1.0,
    this.samplingAgeFactor = 1.0,
    this.debugTrace = '',
    this.hasValidSampling = false,
    this.hasValidFcr = false,
    this.warnings = const [],
  });

  @override
  String toString() =>
      'FeedResult(mode: ${mode.name}, feed: ${finalFeed.toStringAsFixed(3)}kg, '
      'docFeed: ${docFeed?.toStringAsFixed(3)}, '
      'biomassFeed: ${biomassFeed?.toStringAsFixed(3)}, '
      'fcrAdjusted: ${fcrAdjustedFeed?.toStringAsFixed(3)})';
}

/// Main Smart Feed Engine V2
class SmartFeedEngineV2 {
  /// Enable debug logging (set in dev builds)
  static bool debugMode = !kReleaseMode;

  // ── MODE RESOLUTION ──────────────────────────────────────────────────────

  /// Determines which feed calculation to use based on DOC and data availability
  static FeedMode resolveFeedMode({
    required int doc,
    required bool hasSampling,
    required bool hasValidSampling,
  }) {
    // Sampling is the strongest signal: always override to biomass
    if (hasValidSampling) {
      if (debugMode) print('[FeedModeResolver] Sampling valid → FeedMode.biomass');
      return FeedMode.biomass;
    }

    // After DOC 30, use smart mode even without sampling
    if (doc > 30) {
      if (debugMode) print('[FeedModeResolver] DOC > 30 → FeedMode.smart');
      return FeedMode.smart;
    }

    // Default: DOC-only mode
    if (debugMode) print('[FeedModeResolver] DOC <= 30, no sampling → FeedMode.doc');
    return FeedMode.doc;
  }

  // ── DOC-BASED FEED CALCULATION ───────────────────────────────────────────

  /// Calculate feed based on Day of Culture (Blind feeding)
  /// 
  /// For early stages where no biomass data exists yet.
  /// Uses conservative DOC-based ramp.
  static double calculateDocFeed({
    required int doc,
    required int density,
    required String stockingType,
  }) {
    // Base feed ramp (kg per 100K shrimp)
    final double baseFeed;
    if (stockingType == 'hatchery') {
      baseFeed = 2.0 + (doc - 1) * 0.15;
    } else {
      baseFeed = 4.0 + (doc - 1) * 0.25;
    }

    // Density scaling
    final double scaledFeed = baseFeed * (density / 100000);

    if (debugMode) {
      print('[DOCFeed] DOC=$doc, type=$stockingType, density=$density');
      print('  baseFeed=$baseFeed (per 100K)');
      print('  scaledFeed=${scaledFeed.toStringAsFixed(3)} kg');
    }

    return scaledFeed;
  }

  // ── BIOMASS-BASED FEED CALCULATION ───────────────────────────────────────

  /// Calculate feed based on actual biomass (Smart feeding)
  /// 
  /// Uses current Average Body Weight (ABW) to determine
  /// optimal feeding rate based on actual growth.
  static double calculateBiomassFeed({
    required double abw, // grams
    required int seedCount,
    required double survival, // 0.0-1.0
    required double feedPercent, // e.g. 0.03 for 3%
  }) {
    // Total biomass in kg
    final double biomassKg = (abw * seedCount * survival) / 1000;

    // Feed = % of biomass
    final double feed = biomassKg * feedPercent;

    if (debugMode) {
      print('[BiomassFeed] ABW=$abw g, seedCount=$seedCount, survival=$survival');
      print('  biomass=${biomassKg.toStringAsFixed(3)} kg');
      print('  feedPercent=$feedPercent (${(feedPercent * 100).toStringAsFixed(1)}%)');
      print('  biomassFeed=${feed.toStringAsFixed(3)} kg');
    }

    return feed;
  }

  // ── FCR CORRECTION LAYER ─────────────────────────────────────────────────

  /// Apply Feed Conversion Ratio correction to feed recommendation
  /// 
  /// Rewards efficient farms (low FCR), penalizes wasteful farms (high FCR).
  /// Only applies if FCR is fresh (< 10 days old).
  static double applyFcrCorrection({
    required double baseFeed,
    required double? fcr,
    required int? fcrAgeDays,
  }) {
    // No FCR data
    if (fcr == null || fcrAgeDays == null) {
      if (debugMode) print('[FCRCorrection] No FCR data available');
      return baseFeed;
    }

    // FCR too old — discard
    if (fcrAgeDays > 10) {
      if (debugMode) print('[FCRCorrection] FCR too old ($fcrAgeDays days) → ignored');
      return baseFeed;
    }

    // Get FCR factor (rewards/penalties)
    final double factor = _getFcrFactor(fcr);
    final double adjusted = baseFeed * factor;

    if (debugMode) {
      print('[FCRCorrection] FCR=$fcr (age=$fcrAgeDays days)');
      print('  factor=$factor → ${(factor > 1.0 ? '+' : '')}${((factor - 1) * 100).toStringAsFixed(1)}%');
      print('  adjusted=${adjusted.toStringAsFixed(3)} kg');
    }

    return adjusted;
  }

  /// Map FCR value to adjustment factor
  static double _getFcrFactor(double fcr) {
    if (fcr <= 1.0) return 1.15;  // Exceptional: +15%
    if (fcr <= 1.2) return 1.10;  // Very good: +10%
    if (fcr <= 1.3) return 1.05;  // Good: +5%
    if (fcr <= 1.4) return 1.00;  // Acceptable: no change
    if (fcr <= 1.5) return 0.90;  // Poor: -10%
    return 0.85;                  // Very poor: -15%
  }

  // ── MAIN HYBRID CALCULATION ──────────────────────────────────────────────

  /// Calculate final feed recommendation using hybrid logic
  /// 
  /// This is the central decision engine. It:
  /// 1. Determines the appropriate mode (DOC vs Biomass vs Smart)
  /// 2. Calculates base feed using that mode
  /// 3. Applies FCR correction if available
  /// 4. Returns full debugging info
  static FeedResult calculateSmartFeed({
    // Core DOC/stocking data
    required int doc,
    required int density,
    required String stockingType,

    // Sampling data (optional)
    required double? abw,
    required int? seedCount,
    required double? survivalRate,
    required int? sampleAgeDays,

    // FCR data (optional)
    required double? fcr,
    required int? fcrAgeDays,

    // Feeding rate (for biomass mode)
    double biomassFeedPercent = 0.03, // 3% of biomass
  }) {
    final buffer = StringBuffer();
    final warnings = <String>[];

    // ─ VALIDATION ─
    buffer.writeln('🔍 FEED CALCULATION (Smart Feed Engine V2)');
    buffer.writeln('━' * 60);
    buffer.writeln('📊 INPUT: DOC=$doc, density=$density, stocking=$stockingType');

    // Check for valid sampling
    bool hasValidSampling = false;
    if (abw != null && abw > 0 && sampleAgeDays != null && sampleAgeDays <= 7) {
      hasValidSampling = true;
      buffer.writeln('✅ Sampling valid: ABW=${abw.toStringAsFixed(2)}g (age=$sampleAgeDays days)');
    } else if (abw == null) {
      buffer.writeln('⚠️  No ABW data');
    } else if (sampleAgeDays != null && sampleAgeDays > 7) {
      buffer.writeln('⚠️  Sampling stale: age=$sampleAgeDays days (threshold: 7)');
      warnings.add('Sampling data older than 7 days — consider updating');
    }

    // Check for valid FCR
    bool hasValidFcr = false;
    double fcrFactor = 1.0;
    if (fcr != null && fcrAgeDays != null && fcrAgeDays <= 10) {
      hasValidFcr = true;
      fcrFactor = _getFcrFactor(fcr);
      buffer.writeln('✅ FCR valid: FCR=${fcr.toStringAsFixed(2)} factor=$fcrFactor');
    } else if (fcr == null) {
      buffer.writeln('⚠️  No FCR data (from prior harvest)');
    }

    // ─ MODE RESOLUTION ─
    buffer.writeln('');
    final mode = resolveFeedMode(
      doc: doc,
      hasSampling: abw != null,
      hasValidSampling: hasValidSampling,
    );
    buffer.writeln('🎯 FEED MODE: ${mode.name.toUpperCase()}');

    // ─ FEED CALCULATION ─
    buffer.writeln('');
    double finalFeed = 0;
    double? docFeed;
    double? biomassFeed;
    double? fcrAdjustedFeed;
    double trayFactor = 1.0;
    double growthFactor = 1.0;
    double samplingAgeFactor = 1.0;

    if (mode == FeedMode.doc) {
      // Simple DOC-based mode
      docFeed = calculateDocFeed(
        doc: doc,
        density: density,
        stockingType: stockingType,
      );
      finalFeed = docFeed;
      buffer.writeln('📌 Using DOC-based ramp');
      buffer.writeln('  DOC Feed = ${docFeed.toStringAsFixed(3)} kg');

    } else if (mode == FeedMode.biomass) {
      // Biomass-based mode
      if (abw == null || seedCount == null) {
        // Fallback to DOC if biomass data incomplete
        docFeed = calculateDocFeed(
          doc: doc,
          density: density,
          stockingType: stockingType,
        );
        finalFeed = docFeed;
        buffer.writeln('📌 Biomass mode requested but data incomplete → fallback to DOC');
        buffer.writeln('  DOC Feed = ${docFeed.toStringAsFixed(3)} kg');
        warnings.add('Biomass calculation skipped: incomplete data');
      } else {
        biomassFeed = calculateBiomassFeed(
          abw: abw,
          seedCount: seedCount,
          survival: survivalRate ?? 0.90,
          feedPercent: biomassFeedPercent,
        );
        finalFeed = biomassFeed;
        buffer.writeln('📌 Using biomass-based calculation');
        buffer.writeln('  Biomass Feed = ${biomassFeed.toStringAsFixed(3)} kg');
      }

    } else {
      // Smart hybrid mode (DOC + data + FCR)
      docFeed = calculateDocFeed(
        doc: doc,
        density: density,
        stockingType: stockingType,
      );
      buffer.writeln('📌 Using HYBRID smart mode');
      buffer.writeln('  DOC base = ${docFeed.toStringAsFixed(3)} kg');

      finalFeed = docFeed;
    }

    // ─ FCR CORRECTION ─
    if (hasValidFcr) {
      buffer.writeln('');
      buffer.writeln('🔧 Applying FCR correction');
      fcrAdjustedFeed = applyFcrCorrection(
        baseFeed: finalFeed,
        fcr: fcr,
        fcrAgeDays: fcrAgeDays,
      );
      finalFeed = fcrAdjustedFeed;
      buffer.writeln('  FCR-adjusted = ${fcrAdjustedFeed.toStringAsFixed(3)} kg');
    }

    // ─ FINAL VALIDATION ─
    buffer.writeln('');
    buffer.writeln('✅ FINAL RESULT');
    buffer.writeln('━' * 60);
    buffer.writeln('🥘 RECOMMENDED FEED: ${finalFeed.toStringAsFixed(3)} kg');
    if (warnings.isNotEmpty) {
      buffer.writeln('⚠️  WARNINGS:');
      for (final w in warnings) {
        buffer.writeln('  - $w');
      }
    }

    if (debugMode) {
      print(buffer.toString());
    }

    return FeedResult(
      finalFeed: finalFeed,
      mode: mode,
      docFeed: docFeed,
      biomassFeed: biomassFeed,
      fcrAdjustedFeed: fcrAdjustedFeed,
      fcrFactor: fcrFactor,
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      samplingAgeFactor: samplingAgeFactor,
      debugTrace: buffer.toString(),
      hasValidSampling: hasValidSampling,
      hasValidFcr: hasValidFcr,
      warnings: warnings,
    );
  }
}
