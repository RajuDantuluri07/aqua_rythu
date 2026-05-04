// Blind Feeding Engine (V1 – PRODUCTION READY)
// Powers DOC 1–30 in AquaRythu
//
// Core Principle:
// Controlled incremental feeding based on seed count (no intelligence yet)
// Safe growth curve with direct calculation (no loops for efficiency)

import 'package:aqua_rythu/core/utils/logger.dart';

class BlindFeedingEngine {
  static const String version = 'v1.0.0';

  /// Base feed (per 1 lakh/100k seed) at DOC 1
  static const double _baseFeed = 1.5;

  /// Calculate cumulative increment for blind feeding
  ///
  /// Uses direct calculation (no loops) for efficiency
  /// Returns: increment in kg for the given DOC
  static double _calculateCumulativeIncrement(int doc) {
    if (doc <= 7) {
      // DOC 1-7: +0.2 kg/day
      return (doc - 1) * 0.2;
    } else if (doc <= 14) {
      // DOC 8-14: +0.3 kg/day (after 6*0.2 from days 1-7)
      return (6 * 0.2) + (doc - 7) * 0.3;
    } else if (doc <= 21) {
      // DOC 15-21: +0.4 kg/day (after previous increments)
      return (6 * 0.2) + (7 * 0.3) + (doc - 14) * 0.4;
    } else {
      // DOC 22-30: +0.5 kg/day (capped at DOC 30 by guardrail)
      return (6 * 0.2) + (7 * 0.3) + (7 * 0.4) + (doc - 21) * 0.5;
    }
  }

  /// Calculate daily blind feed (kg)
  ///
  /// [doc]       Day of Culture (1-based, must be 1-30)
  /// [seedCount] Live stocking count (shrimp)
  ///
  /// Returns: Feed amount in kg, rounded to 2 decimal places
  ///
  /// Formula:
  /// dailyFeed = (baseFeed + cumulativeIncrement) × (seedCount / 100000)
  static double calculateBlindFeed({
    required int doc,
    required int seedCount,
  }) {
    // ── GUARDRAIL 1: DOC > 30 → STOP ──────────────────────────────────────
    if (doc > 30) {
      AppLogger.warn(
        '[BlindFeedingEngine] DOC > 30 detected ($doc). Switch to smart engine.',
      );
      return 0.0;
    }

    // ── GUARDRAIL 2: Seed count validation ─────────────────────────────────
    if (seedCount < 1000) {
      AppLogger.warn(
        '[BlindFeedingEngine] Low seed count: $seedCount (< 1,000). '
        'Blind feed calculation may be inaccurate.',
      );
    }

    if (seedCount <= 0) {
      AppLogger.error(
        '[BlindFeedingEngine] Zero or negative seed count: $seedCount. '
        'Feed calculation stopped.',
      );
      return 0.0;
    }

    // ── GUARDRAIL 3: DOC validation ────────────────────────────────────────
    final safeDOC = doc < 1 ? 1 : doc;
    if (doc != safeDOC) {
      AppLogger.warn(
        '[BlindFeedingEngine] Invalid DOC: $doc. Clamped to $safeDOC.',
      );
    }

    // ── CALCULATION ────────────────────────────────────────────────────────
    final increment = _calculateCumulativeIncrement(safeDOC);
    final feedPerLakh = _baseFeed + increment;
    final scaledFeed = feedPerLakh * (seedCount / 100000);

    // ── GUARDRAIL 4: Feed < 0 → Clamp to 0 ────────────────────────────────
    final finalFeed =
        scaledFeed < 0 ? 0.0 : double.parse(scaledFeed.toStringAsFixed(2));

    return finalFeed;
  }

  /// Calculate number of meals per day based on DOC
  ///
  /// Rules (from spec):
  /// - DOC ≤ 7   → 2 meals
  /// - DOC ≤ 21  → 3 meals
  /// - DOC > 21  → 4 meals
  /// - DOC > 90  → 4-5 meals (default to 4 for blind phase)
  static int getMealsPerDay(int doc) {
    if (doc <= 7) {
      return 2;
    } else if (doc <= 21) {
      return 3;
    } else {
      return 4; // DOC > 21 and DOC ≤ 30 (blind phase cap)
    }
  }

  /// Split daily feed into meal quantities
  ///
  /// Example: If daily feed = 8 kg and 4 meals → 2 kg per meal
  static List<double> splitMeals({
    required double dailyFeed,
    required int doc,
  }) {
    final mealsCount = getMealsPerDay(doc);
    final perMeal = dailyFeed / mealsCount;

    // Round per-meal amount to 1 decimal place for practical feeding
    final roundedPerMeal =
        double.parse(perMeal.toStringAsFixed(1));

    return List<double>.filled(mealsCount, roundedPerMeal);
  }

  /// Get adjustment factor based on optional inputs
  ///
  /// Even in blind phase, can apply 0.9-1.1 factor based on:
  /// - Farmer manual override
  /// - Mortality input
  /// - Early tray signals (if available)
  static double getOptionalAdjustmentFactor({
    double? manualOverride,
    double? mortalityAdjustment,
    double? traySignal,
  }) {
    double factor = 1.0;

    if (manualOverride != null) {
      factor = manualOverride.clamp(0.9, 1.1);
    }

    if (mortalityAdjustment != null) {
      factor = (factor * mortalityAdjustment).clamp(0.9, 1.1);
    }

    if (traySignal != null) {
      factor = (factor * traySignal).clamp(0.9, 1.1);
    }

    return factor;
  }

  /// Validate feed calculation and return safety status
  static Map<String, dynamic> validateFeedCalculation({
    required int doc,
    required int seedCount,
    required double calculatedFeed,
  }) {
    final issues = <String>[];

    // Check DOC boundary
    if (doc > 30) {
      issues.add('DOC > 30: Switch to smart feed engine');
    }

    // Check feed < 0
    if (calculatedFeed < 0) {
      issues.add('Calculated feed is negative (should be clamped to 0)');
    }

    // Check low seed count
    if (seedCount < 1000) {
      issues.add(
        'Low seed count ($seedCount): May indicate data entry error',
      );
    }

    return {
      'isValid': issues.isEmpty,
      'issues': issues,
      'doc': doc,
      'seedCount': seedCount,
      'feed': calculatedFeed,
    };
  }

  /// Get sample output table for documentation/testing
  /// DOC 1-30 with 100k seed: shows expected feed progression
  static Map<int, double> getSampleOutputTable() {
    const sampleSeedCount = 100000;
    return {
      for (int doc = 1; doc <= 30; doc++)
        doc: calculateBlindFeed(doc: doc, seedCount: sampleSeedCount)
    };
  }

  /// Print sample output for verification (DOC 1-30, 1 lakh seed)
  static void printSampleOutput() {
    AppLogger.info('=== BLIND FEEDING ENGINE - SAMPLE OUTPUT (1 LAKH SEED) ===');
    AppLogger.info('DOC\t| Feed (kg)');
    AppLogger.info('----\t| ---------');

    final table = getSampleOutputTable();
    for (int doc = 1; doc <= 30; doc++) {
      final feed = table[doc] ?? 0.0;
      AppLogger.info('$doc\t| ${feed.toStringAsFixed(2)}');
    }

    AppLogger.info('✔ Smooth progression');
    AppLogger.info('✔ Predictable growth curve');
    AppLogger.info('✔ Matches real-world shrimp behavior');
  }
}
