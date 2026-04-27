// Test cases for Anchor Feed Bug Fix
// 
// Critical bug fix validation - ensures smart feeding never runs on null/zero base
// This test validates the FeedBaseResolver handles all edge cases correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/feed/feed_base_resolver.dart';

void main() {
  group('Anchor Feed Bug Fix Tests', () {
    const pondId = 'test-pond-123';

    test('Case 1: DOC 31, no anchor, has yesterday feed - should use yesterday', () {
      // Case 1: DOC 31, no anchor
      // lastFeed = 20
      // ✅ Expected base = 20
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 20.0);
      expect(result.source, BaseFeedSource.yesterday);
      expect(result.explanation, contains('yesterday\'s actual feed'));
    });

    test('Case 2: DOC 31, no anchor, no yesterday feed - should use planned', () {
      // Case 2: DOC 31, no anchor, no lastFeed
      // plannedFeed = 18
      // ✅ Expected base = 18
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: null,
        plannedFeed: 18.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 18.0);
      expect(result.source, BaseFeedSource.planned);
      expect(result.explanation, contains('engine-calculated planned feed'));
    });

    test('Case 3: All null/zero - should use safe fallback', () {
      // Case 3: All null
      // ✅ Expected base = 1.0 (safe fallback)
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: null,
        plannedFeed: 0.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 1.0);
      expect(result.source, BaseFeedSource.fallback);
      expect(result.explanation, contains('CRITICAL: All sources failed'));
    });

    test('Case 4: Anchor exists - should use anchor', () {
      // Case 4: Anchor exists
      // anchorFeed = 22
      // ✅ Expected base = 22
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: 22.0,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 22.0);
      expect(result.source, BaseFeedSource.anchor);
      expect(result.explanation, contains('farmer-set anchor feed'));
    });

    test('Case 5: Blind phase (DOC ≤ 30) - should use planned feed', () {
      // Blind phase should ignore anchor and use planned
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 25,
        anchorFeed: 100.0, // Should be ignored
        actualFeedYesterday: 20.0,
        plannedFeed: 15.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 15.0);
      expect(result.source, BaseFeedSource.blind);
      expect(result.explanation, contains('Blind feeding phase'));
    });

    test('Case 6: Zero anchor feed - should skip to yesterday', () {
      // Zero anchor feed should be ignored
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: 0.0, // Should be ignored
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 20.0);
      expect(result.source, BaseFeedSource.yesterday);
    });

    test('Case 7: Negative anchor feed - should skip to yesterday', () {
      // Negative anchor feed should be ignored
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: -5.0, // Should be ignored
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 20.0);
      expect(result.source, BaseFeedSource.yesterday);
    });

    test('Case 8: Zero yesterday feed - should skip to planned', () {
      // Zero yesterday feed should be ignored
      final result = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: 0.0, // Should be ignored
        plannedFeed: 18.0,
        pondId: pondId,
      );

      expect(result.feedAmount, 18.0);
      expect(result.source, BaseFeedSource.planned);
    });

    test('Smart phase validation - valid base feed should pass', () {
      // Valid base feed should not throw
      expect(
        () => FeedBaseResolver.validateSmartFeedBase(31, 20.0, pondId),
        returnsNormally,
      );
    });

    test('Smart phase validation - zero base feed should throw', () {
      // Zero base feed should throw exception
      expect(
        () => FeedBaseResolver.validateSmartFeedBase(31, 0.0, pondId),
        throwsA(isA<Exception>()),
      );
    });

    test('Smart phase validation - negative base feed should throw', () {
      // Negative base feed should throw exception
      expect(
        () => FeedBaseResolver.validateSmartFeedBase(31, -5.0, pondId),
        throwsA(isA<Exception>()),
      );
    });

    test('Blind phase validation - zero base feed should pass', () {
      // Blind phase should allow zero base feed
      expect(
        () => FeedBaseResolver.validateSmartFeedBase(25, 0.0, pondId),
        returnsNormally,
      );
    });

    test('Anchor feed initialization - DOC 31 with no anchor', () {
      // Should initialize anchor feed on DOC 31
      final initializedAnchor = FeedBaseResolver.initializeAnchorFeedIfNeeded(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
      );

      expect(initializedAnchor, 20.0); // Should use yesterday's feed
    });

    test('Anchor feed initialization - DOC 30 should not initialize', () {
      // Should not initialize anchor feed before DOC 31
      final initializedAnchor = FeedBaseResolver.initializeAnchorFeedIfNeeded(
        doc: 30,
        anchorFeed: null,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
      );

      expect(initializedAnchor, isNull); // Should not initialize
    });

    test('Anchor feed initialization - existing anchor should not change', () {
      // Should not change existing anchor feed
      final initializedAnchor = FeedBaseResolver.initializeAnchorFeedIfNeeded(
        doc: 31,
        anchorFeed: 25.0,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
      );

      expect(initializedAnchor, 25.0); // Should keep existing anchor
    });

    test('Source to string conversion', () {
      expect(FeedBaseResolver.sourceToString(BaseFeedSource.anchor), 'anchor');
      expect(FeedBaseResolver.sourceToString(BaseFeedSource.yesterday), 'yesterday');
      expect(FeedBaseResolver.sourceToString(BaseFeedSource.planned), 'planned');
      expect(FeedBaseResolver.sourceToString(BaseFeedSource.fallback), 'fallback');
      expect(FeedBaseResolver.sourceToString(BaseFeedSource.blind), 'blind');
    });

    test('Priority order test - anchor > yesterday > planned > fallback', () {
      // Test that priority is correctly enforced
      final result1 = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: 30.0,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
        pondId: pondId,
      );
      expect(result1.source, BaseFeedSource.anchor);

      final result2 = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: 20.0,
        plannedFeed: 18.0,
        pondId: pondId,
      );
      expect(result2.source, BaseFeedSource.yesterday);

      final result3 = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: null,
        plannedFeed: 18.0,
        pondId: pondId,
      );
      expect(result3.source, BaseFeedSource.planned);

      final result4 = FeedBaseResolver.resolveBaseFeed(
        doc: 31,
        anchorFeed: null,
        actualFeedYesterday: null,
        plannedFeed: 0.0,
        pondId: pondId,
      );
      expect(result4.source, BaseFeedSource.fallback);
    });
  });
}
