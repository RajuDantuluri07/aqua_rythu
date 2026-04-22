// Smart Feed Engine V2 — DISABLED FOR V1 LAUNCH
//
// 🚫 THIS ENGINE IS NOT USED IN V1
// All feed corrections are handled by MasterFeedEngine with simple tray factor only.
//
// Legacy comment (kept for reference):
// Formula:
//   correctedFeed = baseFeed × trayFactor × growthFactor × waterFactor × docFactor
//
// Rules:
//   • Applies ONLY for DOC > 30 (blind phase DOC 1–30 is never touched)
//   • baseFeed always comes from MasterFeedEngine (never recomputed here)
//   • Each factor is a pure function — no DB, no UI, no side effects
//   • Safety clamp: correctedFeed ∈ [70%, 130%] of baseFeed
//   • Critical water stop: DO < 3.5 → correctedFeed = 0
//   • Water dominance: if waterFactor < 1.0, tray/growth boosts are suppressed
//   • Manual override: if isManualOverride, engine is skipped entirely
//
// This file is kept for backward compatibility only.
// Do not call SmartFeedEngineV2.calculate() — use MasterFeedEngine.orchestrate() instead.

import 'package:aqua_rythu/core/constants/expected_abw_table.dart';
import 'package:aqua_rythu/core/utils/logger.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// OUTPUT MODEL
// ═══════════════════════════════════════════════════════════════════════════════

/// Full result from [SmartFeedEngineV2.calculate].
/// Every intermediate value is exposed for debug visibility.
class SmartFeedV2Result {
  /// Base feed from MasterFeedEngine before any smart correction (kg).
  final double baseFeed;

  /// Tray appetite signal.
  /// Source: averaged latest 3-day leftover %.
  final double trayFactor;

  /// Growth signal.
  /// Source: ABW vs expected-ABW table, attenuated by sample age.
  final double growthFactor;

  /// Water quality risk signal.
  /// Source: dissolved oxygen + ammonia readings.
  final double waterFactor;

  /// DOC-stage conservatism.
  /// Slightly conservative at DOC 30–45 (acclimation) and DOC >75 (late stage).
  final double docFactor;

  /// Raw product of all factors before safety clamp.
  final double rawProduct;

  /// V2-corrected feed after safety clamp (kg). Intermediate — NOT the final output.
  /// FCR and intelligence factors are applied by MasterFeedEngine on top of this.
  final double correctedFeed;

  /// True when waterFactor == 0.0 — farmer must stop feeding.
  final bool isCriticalStop;

  /// True when rawProduct was clamped to [70%, 130%] range.
  final bool wasClamped;

  /// The leftover % value used for trayFactor (null = no tray data available).
  final double? trayLeftoverUsed;

  /// ABW used for growthFactor (null = no valid sample).
  final double? abwUsed;

  /// Expected ABW for this DOC from the lookup table.
  final double expectedAbw;

  /// Reason string for each non-neutral factor (for debug UI).
  final List<String> reasons;

  /// The single most important reason — shown as primary label in farmer UI.
  /// 'Feed optimal' when all signals are neutral.
  final String primaryReason;

  /// Confidence score 0.0–1.0 based on data availability.
  ///   1.0 = tray + fresh ABW available
  ///   0.7 = one signal missing
  ///   0.4 = both signals missing or stale
  final double confidence;

  const SmartFeedV2Result({
    required this.baseFeed,
    required this.trayFactor,
    required this.growthFactor,
    required this.waterFactor,
    required this.docFactor,
    required this.rawProduct,
    required this.correctedFeed,
    required this.isCriticalStop,
    required this.wasClamped,
    required this.trayLeftoverUsed,
    required this.abwUsed,
    required this.expectedAbw,
    required this.reasons,
    required this.primaryReason,
    required this.confidence,
  });

  /// Percentage change from baseFeed to correctedFeed (+/- %).
  double get adjustmentPercent =>
      baseFeed > 0 ? ((correctedFeed / baseFeed) - 1.0) * 100.0 : 0.0;

