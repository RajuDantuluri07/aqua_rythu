// Smart Feed Engine — Correction Layer
//
// Responsibilities:
//   Apply correction factors to the base feed from MasterFeedEngine:
//     • tray_factor        (shrimp appetite signal from tray observations)
//     • growth_factor      (ABW vs expected for DOC > 30)
//     • sampling_factor    (freshness decay on ABW signal)
//     • environment_factor (DO / ammonia — can stop feeding entirely)
//     • fcr_factor         (ONLY when sampling data is present)
//     • intelligence_factor (enforcement from yesterday's deviation)
//
// MUST NOT:
//   - Recompute base feed (that is MasterFeedEngine's job)
//   - Call FeedInputBuilder or any DB layer
//   - Duplicate DOC-ramp logic
//
// Entry point for runtime corrections: SmartFeedEngine.apply()
// For the full orchestrated pipeline (compute + persist): use FeedOrchestrator.

import '../constants/expected_abw_table.dart';
import '../enums/tray_status.dart';
import 'feed_intelligence_engine.dart';

// ── FEED PHASE ────────────────────────────────────────────────────────────────

/// Feed phase for a given DOC.
///
///   NORMAL     (DOC 1–14)  : no tray/smart adjustment
///   TRAY_HABIT (DOC 15–29) : collect tray data; NO feed correction
///   SMART      (DOC ≥ 30)  : full corrections active; tray MANDATORY
enum FeedMode { normal, trayHabit, smart }

/// Returns the [FeedMode] for [doc].
/// Fix #4: smart_feeding = (doc >= 31)  ← authoritative boundary
/// DOC 30 is tray-habit (data collected, no corrections) matching the product
/// rule "DOC 1–30 → blind feeding ONLY, DOC > 30 → smart feeding enabled."
FeedMode feedModeForDoc(int doc) {
  if (doc <= 14) return FeedMode.normal;
  if (doc <= 30) return FeedMode.trayHabit; // transitional; data collected, no adjustment
  return FeedMode.smart;
}

// ── CORRECTION RESULT ─────────────────────────────────────────────────────────

class CorrectionResult {
  /// Final recommended feed after all corrections (kg).
  final double finalFeed;

  /// Factor breakdown for debug / display.
  final double trayFactor;
  final double growthFactor;
  final double samplingFactor;
  final double environmentFactor;
  final double fcrFactor;
  final double intelligenceFactor;

  /// Combined guarded factor (product of all, clamped to ±10 %).
  final double combinedFactor;

  /// Human-readable reasons for each non-neutral factor.
  final List<String> reasons;

  /// Alerts that may require farmer attention.
  final List<String> alerts;

  /// True when environment factor caused a complete feed stop.
  final bool isCriticalStop;

  const CorrectionResult({
    required this.finalFeed,
    required this.trayFactor,
    required this.growthFactor,
    required this.samplingFactor,
    required this.environmentFactor,
    required this.fcrFactor,
    required this.intelligenceFactor,
    required this.combinedFactor,
    required this.reasons,
    required this.alerts,
    required this.isCriticalStop,
  });
}

// ── ENGINE ────────────────────────────────────────────────────────────────────

class SmartFeedEngine {
  // ── PUBLIC API ────────────────────────────────────────────────────────────

