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
  /// Resolves base feed for smart feeding with proper fallback chain
  ///
  /// Ensures smart feeding never runs on null or zero base feed.
  /// Follows priority: anchor → yesterday → planned → fallback
  ///
  /// [doc] Current day of culture
  /// [anchorFeed] Farmer-set baseline for DOC > 30
  /// [actualFeedYesterday] Previous day's actual feed
  /// [plannedFeed] Engine-calculated planned feed
  /// [pondId] For logging and error tracking
  ///
  /// Returns BaseFeedResult with amount and source for debugging
  static BaseFeedResult resolveBaseFeed({
    required int doc,
    required double? anchorFeed,
    required double? actualFeedYesterday,
    required double plannedFeed,
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

    // 4. Safety fallback - prevents zero feed (should never reach here)
    const fallbackFeed = 1.0;
    AppLogger.error(
      '[FeedBaseResolver] CRITICAL: All base feed sources failed - using safety fallback',
      {
        'pondId': pondId,
        'doc': doc,
        'fallbackFeed': fallbackFeed,
        'anchorFeed': anchorFeed,
        'actualFeedYesterday': actualFeedYesterday,
        'plannedFeed': plannedFeed,
        'severity': 'CRITICAL',
      },
    );

    return const BaseFeedResult(
      feedAmount: fallbackFeed,
      source: BaseFeedSource.fallback,
      explanation:
          'CRITICAL: All sources failed - using safety fallback to prevent starvation',
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
    }
  }
}
