import '../engines/models/feed_input.dart';

/// Validator for FeedInput to catch invalid data before processing.
/// Prevents NaN, negative values, and out-of-range inputs.
class FeedInputValidator {
  /// Validate all FeedInput fields
  /// Throws Exception with descriptive message if validation fails
  static void validate(FeedInput input) {
    // Seed count validation
    // BUG-12 fix: previous max was 10M — far too high for AP coastal ponds.
    // Realistic range: 1,000 (minimum viable) → 500,000 (max stocking density).
    // A typo of 1,000,000 instead of 100,000 (easy on phone keypad) previously
    // produced 20 kg/round — catastrophic overfeed with no guard.
    if (input.seedCount < 1000) {
      throw Exception(
        "Invalid seedCount: ${input.seedCount}. Minimum stocking is 1,000 shrimp",
      );
    }
    if (input.seedCount > 500000) {
      throw Exception(
        "Invalid seedCount: ${input.seedCount}. "
        "Exceeds maximum supported stocking density (500,000 per pond). "
        "Check for a typo — e.g., 1,00,000 instead of 1,00,000.",
      );
    }

    // DOC (Days of Culture) validation
    if (input.doc < 1 || input.doc > 180) {
      throw Exception(
        "Invalid doc: ${input.doc}. Must be between 1-180 days",
      );
    }

    // ABW (Average Body Weight) validation if provided
    if (input.abw != null) {
      if (input.abw!.isNaN) {
        throw Exception("Invalid abw: NaN - Sampling data is corrupted");
      }
      if (input.abw! < 0 || input.abw! > 1000) {
        throw Exception(
          "Invalid abw: ${input.abw}. Must be between 0-1000 grams",
        );
      }
    }

    // Feeding score validation
    if (input.feedingScore.isNaN) {
      throw Exception("Invalid feedingScore: NaN");
    }
    if (input.feedingScore < 0 || input.feedingScore > 5) {
      throw Exception(
        "Invalid feedingScore: ${input.feedingScore}. Must be 0-5 scale (e.g., 3.5)",
      );
    }

    // Intake percent validation
    if (input.intakePercent.isNaN) {
      throw Exception("Invalid intakePercent: NaN");
    }
    if (input.intakePercent < 0 || input.intakePercent > 100) {
      throw Exception(
        "Invalid intakePercent: ${input.intakePercent}. Must be 0-100%",
      );
    }

    // Dissolved oxygen validation
    if (input.dissolvedOxygen.isNaN) {
      throw Exception("Invalid dissolvedOxygen: NaN - Check sensor reading");
    }
    if (input.dissolvedOxygen < 0 || input.dissolvedOxygen > 20) {
      throw Exception(
        "Invalid dissolvedOxygen: ${input.dissolvedOxygen} ppm. Must be 0-20 ppm",
      );
    }

    // Temperature validation
    if (input.temperature.isNaN) {
      throw Exception("Invalid temperature: NaN");
    }
    if (input.temperature < 10 || input.temperature > 40) {
      throw Exception(
        "Invalid temperature: ${input.temperature}°C. Beyond aquaculture range (10-40°C)",
      );
    }

    // pH change validation
    if (input.phChange.isNaN) {
      throw Exception("Invalid phChange: NaN");
    }
    if (input.phChange < -2 || input.phChange > 2) {
      throw Exception(
        "Invalid phChange: ${input.phChange}. Unrealistic pH swing (typical ±0.5)",
      );
    }

    // Ammonia validation
    if (input.ammonia.isNaN) {
      throw Exception("Invalid ammonia: NaN");
    }
    if (input.ammonia < 0 || input.ammonia > 5) {
      throw Exception(
        "Invalid ammonia: ${input.ammonia} ppm. Must be 0-5 ppm",
      );
    }

    // Mortality validation
    if (input.mortality < 0) {
      throw Exception(
        "Invalid mortality: ${input.mortality}. Cannot be negative",
      );
    }
    if (input.mortality > input.seedCount) {
      throw Exception(
        "Invalid mortality: ${input.mortality}. Exceeds seedCount (${input.seedCount})",
      );
    }
    // Max reasonable: 10% of population per day
    if (input.mortality > input.seedCount * 0.1) {
      throw Exception(
        "Invalid mortality: ${input.mortality} (${(input.mortality / input.seedCount * 100).toStringAsFixed(1)}%). "
        "Exceeds 10% population - check for data entry error",
      );
    }

    // Tray statuses validation
    // ✅ Allow empty trays for DOC ≤ 30 (blind feeding)
    // ✅ In smart mode, either a current tray log or valid recent tray history
    //    is required. Sentinel values like [-1.0] do not count as tray data.
    final hasValidRecentTrayHistory =
        input.recentTrayLeftoverPct.any((value) => value >= 0);
    if (input.trayStatuses.isEmpty &&
        input.doc > 30 &&
        !hasValidRecentTrayHistory) {
      throw Exception("Invalid trayStatuses: Empty list and no recent tray history available");
    }

    // FCR validation if provided
    if (input.lastFcr != null) {
      if (input.lastFcr!.isNaN) {
        throw Exception("Invalid lastFcr: NaN - Historical data corrupted");
      }
      if (input.lastFcr! < 0.5 || input.lastFcr! > 5) {
        throw Exception(
          "Invalid lastFcr: ${input.lastFcr}. Must be 0.5-5 (typical 1.2-1.4)",
        );
      }
    }

    // Yesterday's actual feed validation if provided
    if (input.actualFeedYesterday != null) {
      if (input.actualFeedYesterday!.isNaN) {
        throw Exception("Invalid actualFeedYesterday: NaN");
      }
      if (input.actualFeedYesterday! < 0) {
        throw Exception(
          "Invalid actualFeedYesterday: ${input.actualFeedYesterday} - Cannot be negative",
        );
      }
      // Max reasonable: 500kg for a single day (large intensive farm)
      if (input.actualFeedYesterday! > 500) {
        throw Exception(
          "Invalid actualFeedYesterday: ${input.actualFeedYesterday} kg - "
          "Exceeds typical daily feed (check for unit error or data corruption)",
        );
      }
    }
  }