  /// Apply all correction factors to [baseFeed] and return the final
  /// recommended feed amount with a full factor breakdown.
  ///
  /// [baseFeed]        Base expected feed from MasterFeedEngine (kg).
  /// [intelligence]    Expected vs actual analysis from FeedIntelligenceEngine.
  /// [doc]             Day of Culture (1-based).
  /// [trayStatuses]    Latest tray observations (empty list = no data).
  /// [recentTrayLeftoverPct] Rolling leftover percentages for the last 3 days.
  /// [abw]             Latest Average Body Weight (g). Null before sampling.
  /// [sampleAgeDays]   Days since last ABW sample (0 = no sample).
  /// [fcrFactor]        Pre-computed FCR correction factor from FeedOrchestrator.
  ///                   1.0 (neutral) when outside the intelligent stage.
  /// [dissolvedOxygen] Latest DO reading (mg/L). Critical stop < 4.0.
  /// [ammonia]         Latest ammonia reading (mg/L).
  static CorrectionResult apply({
    required double baseFeed,
    required IntelligenceResult intelligence,
    required int doc,
    required List<TrayStatus> trayStatuses,
    List<double> recentTrayLeftoverPct = const [],
    double? abw,
    int sampleAgeDays = 0,
    double fcrFactor = 1.0,
    double dissolvedOxygen = 6.0,
    double ammonia = 0.05,
  }) {
    final reasons = <String>[];
    final alerts = <String>[];

    // ── 1. Environment factor (critical — checked first) ──────────────────
    final envFactor = _environmentFactor(
      dissolvedOxygen: dissolvedOxygen,
      ammonia: ammonia,
    );

    if (envFactor == 0.0) {
      alerts.add('🚨 Critical DO — stop feeding');
      return CorrectionResult(
        finalFeed: 0.0,
        trayFactor: 1.0,
        growthFactor: 1.0,
        samplingFactor: 1.0,
        environmentFactor: 0.0,
        fcrFactor: 1.0,
        intelligenceFactor: 1.0,
        combinedFactor: 0.0,
        reasons: ['Critical: DO below safe threshold — no feeding'],
        alerts: alerts,
        isCriticalStop: true,
      );
    }

    if (dissolvedOxygen < 5.0) alerts.add('⚠️ Low dissolved oxygen');
    if (ammonia > 0.1) alerts.add('⚠️ High ammonia levels');

    // ── 2. Tray factor (SMART phase only) ─────────────────────────────────
    final trayFactor = _trayFactor(
      doc: doc,
      trayStatuses: trayStatuses,
      recentTrayLeftoverPct: recentTrayLeftoverPct,
    );

    // ── 3. Growth factor (SMART phase only, DOC ≥ 30) ─────────────────────
    final growthFactor = _growthFactor(abw: abw, doc: doc);

    // ── 4. Sampling decay factor (SMART phase only) ───────────────────────
    final samplingFactor = _samplingFactor(
      abw: abw,
      doc: doc,
      sampleAgeDays: sampleAgeDays,
    );

    // ── 5. FCR factor (pre-computed by FeedOrchestrator; 1.0 outside intelligent stage) ──

    // ── 6. Intelligence factor (enforcement from yesterday's deviation) ───
    final intelligenceFactor = _intelligenceFactor(intelligence);

    // ── 7. Combine and guard ──────────────────────────────────────────────
    final rawCombined =
        trayFactor * growthFactor * samplingFactor * envFactor * fcrFactor;
    // Apply intelligence separately after the ±10 % guard on operational factors
    final guardedOperational = rawCombined.clamp(0.90, 1.10);
    final combinedFactor = (guardedOperational * intelligenceFactor).clamp(
      0.70, // minimum: never reduce more than 30 %
      1.25, // maximum: never increase more than 25 %
    );

    // ── 8. Build reasons ──────────────────────────────────────────────────
    if (trayFactor != 1.0) {
      reasons.add(
          'Tray signal: ${(trayFactor * 100).toStringAsFixed(0)} %');
    }
    if (growthFactor != 1.0) {
      reasons.add(
          'Growth signal: ${(growthFactor * 100).toStringAsFixed(0)} %');
    }
    if (samplingFactor != 1.0) {
      reasons.add(
          'Sampling confidence: ${(samplingFactor * 100).toStringAsFixed(0)} %');
    }
    if (envFactor != 1.0) {
      reasons.add(
          'Environment adjustment: ${(envFactor * 100).toStringAsFixed(0)} %');
    }
    if (fcrFactor != 1.0) {
      reasons.add(
          'FCR adjustment: ${(fcrFactor * 100).toStringAsFixed(0)} %');
    }
    if (intelligenceFactor != 1.0) {
      final sign = intelligenceFactor > 1.0 ? '+' : '';
      final pct = ((intelligenceFactor - 1.0) * 100).toStringAsFixed(0);
      reasons.add(
          'Deviation enforcement: $sign$pct% (${intelligence.statusLabel})');
    }

    final finalFeed =
        (baseFeed * combinedFactor).clamp(0.1, 50.0);

    return CorrectionResult(
      finalFeed: double.parse(finalFeed.toStringAsFixed(3)),
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      samplingFactor: samplingFactor,
      environmentFactor: envFactor,
      fcrFactor: fcrFactor,
      intelligenceFactor: intelligenceFactor,
      combinedFactor: combinedFactor,
      reasons: reasons,
      alerts: alerts,
      isCriticalStop: false,
    );
  }

  // ── PRIVATE FACTOR CALCULATIONS ───────────────────────────────────────────