  /// Human-readable confidence tier for UI display.
  String get confidenceLabel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  /// Flat map used by the debug dashboard.
  Map<String, dynamic> toDebugMap() => {
        'baseFeed': _fmt(baseFeed),
        'trayFactor': _fmt(trayFactor),
        'growthFactor': _fmt(growthFactor),
        'waterFactor': _fmt(waterFactor),
        'docFactor': _fmt(docFactor),
        'rawProduct': _fmt(rawProduct),
        'correctedFeed': _fmt(correctedFeed),
        'adjustment%': '${adjustmentPercent.toStringAsFixed(1)}%',
        'isCriticalStop': isCriticalStop,
        'wasClamped': wasClamped,
        'trayLeftover%': trayLeftoverUsed?.toStringAsFixed(1) ?? 'n/a',
        'abwUsed': abwUsed?.toStringAsFixed(2) ?? 'n/a',
        'expectedAbw': _fmt(expectedAbw),
        'primaryReason': primaryReason,
        'confidence':
            '${(confidence * 100).toStringAsFixed(0)}% ($confidenceLabel)',
        'reasons': reasons.join(' | '),
      };

  static String _fmt(double v) => v.toStringAsFixed(3);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

class SmartFeedEngineV2 {
  static const String version = 'v2.1.0';

  // Configuration Constants
  static const double _kMinSafetyClamp = 0.70;
  static const double _kMaxSafetyClamp = 1.30;
  static const double _kCriticalDO = 3.5;
  static const double _kHighRiskDO = 4.5;
  static const double _kModerateRiskDO = 5.5;
  static const double _kHighRiskAmmonia = 0.3;
  static const double _kModerateRiskAmmonia = 0.1;

  // ── PUBLIC ENTRY POINT ─────────────────────────────────────────────────────

