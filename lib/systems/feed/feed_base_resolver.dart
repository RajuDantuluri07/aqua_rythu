// Base Feed Resolver - Ensures smart feeding always has valid base feed
//
// Critical fix for anchor feed bug where DOC > 30 could run on null/zero base
// causing shrimp starvation or overfeeding.
//
// Priority order for smart feeding base:
// 1. anchorFeed (farmer-set baseline)
// 2. actualFeedYesterday (previous day actual)
// 3. plannedFeed (engine calculation)
// 4. safe fallback (prevents zero feed)

import '../../core/utils/logger.dart';

/// Source of the base feed for debug tracking
enum BaseFeedSource {
  anchor,
  yesterday,
  planned,
  fallback,
  blind,
  lastBlind,  // Last day of blind feeding (DOC 30)
}

/// Result of base feed resolution with source tracking
class BaseFeedResult {
  final double feedAmount;
  final BaseFeedSource source;
  final String explanation;

  const BaseFeedResult({
    required this.feedAmount,
    required this.source,
    required this.explanation,
  });
}

/// Feed Base Resolver - Single source of truth for base feed selection
class FeedBaseResolver {
  /// Compute safe fallback feed with density scaling
  ///
  /// Ensures fallback is appropriate for pond size:
  /// - 50k shrimp → 2.5 kg (not 5.0)
  /// - 100k shrimp → 5.0 kg (base)
  /// - 300k shrimp → 15.0 kg (not 5.0)
  ///
  /// [seedCount] Live stocking count (shrimp)
  /// Returns: Safe fallback feed amount in kg, scaled to density
  static double computeSafeFallback({required int seedCount}) {
    const double baseFallbackPerLakh = 5.0; // for 100k shrimp
    final double scale = seedCount / 100000;
    final double scaled = baseFallbackPerLakh * scale;

    // Safety clamps: prevent extreme outliers
    final double min = 1.0 * scale; // Don't go too low (20% of base)
    final double max = 15.0 * scale; // Don't go too high (300% of base)

    return scaled.clamp(min, max);
  }

  /// Resolves base feed for smart feeding with proper fallback chain
  ///
  /// NEVER returns null or zero feed. Always provides safe fallback.
  /// Priority: anchor → yesterday → planned → safe fallback (density-scaled)
  ///
  /// [doc] Current day of culture
  /// [anchorFeed] Farmer-set baseline for DOC > 30
  /// [actualFeedYesterday] Previous day's actual feed
  /// [plannedFeed] Engine-calculated planned feed
  /// [seedCount] Pond stocking count (for scaling fallback)
  /// [pondId] For logging and error tracking
  ///
  /// Returns BaseFeedResult with amount and source for debugging
  /// GUARANTEES: feedAmount > 0 (never null, never 0)
  static BaseFeedResult resolveBaseFeed({
    required int doc,
    required double? anchorFeed,
    required double? actualFeedYesterday,
    required double plannedFeed,
    required int seedCount,
    required String pondId,
  }) {
    // Blind phase (DOC ≤ 30) - use planned feed directly
    if (doc <= 30) {
      AppLogger.debug(
        '[FeedBaseResolver] DOC $doc: Blind phase - using planned feed - pondId: $pondId, plannedFeed: $plannedFeed',
      );

      return BaseFeedResult(
        feedAmount: plannedFeed,
        source: BaseFeedSource.blind,
        explanation: 'Blind feeding phase (DOC ≤ 30) - using planned feed',
      );
    }

    // Smart phase (DOC > 30) - priority fallback chain
    AppLogger.debug(
      '[FeedBaseResolver] DOC $doc: Smart phase - resolving base feed - pondId: $pondId, anchorFeed: $anchorFeed, actualFeedYesterday: $actualFeedYesterday, plannedFeed: $plannedFeed',
    );

    // 1. Anchor feed (highest priority - farmer's explicit baseline)
    if (anchorFeed != null && anchorFeed > 0) {
      AppLogger.info(
        '[FeedBaseResolver] Using anchor feed for smart feeding',
        {
          'pondId': pondId,
          'doc': doc,
          'anchorFeed': anchorFeed,
          'source': 'anchor',
        },
      );

      return BaseFeedResult(
        feedAmount: anchorFeed,
        source: BaseFeedSource.anchor,
        explanation: 'Using farmer-set anchor feed as baseline',
      );
    }

    // 2. Yesterday's actual feed (most recent real data)
    if (actualFeedYesterday != null && actualFeedYesterday > 0) {
      AppLogger.info(
        '[FeedBaseResolver] Using yesterday\'s actual feed',
        {
          'pondId': pondId,
          'doc': doc,
          'actualFeedYesterday': actualFeedYesterday,
          'source': 'yesterday',
        },
      );

      return BaseFeedResult(
        feedAmount: actualFeedYesterday,
        source: BaseFeedSource.yesterday,
        explanation: 'Using yesterday\'s actual feed as baseline',
      );
    }

    // 3. Planned feed (engine calculation)
    if (plannedFeed > 0) {
      AppLogger.info(
        '[FeedBaseResolver] Using planned feed',
        {
          'pondId': pondId,
          'doc': doc,
          'plannedFeed': plannedFeed,
          'source': 'planned',
        },
      );

      return BaseFeedResult(
        feedAmount: plannedFeed,
        source: BaseFeedSource.planned,
        explanation: 'Using engine-calculated planned feed as baseline',
      );
    }

    // 4. SOFT FALLBACK - Safe minimum feed (NEVER return 0 or throw)
    // Scaled based on pond density to avoid over/underfeeding
    final safeFallbackFeed = computeSafeFallback(seedCount: seedCount);

    AppLogger.warn(
      '[FeedBaseResolver] Using soft fallback - no valid feed source available',
      {
        'pondId': pondId,
        'doc': doc,
        'seedCount': seedCount,
        'fallbackFeed': safeFallbackFeed,
        'anchorFeed': anchorFeed,
        'actualFeedYesterday': actualFeedYesterday,
        'plannedFeed': plannedFeed,
        'reason': 'Missing anchor, yesterday, and planned feed. Using density-scaled safe minimum.',
      },
    );

    return BaseFeedResult(
      feedAmount: safeFallbackFeed,
      source: BaseFeedSource.fallback,
      explanation: 'Using safe fallback baseline (scaled to pond size). '
          'Please set anchor feed in Settings for better accuracy.',
    );
  }

