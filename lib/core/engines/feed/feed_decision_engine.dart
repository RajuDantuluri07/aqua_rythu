// Feed Decision Engine — DISABLED FOR V1 LAUNCH
//
// 🚫 THIS ENGINE IS NOT ACTIVELY USED IN V1
// Decision logic simplified — now returns static "Maintain Feeding" from MasterFeedEngine.
//
// Legacy comment (kept for reference):
// Converts raw feed numbers into a single, human-readable decision:
//   action     → Increase / Reduce / Maintain / Stop Feeding
//   deltaKg    → +0.5 / -1.2 etc.
//   reason     → Overfeeding detected, Tray low, etc.
//   recommendations → actionable list reused from correction pipeline
//   decisionTrace   → full audit trail passed from orchestrator
//
// Recommendation logic ported from:
//   _archive/smart_feed_decision_engine.dart → generateRecommendations()
//
// This file is kept for backward compatibility only.
// MasterFeedEngine.orchestrate() creates FeedDecision directly.

import '../../enums/feed_stage.dart';
import 'feed_intelligence_engine.dart';

// ── DECISION MODEL ────────────────────────────────────────────────────────────

class FeedDecision {
  /// Primary action label shown in UI.
  final String action;

  /// finalFeed − baseFeed (kg). Negative = reduction, positive = increase.
  final double deltaKg;

  /// One-line reason for the action.
  final String reason;

  /// Actionable recommendations for the farmer (ported from archived engine).
  final List<String> recommendations;

  /// Full audit trail of the pipeline decision.
  final List<String> decisionTrace;

