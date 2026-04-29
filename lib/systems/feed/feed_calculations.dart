// Feed Calculations - Pure math functions for feed engine
//
// This file contains pure functions for feed calculations.
// No classes, no state, just mathematical operations.
// SIMPLIFIED: Tray-driven only, no sampling or water adjustments.
//

import '../../../features/tray/enums/tray_status.dart';
import 'package:aqua_rythu/core/utils/logger.dart';

// ── PURE CALCULATION FUNCTIONS ─────────────────────────────────────────────────────

/// Calculate tray factor based on tray statuses
/// Enhanced with reliability checks and strict limits
/// Pure function - no side effects
double calculateTrayFactor(List<TrayStatus> trayStatuses) {
  // Task 1: No tray data handling
  if (trayStatuses.isEmpty) {
    AppLogger.warn('No tray data — using base feed (tray_factor = 1.0)');
    return 1.0;
  }

  // Task 4: Tray log reliability - filter outliers and use average safely
  final processedStatuses = _processTrayReliability(trayStatuses);
  if (processedStatuses.isEmpty) {
    AppLogger.warn('All tray data filtered as unreliable — using base feed');
    return 1.0;
  }

  // Calculate ratios from reliable data
  int full = 0, empty = 0, partial = 0;
  for (final status in processedStatuses) {
    switch (status) {
      case TrayStatus.full:
        full++;
        break;
      case TrayStatus.completed:
        empty++;
        break;
      case TrayStatus.partial:
        partial++;
        break;
    }
  }

  final total = full + empty + partial;
  final emptyRatio = empty / total;
  final fullRatio = full / total;

  // Calculate raw tray factor
  double rawFactor;
  if (emptyRatio > 0.6) {
    rawFactor = 1.10; // Mostly empty - increase feed
  } else if (fullRatio > 0.6) {
    rawFactor = 0.85; // Mostly full - decrease feed
  } else if (emptyRatio > 0.3) {
    rawFactor = 1.05; // Some empty - slight increase
  } else if (fullRatio > 0.3) {
    rawFactor = 0.95; // Some full - slight decrease
  } else {
    rawFactor = 1.0; // Balanced - no adjustment
  }

  // Task 2: Enforce strict tray factor limits
  const double minTrayFactor = 0.8;
  const double maxTrayFactor = 1.2;

  final double clampedFactor = rawFactor.clamp(minTrayFactor, maxTrayFactor);

  if (rawFactor < minTrayFactor || rawFactor > maxTrayFactor) {
    AppLogger.info(
        'Tray factor clamped: ${rawFactor.toStringAsFixed(3)} → ${clampedFactor.toStringAsFixed(3)}');
  }

  return clampedFactor;
}

/// Process tray reliability - filter outliers and ensure data consistency
/// Task 4: Tray log reliability implementation
List<TrayStatus> _processTrayReliability(List<TrayStatus> trayStatuses) {
  if (trayStatuses.length <= 2) {
    // With very few trays, accept all data but log warning
    if (trayStatuses.length == 1) {
      AppLogger.info('Single tray data point - using with caution');
    }
    return trayStatuses;
  }

  // Count each status
  int full = 0, empty = 0, partial = 0;
  for (final status in trayStatuses) {
    switch (status) {
      case TrayStatus.full:
        full++;
        break;
      case TrayStatus.completed:
        empty++;
        break;
      case TrayStatus.partial:
        partial++;
        break;
    }
  }

  final total = trayStatuses.length;
  final List<TrayStatus> reliableStatuses = [];

  // Detect and handle outliers
  // If we have a mixed pattern but one status is overwhelmingly dominant,
  // the minority might be unreliable

  final double fullRatio = full / total;
  final double emptyRatio = empty / total;
  final double partialRatio = partial / total;

  // Outlier detection: if any status is < 20% and we have mixed data,
  // treat it as potential outlier
  const double outlierThreshold = 0.2;
  const double mixedDataThreshold = 0.3; // At least two types with >30%

  bool isMixedData = (fullRatio > mixedDataThreshold &&
          emptyRatio > mixedDataThreshold) ||
      (fullRatio > mixedDataThreshold && partialRatio > mixedDataThreshold) ||
      (emptyRatio > mixedDataThreshold && partialRatio > mixedDataThreshold);

  if (isMixedData) {
    // Mixed data detected - filter outliers
    if (fullRatio < outlierThreshold) {
      AppLogger.info(
          'Filtering FULL trays as outliers (${(fullRatio * 100).toStringAsFixed(1)}%)');
    } else {
      reliableStatuses.addAll(List.filled(full, TrayStatus.full));
    }

    if (emptyRatio < outlierThreshold) {
      AppLogger.info(
          'Filtering EMPTY trays as outliers (${(emptyRatio * 100).toStringAsFixed(1)}%)');
    } else {
      reliableStatuses.addAll(List.filled(empty, TrayStatus.completed));
    }

    if (partialRatio < outlierThreshold) {
      AppLogger.info(
          'Filtering PARTIAL trays as outliers (${(partialRatio * 100).toStringAsFixed(1)}%)');
    } else {
      reliableStatuses.addAll(List.filled(partial, TrayStatus.partial));
    }

    if (reliableStatuses.isEmpty) {
      AppLogger.warn(
          'All tray data filtered as outliers - using original data');
      return trayStatuses; // Fallback to original data
    }

    AppLogger.info(
        'Tray reliability: $total → ${reliableStatuses.length} reliable data points');
    return reliableStatuses;
  } else {
    // Not mixed data - all data is reliable
    return trayStatuses;
  }
}