  /// Validate output is within reasonable ranges
  /// Called after MasterFeedEngine.run() to catch calculation errors
  static void validateOutput(double recommendedFeed, double baseFeed) {
    if (recommendedFeed.isNaN) {
      throw Exception("Output validation failed: recommendedFeed is NaN");
    }
    if (recommendedFeed.isInfinite) {
      throw Exception("Output validation failed: recommendedFeed is Infinite");
    }
    if (recommendedFeed < 0) {
      throw Exception("Output validation failed: recommendedFeed is negative ($recommendedFeed)");
    }
    if (recommendedFeed > 10000) {
      throw Exception(
        "Output validation failed: recommendedFeed ($recommendedFeed kg) "
        "exceeds physical delivery limit - Check calculation error",
      );
    }

    // Check that output is within safety bounds relative to base
    final lowerBound = baseFeed * 0.5;  // Can't go below 50%
    final upperBound = baseFeed * 1.5;  // Can't go above 150%
    if (recommendedFeed < lowerBound) {
      throw Exception(
        "Output validation warning: recommendedFeed (${recommendedFeed.toStringAsFixed(2)} kg) "
        "below 50% of base (${baseFeed.toStringAsFixed(2)} kg). "
        "Check if critical conditions (DO < 4, high ammonia) are being masked.",
      );
    }
    if (recommendedFeed > upperBound) {
      throw Exception(
        "Output validation warning: recommendedFeed (${recommendedFeed.toStringAsFixed(2)} kg) "
        "exceeds 150% of base (${baseFeed.toStringAsFixed(2)} kg). "
        "Check FCR/tray bonus stacking.",
      );
    }
  }
}
