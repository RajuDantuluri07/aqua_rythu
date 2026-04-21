import '../../features/feed/models/feed_input.dart';
import '../utils/logger.dart';

/// Validates FeedInput before pipeline processing.
///
/// Policy: log warnings for out-of-range data; log errors for corrupt data
/// (NaN/Infinite). Never throw — the engine's own clamping is the safety net.
/// Throwing here was causing silent feed failures when exceptions were swallowed
/// upstream, which is worse than continuing with a logged warning.
class FeedInputValidator {
  static void validate(FeedInput input) {
    // ── seedCount ────────────────────────────────────────────────────────────
    // BUG-12: previous max was 10M — far too high for AP coastal ponds.
    // Engine clamps to [1000, 1_000_000] in computeWithDebug, so out-of-range
    // inputs won't produce runaway feed values. Just warn here.
    if (input.seedCount < 1000) {
      AppLogger.warn(
        'FeedInput.seedCount=${input.seedCount} below minimum (1,000). '
        'Engine will clamp — verify pond data.',
      );
    } else if (input.seedCount > 500000) {
      AppLogger.warn(
        'FeedInput.seedCount=${input.seedCount} exceeds 500,000. '
        'Possible typo (e.g. 1,00,000 vs 1,00,000). Engine will clamp.',
      );
    }

    // ── DOC ──────────────────────────────────────────────────────────────────
    // Engine clamps DOC to [1, FeedConfig.maxDoc] in computeWithDebug.
    if (input.doc < 1 || input.doc > 180) {
      AppLogger.warn(
        'FeedInput.doc=${input.doc} outside [1, 180]. '
        'Engine will clamp — verify stocking date.',
      );
    }

    // ── ABW ──────────────────────────────────────────────────────────────────
    if (input.abw != null) {
      if (input.abw!.isNaN || input.abw!.isInfinite) {
        AppLogger.error(
          'FeedInput.abw is ${input.abw} — sampling data corrupted. '
          'Pipeline will treat ABW as absent.',
        );
      } else if (input.abw! < 0 || input.abw! > 1000) {
        AppLogger.warn(
          'FeedInput.abw=${input.abw} outside [0, 1000] g. '
          'Verify sampling record.',
        );
      }
    }

    // ── feedingScore ─────────────────────────────────────────────────────────
    if (input.feedingScore.isNaN || input.feedingScore.isInfinite) {
      AppLogger.error('FeedInput.feedingScore is ${input.feedingScore} — data corrupted.');
    } else if (input.feedingScore < 0 || input.feedingScore > 5) {
      AppLogger.warn(
        'FeedInput.feedingScore=${input.feedingScore} outside [0, 5]. '
        'Expected 0–5 scale.',
      );
    }

    // ── intakePercent ─────────────────────────────────────────────────────────
    if (input.intakePercent.isNaN || input.intakePercent.isInfinite) {
      AppLogger.error('FeedInput.intakePercent is ${input.intakePercent} — data corrupted.');
    } else if (input.intakePercent < 0 || input.intakePercent > 100) {
      AppLogger.warn(
        'FeedInput.intakePercent=${input.intakePercent} outside [0, 100]%.',
      );
    }

    // ── dissolvedOxygen ──────────────────────────────────────────────────────
    // Critical for stop-feeding logic — log as error so it's visible in monitoring.
    if (input.dissolvedOxygen.isNaN || input.dissolvedOxygen.isInfinite) {
      AppLogger.error(
        'FeedInput.dissolvedOxygen is ${input.dissolvedOxygen} — sensor failure. '
        'SmartFeedEngineV2 will apply conservative water factor.',
      );
    } else if (input.dissolvedOxygen < 0 || input.dissolvedOxygen > 20) {
      AppLogger.warn(
        'FeedInput.dissolvedOxygen=${input.dissolvedOxygen} ppm outside [0, 20]. '
        'Possible sensor error.',
      );
    }

    // ── temperature ──────────────────────────────────────────────────────────
    if (input.temperature.isNaN || input.temperature.isInfinite) {
      AppLogger.error('FeedInput.temperature is ${input.temperature} — sensor failure.');
    } else if (input.temperature < 10 || input.temperature > 40) {
      AppLogger.warn(
        'FeedInput.temperature=${input.temperature}°C outside aquaculture range [10, 40].',
      );
    }

    // ── phChange ─────────────────────────────────────────────────────────────
    if (input.phChange.isNaN || input.phChange.isInfinite) {
      AppLogger.error('FeedInput.phChange is ${input.phChange} — data corrupted.');
    } else if (input.phChange < -2 || input.phChange > 2) {
      AppLogger.warn(
        'FeedInput.phChange=${input.phChange} outside [-2, 2]. '
        'Typical range is ±0.5.',
      );
    }

    // ── ammonia ──────────────────────────────────────────────────────────────
    if (input.ammonia.isNaN || input.ammonia.isInfinite) {
      AppLogger.error('FeedInput.ammonia is ${input.ammonia} — data corrupted.');
    } else if (input.ammonia < 0 || input.ammonia > 5) {
      AppLogger.warn(
        'FeedInput.ammonia=${input.ammonia} ppm outside [0, 5].',
      );
    }

    // ── mortality ────────────────────────────────────────────────────────────
    if (input.mortality < 0) {
      AppLogger.warn('FeedInput.mortality=${input.mortality} is negative — treating as 0.');
    } else if (input.mortality > input.seedCount) {
      AppLogger.error(
        'FeedInput.mortality=${input.mortality} exceeds seedCount=${input.seedCount}. '
        'Data entry error.',
      );
    } else if (input.seedCount > 0 && input.mortality > input.seedCount * 0.1) {
      AppLogger.warn(
        'FeedInput.mortality=${input.mortality} '
        '(${(input.mortality / input.seedCount * 100).toStringAsFixed(1)}% of stock) '
        'exceeds 10% daily — verify record.',
      );
    }

    // ── trayStatuses ─────────────────────────────────────────────────────────
    // Empty for DOC ≤ 30 (blind phase) is expected.
    // Empty for DOC > 30 is valid for new ponds; engine uses neutral factor (1.0).

    // ── lastFcr ──────────────────────────────────────────────────────────────
    if (input.lastFcr != null) {
      if (input.lastFcr!.isNaN || input.lastFcr!.isInfinite) {
        AppLogger.error('FeedInput.lastFcr is ${input.lastFcr} — historical data corrupted.');
      } else if (input.lastFcr! < 0.5 || input.lastFcr! > 5) {
        AppLogger.warn(
          'FeedInput.lastFcr=${input.lastFcr} outside [0.5, 5]. '
          'Typical range is 1.2–1.4.',
        );
      }
    }

    // ── actualFeedYesterday ──────────────────────────────────────────────────
    if (input.actualFeedYesterday != null) {
      if (input.actualFeedYesterday!.isNaN || input.actualFeedYesterday!.isInfinite) {
        AppLogger.error('FeedInput.actualFeedYesterday is ${input.actualFeedYesterday} — corrupted.');
      } else if (input.actualFeedYesterday! < 0) {
        AppLogger.warn(
          'FeedInput.actualFeedYesterday=${input.actualFeedYesterday} is negative.',
        );
      } else if (input.actualFeedYesterday! > 500) {
        AppLogger.warn(
          'FeedInput.actualFeedYesterday=${input.actualFeedYesterday} kg exceeds 500 kg. '
          'Check for unit error.',
        );
      }
    }
  }

