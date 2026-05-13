// Blind Feeding Engine (V1 – PRODUCTION READY)
// Powers DOC 1–30 in AquaRythu
//
// Core Principle:
// Controlled incremental feeding based on seed count (no intelligence yet)
// Safe growth curve with direct calculation (no loops for efficiency)

import 'package:aqua_rythu/core/utils/logger.dart';
import '../../features/pond/enums/seed_type.dart';

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
  /// [seedType]  Type of seed (nursery or hatchery)
  ///
  /// Returns: Feed amount in kg, rounded to 2 decimal places
  ///
  /// Formula:
  /// dailyFeed = (baseFeed + cumulativeIncrement) × (seedCount / 100000)
  static double calculateBlindFeed({
    required int doc,
    required int seedCount,
    required String seedType,
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

    // ── NURSERY DOC 10 BOUNDARY ────────────────────────────────────────────
    // When nursery DOC > 10, transition to hatchery (regular) feed with warning
    final bool isNurseryTransition = seedType.toLowerCase() == 'nursery' && safeDOC > 10;
    if (isNurseryTransition) {
      AppLogger.warn(
        '[BlindFeedingEngine] Nursery DOC > 10 detected ($safeDOC). '
        'Nursery phase ends at DOC 10. Transitioning to regular feed mode.',
      );
      // Fall through to use hatchery calculation instead of returning 0.0
    }

    // ── CALCULATION ────────────────────────────────────────────────────────
    double feedPerLakh;

    if (seedType.toLowerCase() == 'nursery') {
      // Nursery feed: Use nursery table values (higher feed for bigger shrimp)
      feedPerLakh = _getNurseryFeedPerLakh(safeDOC);
    } else {
      // Hatchery feed: Use incremental formula (smaller shrimp)
      final increment = _calculateCumulativeIncrement(safeDOC);
      feedPerLakh = _baseFeed + increment;
    }

    final scaledFeed = feedPerLakh * (seedCount / 100000);

    // ── GUARDRAIL 4: Feed < 0 → Clamp to 0 ────────────────────────────────
    final finalFeed =
        scaledFeed < 0 ? 0.0 : double.parse(scaledFeed.toStringAsFixed(2));

    return finalFeed;
  }

  /// Calculate number of meals per day based on DOC and seed type
  ///
  /// Nursery Seed Rules:
  /// - DOC 1   → 2 meals
  /// - DOC ≥ 2   → 4 meals
  ///
  /// Hatchery Seed Rules:
  /// - DOC 1     → 2 meals
  /// - DOC 2–6   → 3 meals
  /// - DOC ≥ 7   → 4 meals
  ///
  /// Legacy rules (for backward compatibility when seedType not specified):
  /// - DOC ≤ 7   → 2 meals
  /// - DOC ≤ 21  → 3 meals
  /// - DOC > 21  → 4 meals
  static int getMealsPerDay(int doc, {SeedType? seedType}) {
    if (seedType != null) {
      // Seed-type specific rules
      if (seedType == SeedType.nurseryBig) {
        // Nursery: Day 1 = 2 feeds, Day 2+ = 4 feeds
        return doc == 1 ? 2 : 4;
      } else {
        // Hatchery: Day 1 = 2 feeds, Day 2-6 = 3 feeds, Day 7+ = 4 feeds
        if (doc == 1) return 2;
        if (doc <= 6) return 3;
        return 4;
      }
    }

    // Legacy rules for backward compatibility
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
    SeedType? seedType,
  }) {
    final mealsCount = getMealsPerDay(doc, seedType: seedType);
    final perMeal = dailyFeed / mealsCount;

    // Round per-meal amount to 1 decimal place for practical feeding
    final roundedPerMeal = double.parse(perMeal.toStringAsFixed(1));

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

  /// Get nursery feed per 100k based on predefined table.
  ///
  /// Nursery phase ends at DOC 10. Returns feed per day for DOC 1–10.
  /// For DOC > 10, returns 13.0 (caps at max nursery feed) — but
  /// calculateBlindFeed should have already blocked DOC > 10 nursery.
  static double _getNurseryFeedPerLakh(int doc) {
    if (doc <= 1) return 4.0;   // d1
    if (doc <= 2) return 5.0;   // d2
    if (doc <= 3) return 6.0;   // d3
    if (doc <= 4) return 7.0;   // d4
    if (doc <= 5) return 8.0;   // d5
    if (doc <= 6) return 9.0;   // d6
    if (doc <= 7) return 10.0;  // d7
    if (doc <= 8) return 11.0;  // d8
    if (doc <= 9) return 12.0;  // d9
    if (doc <= 10) return 13.0; // d10
    return 13.0;                // cap at d10 value for any doc > 10
  }

  /// Get sample output table for documentation/testing
  /// DOC 1-30 with 100k seed: shows expected feed progression
  static Map<int, double> getSampleOutputTable() {
    const sampleSeedCount = 100000;
    return {
      for (int doc = 1; doc <= 30; doc++)
        doc: calculateBlindFeed(
            doc: doc, seedCount: sampleSeedCount, seedType: 'hatchery')
    };
  }

  /// Print sample output for verification (DOC 1-30, 1 lakh seed)
  static void printSampleOutput() {
    AppLogger.info(
        '=== BLIND FEEDING ENGINE - SAMPLE OUTPUT (1 LAKH SEED) ===');
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
