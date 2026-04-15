import '../../../models/feed_result.dart';

/// Advanced output from SmartFeedEngine with decision intelligence
/// 
/// This model encapsulates:
/// - Calculation results (feed amounts, factors)
/// - Decision explanation (why this feed?)
/// - Confidence assessment (how sure are we?)
/// - Actionable recommendations (what to do next?)
class SmartFeedOutput {
  // ── CALCULATION RESULTS ────────────────────────────────────────────────────
  
  /// Final recommended feed quantity (kg)
  final double finalFeed;

  /// Feed source indicator (DOC vs Biomass-based)
  final FeedSource source;

  /// DOC-based calculation (baseline)
  final double docFeed;

  /// Biomass-based calculation (if sampling available)
  final double? biomassFeed;

  // ── INDIVIDUAL FACTORS ─────────────────────────────────────────────────────
  
  /// FCR factor (food conversion ratio)
  /// < 1.0 = reduce feed (overfeeding)
  /// > 1.0 = increase feed (underfeeding)
  final double? fcrFactor;

  /// Tray leftover factor
  /// > 1.0 = more leftover = reduce feed
  /// < 1.0 = less leftover = increase feed
  final double? trayFactor;

  /// Growth trend factor
  /// > 1.0 = faster growth = good
  /// < 1.0 = slower growth = concerning
  final double? growthFactor;

  /// Recency of sampling data (in days)
  /// Used for confidence calculation
  final int? samplingAgeDays;

  // ── DECISION INTELLIGENCE ──────────────────────────────────────────────────
  
  /// Plain English explanation of WHY this feed recommendation
  /// Example: "Biomass data used from sampling\nFCR indicates overfeeding → reducing feed"
  final String explanation;

  /// Confidence score (0.0 - 1.0)
  /// Reflects data quality and completeness
  /// 0.9+ = Very confident (fresh sampling + multiple factors)
  /// 0.7-0.9 = Confident (most data available)
  /// 0.5-0.7 = Moderate (some data missing)
  /// < 0.5 = Low confidence (minimal data)
  final double confidenceScore;

  /// Actionable recommendations for farmer
  /// Example: ["Reduce feed slightly for next 2 days", "Check tray after next feeding"]
  final List<String> recommendations;

  // ── METADATA ───────────────────────────────────────────────────────────────
  
  /// Engine version that generated this output
  final String engineVersion;

  /// Timestamp of calculation
  final DateTime calculatedAt;

  SmartFeedOutput({
    required this.finalFeed,
    required this.source,
    required this.docFeed,
    this.biomassFeed,
    this.fcrFactor,
    this.trayFactor,
    this.growthFactor,
    this.samplingAgeDays,
    required this.explanation,
    required this.confidenceScore,
    required this.recommendations,
    this.engineVersion = "v2.1",
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  /// Calculate adjustment from DOC feed
  double get feedAdjustment => finalFeed - docFeed;

  /// Calculate adjustment percentage
  double get adjustmentPercent {
    if (docFeed == 0) return 0;
    return (feedAdjustment / docFeed) * 100;
  }

  /// Get confidence label for UI display
  String get confidenceLabel {
    if (confidenceScore >= 0.9) return "Very High";
    if (confidenceScore >= 0.8) return "High";
    if (confidenceScore >= 0.7) return "Good";
    if (confidenceScore >= 0.6) return "Moderate";
    if (confidenceScore >= 0.5) return "Low";
    return "Very Low";
  }

  /// Get confidence color indicator
  /// Green: >= 0.8
  /// Orange: 0.6-0.79
  /// Red: < 0.6
  String get confidenceColor {
    if (confidenceScore >= 0.8) return "green";
    if (confidenceScore >= 0.6) return "orange";
    return "red";
  }

  /// Whether adjustment is significant (> 5%)
  bool get isSignificantAdjustment => adjustmentPercent.abs() > 5.0;

  /// Whether we have recent sampling data (< 7 days)
  bool get hasRecentSampling =>
      samplingAgeDays != null && samplingAgeDays! <= 7;

  /// Whether we have any biomass data
  bool get hasBiomassData => biomassFeed != null;

  /// Count of active adjustment factors
  int get activeFactorCount {
    int count = 0;
    if ((fcrFactor ?? 1.0 - 1.0).abs() > 0.01) count++;
    if ((trayFactor ?? 1.0 - 1.0).abs() > 0.01) count++;
    if ((growthFactor ?? 1.0 - 1.0).abs() > 0.01) count++;
    return count;
  }
}