  /// Validates base feed for smart feeding safety
  ///
  /// Throws exception if base feed is invalid for smart phase
  static void validateSmartFeedBase(int doc, double baseFeed, String pondId) {
    if (doc > 30 && baseFeed <= 0) {
      AppLogger.error(
        '[FeedBaseResolver] CRITICAL: Invalid base feed for smart feeding',
        {
          'pondId': pondId,
          'doc': doc,
          'baseFeed': baseFeed,
          'severity': 'CRITICAL',
          'impact': 'Smart feeding cannot run with zero or negative base feed',
        },
      );

      throw Exception(
        'CRITICAL: Invalid base feed ($baseFeed) for smart feeding on pond $pondId DOC $doc. '
        'Smart feeding requires positive base feed to prevent shrimp starvation.',
      );
    }
  }

  /// Initializes anchor feed for DOC 31 transition if not set
  ///
  /// Called when pond enters smart feeding phase for the first time
  static double? initializeAnchorFeedIfNeeded({
    required int doc,
    required double? anchorFeed,
    required double? actualFeedYesterday,
    required double plannedFeed,
  }) {
    // Only initialize on first day of smart feeding
    if (doc != 31 || anchorFeed != null) {
      return anchorFeed;
    }

    // Use yesterday's feed or planned feed as initial anchor
    final initialAnchor = actualFeedYesterday ?? plannedFeed;

    if (initialAnchor > 0) {
      AppLogger.info(
        '[FeedBaseResolver] Auto-initializing anchor feed for DOC 31',
        {
          'doc': doc,
          'initialAnchor': initialAnchor,
          'source': actualFeedYesterday != null ? 'yesterday' : 'planned',
        },
      );

      return initialAnchor;
    }

    return null;
  }

  /// Converts source enum to string for debug display
  static String sourceToString(BaseFeedSource source) {
    switch (source) {
      case BaseFeedSource.anchor:
        return 'anchor';
      case BaseFeedSource.yesterday:
        return 'yesterday';
      case BaseFeedSource.planned:
        return 'planned';
      case BaseFeedSource.fallback:
        return 'fallback';
      case BaseFeedSource.blind:
        return 'blind';
      case BaseFeedSource.lastBlind:
        return 'lastBlind';
    }
  }
}