  /// Calculate smart-adjusted feed for [doc] > 30.
  ///
  /// Returns [SmartFeedV2Result] with full factor breakdown.
  /// Caller MUST check [SmartFeedV2Result.isCriticalStop] before using
  /// [SmartFeedV2Result.correctedFeed].
  ///
  /// [baseFeed]              Base feed from MasterFeedEngine (kg). Never 0.
  /// [doc]                   Day of culture (must be > 30; guard is enforced).
  /// [isManualOverride]      When true, engine is skipped — farmer value is used.
  /// [recentTrayLeftoverPct] Last 1–3 observations (newest last). Empty = no data.
  /// [abw]                   Latest ABW (g). Null before first sampling.
  /// [sampleAgeDays]         Days since last ABW sample. 0 = fresh.
  /// [dissolvedOxygen]       Latest DO reading (mg/L). Default 6.0 = safe.
  /// [ammonia]               Latest ammonia reading (mg/L). Default 0.0 = safe.
  static SmartFeedV2Result calculate({
    required double baseFeed,
    required int doc,
    bool isManualOverride = false,
    List<double> recentTrayLeftoverPct = const [],
    double? abw,
    int sampleAgeDays = 0,
    double dissolvedOxygen = 6.0,
    double ammonia = 0.0,
  }) {
    assert(baseFeed > 0, 'baseFeed must be positive');
    // DOC gate is enforced by MasterFeedEngine before calling this engine.
    assert(doc > 30, 'SmartFeedEngineV2 must only be called for DOC > 30');

    // Issue 6: farmer manually set this round — never override their decision
    if (isManualOverride) {
      AppLogger.info(
          '[SmartFeedEngineV2] Manual override active — skipping smart adjustment');
      return _manualOverrideResult(baseFeed, doc);
    }

    final reasons = <String>[];

    // ── 1. Water factor (evaluated first — critical stop path) ──────────────
    final waterResult = getWaterFactor(
      dissolvedOxygen: dissolvedOxygen,
      ammonia: ammonia,
    );
    final waterFactor = waterResult.factor;

    if (waterResult.isCriticalStop) {
      AppLogger.error(
          '[SmartFeedEngineV2] Critical DO ($dissolvedOxygen mg/L) — feed STOPPED');
      return _criticalStopResult(baseFeed, doc, waterResult.reason);
    }

    if (waterFactor != 1.0) reasons.add(waterResult.reason);

    // ── 2. Tray factor ──────────────────────────────────────────────────────
    final trayData = _resolveLatestLeftover(recentTrayLeftoverPct);
    // Issue 2: explicit no-data reason for debug clarity
    if (trayData == null) reasons.add('No tray data — using baseline');

    // Compute raw tray factor
    var trayFactor = trayData != null ? getTrayFactor(trayData) : 1.0;

    // Issue 1: water dominance — risky water blocks all positive boosts
    if (waterFactor < 1.0 && trayFactor > 1.0) trayFactor = 1.0;

    final trayReason = _trayReason(trayData, trayFactor);
    if (trayFactor != 1.0) reasons.add(trayReason);

    // ── 3. Growth factor ────────────────────────────────────────────────────
    // Issue 2: explicit no-data reason for debug clarity
    if (abw == null) reasons.add('No sampling data — growth neutral');

    final expectedAbw = getExpectedABW(doc);
    final growthResult = getGrowthFactor(
      abw: abw,
      doc: doc,
      sampleAgeDays: sampleAgeDays,
      expectedAbw: expectedAbw,
    );

    // Issue 1: water dominance — risky water blocks positive growth boost
    var growthFactor = growthResult.factor;
    if (waterFactor < 1.0 && growthFactor > 1.0) growthFactor = 1.0;

    if (growthFactor != 1.0) reasons.add(growthResult.reason);

    // ── 4. DOC factor ───────────────────────────────────────────────────────
    final docFactor = getDocFactor(doc);
    if (docFactor != 1.0) {
      reasons
          .add('DOC $doc: stage adjustment ×${docFactor.toStringAsFixed(2)}');
    }

    // ── 5. Combine factors & clamp ──────────────────────────────────────────
    final rawProduct = trayFactor * growthFactor * waterFactor * docFactor;
    final clampedProduct = rawProduct.clamp(
      _kMinSafetyClamp,
      _kMaxSafetyClamp,
    );
    final wasClamped = (rawProduct - clampedProduct).abs() > 0.001;

    double correctedFeed = baseFeed * clampedProduct;
    // Issue 3: cap at 2× baseFeed (scales with pond size) instead of fixed 50 kg
    correctedFeed = correctedFeed.clamp(0.1, baseFeed * 2.0);

    if (wasClamped) {
      reasons.add(
          'Safety clamp applied (raw ${(rawProduct * 100).toStringAsFixed(0)}% → ${(clampedProduct * 100).toStringAsFixed(0)}%)');
    }

    // ── 6. Confidence score (data availability) ─────────────────────────────
    double confidence = 1.0;
    if (abw == null) confidence -= 0.3; // no growth signal
    if (trayData == null) confidence -= 0.3; // no appetite signal
    if (sampleAgeDays > 5) confidence -= 0.2; // stale sample attenuates signal
    confidence = confidence.clamp(0.0, 1.0);

    // ── 7. Primary reason for farmer UI ────────────────────────────────────
    // Skip "no data" entries (index 0 or 1) as primary — prefer factor reasons.
    final factorReasons = reasons.where((r) => !r.startsWith('No ')).toList();
    final primaryReason =
        factorReasons.isNotEmpty ? factorReasons.first : 'Feed optimal';

    final result = SmartFeedV2Result(
      baseFeed: baseFeed,
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      waterFactor: waterFactor,
      docFactor: docFactor,
      rawProduct: rawProduct,
      correctedFeed: correctedFeed,
      isCriticalStop: false,
      wasClamped: wasClamped,
      trayLeftoverUsed: trayData,
      abwUsed: growthResult.abwUsed,
      expectedAbw: expectedAbw,
      reasons: reasons,
      primaryReason: primaryReason,
      confidence: confidence,
    );

    AppLogger.debug(
        '[SmartFeedEngineV2] DOC=$doc base=${baseFeed.toStringAsFixed(3)} '
        'final=${correctedFeed.toStringAsFixed(3)} '
        'T=${trayFactor.toStringAsFixed(2)} '
        'G=${growthFactor.toStringAsFixed(2)} '
        'W=${waterFactor.toStringAsFixed(2)} '
        'D=${docFactor.toStringAsFixed(2)} '
        'confidence=${(confidence * 100).toStringAsFixed(0)}%');

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTOR FUNCTIONS (public — testable individually)
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Tray Factor ─────────────────────────────────────────────────────────────

  /// Maps latest tray leftover % → feed factor.
  ///
  /// Appetite signal table (spec):
  ///   0%        → 1.15  (+15%)  shrimp ate everything
  ///   1–9%      → 1.10  (+10%)  near-clean tray
  ///   10–20%    → 1.00  (0%)    normal consumption
  ///   21–50%    → 0.85  (-15%)  moderate leftover
  ///   > 50%     → 0.70  (-30%)  heavy leftover — aggressive cut
  ///
  /// [leftoverPct] must be in [0, 100].
  static double getTrayFactor(double leftoverPct) {
    assert(leftoverPct >= 0 && leftoverPct <= 100);
    if (leftoverPct <= 0) return 1.15;
    if (leftoverPct < 10) return 1.10;
    if (leftoverPct <= 20) return 1.00;
    if (leftoverPct <= 50) return 0.85;
    return 0.70;
  }

  // ── Growth Factor ────────────────────────────────────────────────────────────

  /// ABW vs expected ABW → growth speed → feed adjustment.
  ///
  ///   fast  (ABW > 110% expected) → +5%   (1.05)
  ///   good  (90–110% expected)    → 0%    (1.00)
  ///   slow  (ABW < 90% expected)  → -10%  (0.90)   [fix: was -5%]
  ///
  /// Sample age attenuation:
  ///   ≤2 days → full weight
  ///   ≤5 days → 70% weight
  ///   ≤7 days → 40% weight
  ///   >7 days → no signal (return 1.0)
  static GrowthFactorResult getGrowthFactor({
    required double? abw,
    required int doc,
    required int sampleAgeDays,
    required double expectedAbw,
  }) {
    if (abw == null || abw <= 0 || expectedAbw <= 0) {
      return const GrowthFactorResult(
          factor: 1.0, reason: 'No ABW data', abwUsed: null);
    }
    if (sampleAgeDays > 7) {
      return GrowthFactorResult(
          factor: 1.0,
          reason: 'ABW sample too old ($sampleAgeDays days)',
          abwUsed: abw);
    }

    final ratio = abw / expectedAbw;

    double rawFactor;
    String status;
    if (ratio > 1.10) {
      rawFactor = 1.05;
      status = 'fast growth (+5%)';
    } else if (ratio < 0.90) {
      rawFactor = 0.90; // fixed: was 0.95
      status = 'slow growth (-10%)';
    } else {
      rawFactor = 1.00;
      status = 'good growth (0%)';
    }

    // Attenuate by sample age
    final weight = _samplingWeight(sampleAgeDays);
    final attenuated = 1.0 + (rawFactor - 1.0) * weight;
    final factor = attenuated.clamp(0.90, 1.10);

    final reason = 'Growth: $status '
        '(ABW ${abw.toStringAsFixed(2)}g vs expected ${expectedAbw.toStringAsFixed(2)}g, '
        '${sampleAgeDays}d old, weight ${(weight * 100).toStringAsFixed(0)}%)';

    return GrowthFactorResult(factor: factor, reason: reason, abwUsed: abw);
  }

  // ── Water Factor ─────────────────────────────────────────────────────────────

  /// Dissolved oxygen + ammonia → risk signal → feed reduction.
  ///
  ///   DO < 3.5             → STOP feeding (critical)
  ///   DO < 4.5 or NH₃>0.3 → -20%  (0.80)  high risk
  ///   DO < 5.5 or NH₃>0.1 → -10%  (0.90)  moderate stress
  ///   otherwise            → 0%   (1.00)  normal
  ///
  /// When waterFactor < 1.0, the caller (calculate) additionally caps
  /// trayFactor and growthFactor at 1.0 — see water dominance rule.
  static WaterFactorResult getWaterFactor({
    required double dissolvedOxygen,
    required double ammonia,
  }) {
    // Critical stop — only at genuinely dangerous DO level
    if (dissolvedOxygen < _kCriticalDO) {
      return WaterFactorResult(
        factor: 0.0,
        isCriticalStop: true,
        reason:
            'CRITICAL: DO ${dissolvedOxygen.toStringAsFixed(1)} mg/L < $_kCriticalDO — stop feeding',
      );
    }

    // High risk: low DO or high ammonia
    if (dissolvedOxygen < _kHighRiskDO || ammonia > _kHighRiskAmmonia) {
      final who = dissolvedOxygen < _kHighRiskDO
          ? 'DO ${dissolvedOxygen.toStringAsFixed(1)} mg/L'
          : 'NH₃ ${ammonia.toStringAsFixed(2)} mg/L';
      return WaterFactorResult(
        factor: 0.80,
        isCriticalStop: false,
        reason: 'High water risk ($who) → -20%',
      );
    }

    // Moderate stress
    if (dissolvedOxygen < _kModerateRiskDO || ammonia > _kModerateRiskAmmonia) {
      final who = dissolvedOxygen < _kModerateRiskDO
          ? 'DO ${dissolvedOxygen.toStringAsFixed(1)} mg/L'
          : 'NH₃ ${ammonia.toStringAsFixed(2)} mg/L';
      return WaterFactorResult(
        factor: 0.90,
        isCriticalStop: false,
        reason: 'Moderate water stress ($who) → -10%',
      );
    }

    return const WaterFactorResult(
        factor: 1.0, isCriticalStop: false, reason: 'Water quality normal');
  }

  // ── DOC Factor ───────────────────────────────────────────────────────────────

  /// DOC-based stage conservatism.
  ///
  ///   DOC 31–45  → 0.95  acclimation period — conservative
  ///   DOC 46–75  → 1.00  optimal feeding window — normal
  ///   DOC > 75   → 0.95  late stage, slower metabolism — conservative
  static double getDocFactor(int doc) {
    assert(doc > 30, 'getDocFactor should only be called for DOC > 30');
    if (doc <= 45) return 0.95;
    if (doc <= 75) return 1.00;
    return 0.95;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static const double _kMinFactor = 0.70;
  static const double _kMaxFactor = 1.30;

  /// Use the most recent leftover reading. Average the last 3 if fresh data
  /// exists; fall back to the last single value.
  static double? _resolveLatestLeftover(List<double> history) {
    final usable = history.where((v) => v >= 0 && v <= 100).toList();
    if (usable.isEmpty) return null;
    // Weighted: latest reading has 50% weight, prior readings share 50%
    if (usable.length == 1) return usable.last;
    final last = usable.last;
    final prior = usable.sublist(0, usable.length - 1);
    final priorAvg = prior.reduce((a, b) => a + b) / prior.length;
    return (last * 0.5 + priorAvg * 0.5).clamp(0.0, 100.0);
  }

  static String _trayReason(double? leftoverPct, double factor) {
    if (leftoverPct == null) return 'No tray data';
    final pctStr = leftoverPct.toStringAsFixed(1);
    final adj = factor >= 1.0
        ? '+${((factor - 1) * 100).toStringAsFixed(0)}%'
        : '${((factor - 1) * 100).toStringAsFixed(0)}%';
    return 'Tray $pctStr% leftover → $adj';
  }

  static double _samplingWeight(int ageDays) {
    if (ageDays <= 2) return 1.0;
    if (ageDays <= 5) return 0.7;
    if (ageDays <= 7) return 0.4;
    return 0.0;
  }

  /// Returns a neutral (all-factors-1.0) result for the blind phase.
  /// Called by MasterFeedEngine when doc ≤ kSmartModeMinDoc — V2 is never
  /// invoked for blind-phase DOCs.
  static SmartFeedV2Result blindPhaseResult(double baseFeed, int doc) {
    return SmartFeedV2Result(
      baseFeed: baseFeed,
      trayFactor: 1.0,
      growthFactor: 1.0,
      waterFactor: 1.0,
      docFactor: 1.0,
      rawProduct: 1.0,
      correctedFeed: baseFeed,
      isCriticalStop: false,
      wasClamped: false,
      trayLeftoverUsed: null,
      abwUsed: null,
      expectedAbw: getExpectedABW(doc),
      reasons: const ['DOC ≤ 30 — blind phase, no adjustment'],
      primaryReason: 'DOC ≤ 30 — blind phase, no adjustment',
      confidence: 1.0,
    );
  }

  static SmartFeedV2Result _manualOverrideResult(double baseFeed, int doc) {
    return SmartFeedV2Result(
      baseFeed: baseFeed,
      trayFactor: 1.0,
      growthFactor: 1.0,
      waterFactor: 1.0,
      docFactor: 1.0,
      rawProduct: 1.0,
      correctedFeed: baseFeed,
      isCriticalStop: false,
      wasClamped: false,
      trayLeftoverUsed: null,
      abwUsed: null,
      expectedAbw: getExpectedABW(doc),
      reasons: const ['Manual override — farmer value used as-is'],
      primaryReason: 'Manual override — farmer value used as-is',
      confidence: 1.0,
    );
  }

  static SmartFeedV2Result _criticalStopResult(
      double baseFeed, int doc, String reason) {
    return SmartFeedV2Result(
      baseFeed: baseFeed,
      trayFactor: 1.0,
      growthFactor: 1.0,
      waterFactor: 0.0,
      docFactor: 1.0,
      rawProduct: 0.0,
      correctedFeed: 0.0,
      isCriticalStop: true,
      wasClamped: false,
      trayLeftoverUsed: null,
      abwUsed: null,
      expectedAbw: getExpectedABW(doc),
      reasons: [reason],
      primaryReason: reason,
      confidence: 1.0, // water reading is confident — it IS dangerous
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE OBJECTS
// ═══════════════════════════════════════════════════════════════════════════════

class GrowthFactorResult {
  final double factor;
  final String reason;
  final double? abwUsed;
  const GrowthFactorResult(
      {required this.factor, required this.reason, required this.abwUsed});
}

class WaterFactorResult {
  final double factor;
  final bool isCriticalStop;
  final String reason;
  const WaterFactorResult(
      {required this.factor,
      required this.isCriticalStop,
      required this.reason});
}
