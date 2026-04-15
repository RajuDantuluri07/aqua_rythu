import '../constants/expected_abw_table.dart';
import '../enums/tray_status.dart';
import 'feeding_engine_v1.dart';
import 'fcr_engine.dart';

/// Centralized factor calculations for feed recommendations.
///
/// This engine is intentionally small and deterministic so each component can
/// be independently tested and audited.
class FeedFactorEngine {
  /// Tray factor based on recent tray observations.
  ///
  /// Only active in SMART phase (DOC > 30). Before that, tray data is
  /// collected without changing the feed quantity.
  static double calculateTrayFactor({
    required int doc,
    required List<TrayStatus> trayStatuses,
    List<double>? recentTrayLeftoverPct,
  }) {
    if (doc <= 30) return 1.0;

    if (trayStatuses.isNotEmpty) {
      return _trayFactorFromStatuses(trayStatuses);
    }

    if (recentTrayLeftoverPct != null && recentTrayLeftoverPct.isNotEmpty) {
      final usable = recentTrayLeftoverPct.where((v) => v >= 0).toList();
      if (usable.isNotEmpty) {
        final avg = usable.reduce((a, b) => a + b) / usable.length;
        return FeedingEngineV1.trayFactor(avg);
      }
    }

    return _trayFactorFromStatuses(trayStatuses);
  }

  static double _trayFactorFromStatuses(List<TrayStatus> trayStatuses) {
    if (trayStatuses.isEmpty) return 1.0;

    final leftovers = trayStatuses.map(_leftoverPctForStatus).toList();
    final avg = leftovers.reduce((a, b) => a + b) / leftovers.length;
    return FeedingEngineV1.trayFactor(avg);
  }

  /// Growth signal based on actual ABW versus expected ABW.
  /// Only active in SMART phase (DOC > 30). Before that, keep neutral.
  static double calculateGrowthFactor(double? actualAbw, int doc) {
    if (doc <= 30) return 1.0;
    if (actualAbw == null || actualAbw <= 0) return 1.0;
    final expected = getExpectedABW(doc);
    if (expected <= 0) return 1.0;

    final ratio = actualAbw / expected;
    if (ratio > 1.1) return 1.05;
    if (ratio < 0.9) return 0.95;
    return 1.0;
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

  /// Sampling confidence decay based on sample freshness.
  static double calculateSamplingFactor(
    double? actualAbw,
    int doc, {
    int sampleAgeDays = 0,
  }) {
    if (doc <= 30) return 1.0;
    if (actualAbw == null || actualAbw <= 0) return 1.0;

    final expected = getExpectedABW(doc);
    if (expected < 0.5) return 1.0;

    final ratio = actualAbw / expected;
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

  /// Environment factor from water quality.
  ///
  /// A zero factor means feeding should stop immediately.
  static double calculateEnvironmentFactor({
    required double dissolvedOxygen,
    required double ammonia,
  }) {
    if (dissolvedOxygen < 4.0) return 0.0;
    if (dissolvedOxygen < 5.0) return 0.9;
    if (ammonia > 0.2) return 0.9;
    if (ammonia > 0.1) return 0.95;
    return 1.0;
  }

  /// Combine independent factors into a raw multiplier.
  static double combineFactors({
    required double trayFactor,
    required double growthFactor,
    required double samplingFactor,
    required double environmentFactor,
  }) {
    return trayFactor * growthFactor * samplingFactor * environmentFactor;
  }

  /// Convert FCR into an additional multiplier.
  static double calculateFcrFactor(double? lastFcr) {
    return FCREngine.correction(lastFcr);
  }

  /// Apply a strict production guard to the combined factor.
  static double applyFactorGuards(double factor) {
    return factor.clamp(0.90, 1.10);
  }
}