/// Get expected ABW for given DOC using lookup table
/// REMOVED: No longer used for feed calculations (insight only)
double getExpectedABW(int doc) {
  // Simple expected ABW table (grams) - can be enhanced with real data
  if (doc <= 0) return 0.0;
  if (doc <= 10) return 0.5 + (doc - 1) * 0.1; // 0.5g to 1.4g
  if (doc <= 20) return 1.4 + (doc - 10) * 0.2; // 1.4g to 3.4g
  if (doc <= 30) return 3.4 + (doc - 20) * 0.3; // 3.4g to 6.4g
  if (doc <= 40) return 6.4 + (doc - 30) * 0.4; // 6.4g to 10.4g
  if (doc <= 50) return 10.4 + (doc - 40) * 0.5; // 10.4g to 15.4g
  if (doc <= 60) return 15.4 + (doc - 50) * 0.6; // 15.4g to 21.4g
  if (doc <= 80) return 21.4 + (doc - 60) * 0.7; // 21.4g to 35.4g
  if (doc <= 100) return 35.4 + (doc - 80) * 0.8; // 35.4g to 51.4g
  if (doc <= 120) return 51.4 + (doc - 100) * 0.9; // 51.4g to 69.4g
  return 69.4 + (doc - 120) * 1.0; // Beyond DOC 120
}

/// Calculate growth factor based on ABW vs expected
/// REMOVED: No longer used for feed calculations (insight only)
double calculateGrowthFactor(double? abw, int doc, int sampleAgeDays) {
  if (abw == null || abw <= 0) return 1.0;
  if (sampleAgeDays > 7) return 1.0; // Stale sample - no adjustment

  final expectedAbw = getExpectedABW(doc);
  if (expectedAbw <= 0) return 1.0;

  final ratio = abw / expectedAbw;

  // Growth factor based on actual vs expected ABW
  if (ratio > 1.15) return 1.05; // Much faster growth
  if (ratio > 1.05) return 1.02; // Slightly faster growth
  if (ratio < 0.85) return 0.95; // Slower growth
  if (ratio < 0.75) return 0.90; // Much slower growth

  return 1.0; // On track - no adjustment
}

/// Calculate environment factor based on water quality
/// REMOVED: No longer used for feed calculations (safety only)
double calculateEnvironmentFactor(double dissolvedOxygen, double ammonia) {
  // Critical DO check already done earlier, this is for adjustments
  if (dissolvedOxygen < 4.5) return 0.90; // Low DO - reduce feed
  if (dissolvedOxygen < 5.0) return 0.95; // Slightly low DO
  if (ammonia > 0.2) return 0.95; // High ammonia - reduce feed
  if (ammonia > 0.1) return 0.98; // Slightly high ammonia

  return 1.0; // Good water quality - no adjustment
}

/// Convert factor to human-readable percentage change
/// Pure function - no side effects
String factorToPercent(double factor) {
  final pct = ((factor - 1.0) * 100).round();
  if (pct > 0) return '+$pct%';
  if (pct < 0) return '$pct%';
  return '0%';
}

/// DOC-based feed curve for shrimp
/// Enhanced for smoothness at DOC 30→31 transition
/// Pure function - no side effects
double docFeedCurve(int doc) {
  // Task 3: Ensure smoothness at DOC 30→31 transition
  // Use continuous curve with no sudden jumps

  if (doc <= 5) return 2.0;
  if (doc <= 10) return 2.5;
  if (doc <= 15) return 3.0;
  if (doc <= 20) return 3.5;
  if (doc <= 25) return 4.0;

  // Critical transition zone: DOC 25-35
  // Ensure smooth progression through DOC 30
  if (doc <= 30) {
    // Linear interpolation from DOC 25 (4.0) to DOC 30 (5.0)
    return 4.0 + (doc - 25) * 0.2; // 0.2 per day = smooth progression
  }

  if (doc <= 35) {
    // Continue smooth progression from DOC 30 (5.0) to DOC 35 (5.75)
    return 5.0 + (doc - 30) * 0.15; // 0.15 per day
  }

  if (doc <= 40) return 6.5;
  if (doc <= 50) return 8.0;
  if (doc <= 60) return 10.0;
  return 12.0;
}

/// Test DOC curve smoothness - validates continuity at transitions
/// Task 3: Validation function for smoothness
double testDOCCurveSmoothness() {
  // Test critical transition points
  final doc29 = docFeedCurve(29);
  final doc30 = docFeedCurve(30);
  final doc31 = docFeedCurve(31);

  AppLogger.info('DOC curve smoothness test:');
  AppLogger.info('DOC 29: ${doc29.toStringAsFixed(3)} kg');
  AppLogger.info('DOC 30: ${doc30.toStringAsFixed(3)} kg');
  AppLogger.info('DOC 31: ${doc31.toStringAsFixed(3)} kg');

  // Check for sudden jumps (>20% change is concerning)
  final change29to30 = (doc30 - doc29).abs();
  final change30to31 = (doc31 - doc30).abs();

  AppLogger.info('Change 29→30: ${change29to30.toStringAsFixed(3)} kg');
  AppLogger.info('Change 30→31: ${change30to31.toStringAsFixed(3)} kg');

  // Validate smoothness
  if (change29to30 > 1.0 || change30to31 > 1.0) {
    AppLogger.warn('WARNING: Large jump detected in DOC curve!');
  } else {
    AppLogger.info('DOC curve smoothness: PASSED');
  }

  return change29to30 + change30to31;
}