  /// Validate pipeline output is within reasonable ranges.
  /// Logs warnings instead of throwing — the engine already applied safety caps,
  /// so a throw here would crash valid pipelines (e.g. aggressive tray correction).
  static void validateOutput(double recommendedFeed, double baseFeed) {
    if (recommendedFeed.isNaN) {
      AppLogger.error('Output validation: recommendedFeed is NaN — pipeline error.');
      return;
    }
    if (recommendedFeed.isInfinite) {
      AppLogger.error('Output validation: recommendedFeed is Infinite — pipeline error.');
      return;
    }
    if (recommendedFeed < 0) {
      AppLogger.error(
        'Output validation: recommendedFeed=$recommendedFeed is negative — pipeline error.',
      );
      return;
    }
    if (recommendedFeed > 10000) {
      AppLogger.error(
        'Output validation: recommendedFeed=$recommendedFeed kg exceeds physical limit.',
      );
      return;
    }

    if (baseFeed > 0) {
      final lowerBound = baseFeed * 0.5;
      final upperBound = baseFeed * 1.5;
      if (recommendedFeed < lowerBound) {
        AppLogger.warn(
          'Output validation: recommendedFeed=${recommendedFeed.toStringAsFixed(2)} kg '
          'is below 50% of base=${baseFeed.toStringAsFixed(2)} kg. '
          'Critical condition (DO/ammonia) may be active.',
        );
      } else if (recommendedFeed > upperBound) {
        AppLogger.warn(
          'Output validation: recommendedFeed=${recommendedFeed.toStringAsFixed(2)} kg '
          'exceeds 150% of base=${baseFeed.toStringAsFixed(2)} kg. '
          'Check FCR/tray correction stacking.',
        );
      }
    }
  }
}