  const FeedDecision({
    required this.action,
    required this.deltaKg,
    required this.reason,
    required this.recommendations,
    required this.decisionTrace,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedDecision &&
        other.action == action &&
        other.deltaKg == deltaKg &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(action, deltaKg, reason);

  /// Signed delta display: "+0.5 kg" / "-1.2 kg" / "0.0 kg"
  String get formattedDelta {
    if (deltaKg.abs() < 0.001) return '0.0 kg';
    final sign = deltaKg > 0 ? '+' : '';
    return '$sign${deltaKg.toStringAsFixed(1)} kg';
  }
}

// ── ENGINE ────────────────────────────────────────────────────────────────────

class FeedDecisionEngine {
  // ── MAIN ENTRY POINT ─────────────────────────────────────────────────────

  /// Convert pipeline outputs into a single [FeedDecision].
  ///
  /// [baseFeed]                  Output of MasterFeedEngine (kg).
  /// [finalFeed]                 Output of SmartFeedEngine (kg).
  /// [intelligence]              Expected vs actual analysis.
  /// [stage]                     Current feed stage.
  /// [existingRecommendations]   Pre-generated recs (use [generateRecommendations]).
  /// [decisionTrace]             Audit trail built by the orchestrator.
  /// [isCriticalStop]            True when environment factor zeroed the feed.
  static FeedDecision compute({
    required double baseFeed,
    required double finalFeed,
    required IntelligenceResult intelligence,
    required FeedStage stage,
    required double trayFactor,
    required double growthFactor,
    required double environmentFactor,
    required double fcrFactor,
    required FeedStatus intelligenceStatus,
    required bool hasActualData,
    required double confidenceScore,
    required List<String> alerts,
    required List<String> existingRecommendations,
    required List<String> decisionTrace,
    bool isCriticalStop = false,
  }) {
    final delta = finalFeed - baseFeed;
    final bool hasStrongNegativeSignal =
        hasActualData && intelligenceStatus == FeedStatus.overfeeding;

    final updatedTrace = [
      ...decisionTrace,
      'Tray factor: ${trayFactor.toStringAsFixed(3)}',
      'Growth factor: ${growthFactor.toStringAsFixed(3)}',
      'Env factor: ${environmentFactor.toStringAsFixed(3)}',
      'FCR factor: ${fcrFactor.toStringAsFixed(3)}',
      ...alerts.map((alert) => 'Alert: $alert'),
    ];

    String appendConfidence(String reason) {
      if (confidenceScore < 0.5) {
        return '$reason (low confidence)';
      }
      return reason;
    }

    if (isCriticalStop || environmentFactor == 0.0) {
      return FeedDecision(
        action: 'Stop Feeding',
        deltaKg: double.parse(delta.toStringAsFixed(3)),
        reason: 'Critical water condition (low DO / high ammonia)',
        recommendations: existingRecommendations.isNotEmpty
            ? existingRecommendations
            : ['🚨 Stop feeding immediately — critical water condition'],
        decisionTrace: updatedTrace,
      );
    }

    if (environmentFactor < 1.0) {
      return _reduceDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Water quality stress detected'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (trayFactor < 0.95) {
      return _reduceDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Shrimp not consuming feed fully'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (hasActualData && intelligenceStatus == FeedStatus.overfeeding) {
      return _reduceDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Excess feed detected yesterday'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (trayFactor > 1.05 && !hasStrongNegativeSignal) {
      return _increaseDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Shrimp showing strong appetite'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (hasActualData && intelligenceStatus == FeedStatus.underfeeding) {
      return _increaseDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Feed intake lower than expected'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (growthFactor < 0.95) {
      return _reduceDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Shrimp growth below expected curve'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (growthFactor > 1.05 && !hasStrongNegativeSignal) {
      return _increaseDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Growth above expected'),
        existingRecommendations,
        updatedTrace,
      );
    }

    if (stage == FeedStage.intelligent && fcrFactor < 0.9) {
      return _reduceDecision(
        baseFeed,
        finalFeed,
        appendConfidence('Poor feed conversion (high FCR)'),
        existingRecommendations,
        updatedTrace,
      );
    }

    return FeedDecision(
      action: 'Maintain Feeding',
      deltaKg: double.parse(delta.toStringAsFixed(3)),
      reason: appendConfidence('All signals normal'),
      recommendations: existingRecommendations.isNotEmpty
          ? existingRecommendations
          : ['✓ Proceed with recommended feed amount'],
      decisionTrace: updatedTrace,
    );
  }

  static FeedDecision _reduceDecision(
    double base,
    double finalFeed,
    String reason,
    List<String> existingRecommendations,
    List<String> decisionTrace,
  ) {
    return FeedDecision(
      action: 'Reduce Feeding',
      deltaKg: double.parse((finalFeed - base).toStringAsFixed(3)),
      reason: reason,
      recommendations: existingRecommendations.isNotEmpty
          ? existingRecommendations
          : ['✓ Proceed with recommended feed amount'],
      decisionTrace: decisionTrace,
    );
  }

  static FeedDecision _increaseDecision(
    double base,
    double finalFeed,
    String reason,
    List<String> existingRecommendations,
    List<String> decisionTrace,
  ) {
    return FeedDecision(
      action: 'Increase Feeding',
      deltaKg: double.parse((finalFeed - base).toStringAsFixed(3)),
      reason: reason,
      recommendations: existingRecommendations.isNotEmpty
          ? existingRecommendations
          : ['✓ Proceed with recommended feed amount'],
      decisionTrace: decisionTrace,
    );
  }

  // ── RECOMMENDATION GENERATOR (ported from archived engine) ───────────────

  /// Generate actionable recommendations for the farmer.
  ///
  /// Ported from [SmartFeedDecisionEngine.generateRecommendations] in the
  /// archived engine — adapted to accept [CorrectionResult]-style factors
  /// directly rather than the old FeedInput.
  ///
  /// [trayFactor]       Tray correction factor from SmartFeedEngine.
  /// [growthFactor]     Growth correction factor.
  /// [fcrFactor]        FCR correction factor.
  /// [confidenceScore]  Derived from feed stage (blind=0.4, transitional=0.65, intelligent=0.85).
  /// [alerts]           Critical alerts from SmartFeedEngine (env stop, low DO, etc.).
  /// [isCriticalStop]   When true, returns a single stop recommendation.
  static List<String> generateRecommendations({
    required double trayFactor,
    required double growthFactor,
    required double fcrFactor,
    required double confidenceScore,
    required List<String> alerts,
    bool isCriticalStop = false,
  }) {
    if (isCriticalStop) {
      return ['🚨 Stop feeding immediately — critical water condition'];
    }

    final recs = <String>[];

    // ── FCR-BASED ─────────────────────────────────────────────────────────
    if (fcrFactor < 0.90) {
      recs.add('⚠️ Reduce feed for next 2 days and monitor tray');
    } else if (fcrFactor < 0.95) {
      recs.add('→ Slightly reduce feed for next 2 days');
    } else if (fcrFactor > 1.10) {
      recs.add('→ Consider increasing feed gradually');
    }

    // ── TRAY-BASED ────────────────────────────────────────────────────────
    if (trayFactor > 1.05) {
      recs.add('✓ Tray looks good — continue current feeding');
    } else if (trayFactor < 0.85) {
      recs.add('⚠️ High tray leftover — reduce feed next round');
    } else if (trayFactor < 0.95) {
      recs.add('→ Monitor tray closely for overflow');
    }

    // ── GROWTH-BASED ──────────────────────────────────────────────────────
    if (growthFactor > 1.05) {
      recs.add('✓ Growth trending well — maintain feeding');
    } else if (growthFactor < 0.95) {
      recs.add('⚠️ Growth below expected — monitor closely');
    }

    // ── ALERTS (environment, DO, ammonia) ─────────────────────────────────
    recs.addAll(alerts);

    // ── CONFIDENCE ────────────────────────────────────────────────────────
    if (confidenceScore < 0.55) {
      recs.add('⚠️ Limited data — verify recommendation with manual observation');
    }

    // ── ENSURE MINIMUM ────────────────────────────────────────────────────
    if (recs.isEmpty) {
      recs.add('✓ Recommendation looks good — proceed with confidence');
    }

    return recs;
  }

  // ── CONFIDENCE FROM STAGE ─────────────────────────────────────────────────

  /// Approximate confidence score from the pipeline's feed stage.
  static double confidenceForStage(FeedStage stage) {
    switch (stage) {
      case FeedStage.blind:
        return 0.40;
      case FeedStage.transitional:
        return 0.65;
      case FeedStage.intelligent:
        return 0.85;
    }
  }
}