  /// Tray factor — only active in SMART phase (DOC ≥ 31).
  static double _trayFactor({
    required int doc,
    required List<TrayStatus> trayStatuses,
    required List<double> recentTrayLeftoverPct,
  }) {
    if (doc <= 30) return 1.0; // Fix #4: no tray correction until DOC 31

    if (trayStatuses.isNotEmpty) {
      return _trayFactorFromStatuses(trayStatuses);
    }

    final usable = recentTrayLeftoverPct.where((v) => v >= 0).toList();
    if (usable.isNotEmpty) {
      final avg = usable.reduce((a, b) => a + b) / usable.length;
      return _leftoverPctToFactor(avg);
    }

    return 1.0;
  }

  static double _trayFactorFromStatuses(List<TrayStatus> statuses) {
    if (statuses.isEmpty) return 1.0;
    final leftovers = statuses.map(_leftoverPctForStatus).toList();
    final avg = leftovers.reduce((a, b) => a + b) / leftovers.length;
    return _leftoverPctToFactor(avg);
  }

  static double _leftoverPctToFactor(double pct) {
    if (pct == 0) return 1.1;
    if (pct <= 10) return 1.0;
    if (pct <= 25) return 0.9;
    return 0.75;
  }

  static double _leftoverPctForStatus(TrayStatus status) {
    switch (status) {
      case TrayStatus.empty:
        return 0.0;
      case TrayStatus.partial:
        return 30.0;
      case TrayStatus.full:
        return 70.0;
    }
  }

  /// Growth factor — only active in SMART phase (DOC ≥ 31).
  static double _growthFactor({required double? abw, required int doc}) {
    if (doc <= 30 || abw == null || abw <= 0) return 1.0; // Fix #4
    final expected = getExpectedABW(doc);
    if (expected <= 0) return 1.0;
    final ratio = abw / expected;
    if (ratio > 1.1) return 1.05;
    if (ratio < 0.9) return 0.95;
    return 1.0;
  }

  /// Sampling confidence decay — only active in SMART phase (DOC ≥ 31).
  static double _samplingFactor({
    required double? abw,
    required int doc,
    required int sampleAgeDays,
  }) {
    if (doc <= 30 || abw == null || abw <= 0) return 1.0; // Fix #4
    final expected = getExpectedABW(doc);
    if (expected < 0.5) return 1.0;
    final ratio = abw / expected;
    double rawFactor = 1.0;
    if (ratio > 1.1) {
      rawFactor = 1.05;
    } else if (ratio < 0.9) {
      rawFactor = 0.95;
    }
    final attenuated = 1.0 + (rawFactor - 1.0) * 0.7;
    final weight = _samplingWeight(sampleAgeDays);
    final decayed = 1.0 + (attenuated - 1.0) * weight;
    return decayed.clamp(0.9, 1.1);
  }

  static double _samplingWeight(int ageDays) {
    if (ageDays <= 2) return 1.0;
    if (ageDays <= 5) return 0.7;
    if (ageDays <= 7) return 0.4;
    return 0.0;
  }

  /// Environment factor — critical stop at DO < 4.0.
  static double _environmentFactor({
    required double dissolvedOxygen,
    required double ammonia,
  }) {
    if (dissolvedOxygen < 4.0) return 0.0;
    if (dissolvedOxygen < 5.0) return 0.9;
    if (ammonia > 0.2) return 0.9;
    if (ammonia > 0.1) return 0.95;
    return 1.0;
  }

  /// Intelligence factor — enforcement based on yesterday's deviation.
  ///
  /// Overfeeding yesterday → reduce today proportionally.
  /// Underfeeding yesterday → small catch-up bonus.
  /// Bounds: [0.75, 1.25].
  static double _intelligenceFactor(IntelligenceResult intelligence) {
    if (!intelligence.hasActualData) return 1.0;

    final deviationPct = intelligence.deviationPercent ?? 0.0;

    // Within ±5 %: no enforcement
    if (deviationPct.abs() <= 5.0) return 1.0;

    if (deviationPct > 5.0) {
      // Overfeeding yesterday → proportional reduction
      // 10 % overage → −2.5 %, 50 % overage → −12.5 %, 100 % → −25 %
      final factor = 1.0 - (deviationPct / 100.0) * 0.25;
      return factor.clamp(0.75, 1.0);
    } else {
      // Underfeeding yesterday → small catch-up
      // −10 % under → +1.5 %, −50 % → +7.5 %, −100 % → +15 %
      final factor = 1.0 + (deviationPct.abs() / 100.0) * 0.15;
      return factor.clamp(1.0, 1.25);
    }
  }

  // ── SAFE DB FACTOR APPLICATION ────────────────────────────────────────────

  /// Hard clamp: adjusted amount never goes below 70 % or above 130 % of base.
  static double applySafetyClamp(double base, double adjusted) {
    return adjusted.clamp(base * 0.70, base * 1.30);
  }
}
