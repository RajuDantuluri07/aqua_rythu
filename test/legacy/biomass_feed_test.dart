import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/smart_feed_engine_v2.dart';

void main() {
  group('SmartFeedEngineV2 - Biomass Feed Tests', () {
    setUp(() {
      SmartFeedEngineV2.debugMode = false;
    });

    test('Biomass calculation - Basic', () {
      // 100k shrimp, 10g each, 90% survival, feed 3% of biomass
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: 10.0, // grams
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 1,
        fcr: null,
        fcrAgeDays: null,
      );

      // biomassKg = (10 * 100000 * 0.90) / 1000 = 900 kg
      // feed = 900 * 0.03 = 27.0 kg
      expect(result.mode, FeedMode.biomass);
      expect(result.biomassFeed, closeTo(27.0, 0.1));
      expect(result.finalFeed, closeTo(27.0, 0.1));
    });

    test('Biomass overrides DOC when sampling valid', () {
      // DOC 35 would suggest ~12.5kg, but biomass says 27kg
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: 10.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: null,
        fcrAgeDays: null,
      );

      // Should use biomass, not DOC
      expect(result.mode, FeedMode.biomass);
      expect(result.biomassFeed, closeTo(27.0, 0.1));
      // docFeed is calculated for reference but not used
      expect(result.finalFeed, closeTo(27.0, 0.1));
    });

    test('Light sampling (5g) - Lower biomass', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 30,
        density: 100000,
        stockingType: 'nursery',
        abw: 5.0, // Lighter growth
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 1,
        fcr: null,
        fcrAgeDays: null,
      );

      // biomassKg = (5 * 100000 * 0.90) / 1000 = 450 kg
      // feed = 450 * 0.03 = 13.5 kg
      expect(result.biomassFeed, closeTo(13.5, 0.1));
    });

    test('Heavy sampling (20g) - Higher biomass', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 50,
        density: 100000,
        stockingType: 'nursery',
        abw: 20.0, // Heavy growth
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: null,
        fcrAgeDays: null,
      );

      // biomassKg = (20 * 100000 * 0.90) / 1000 = 1800 kg
      // feed = 1800 * 0.03 = 54.0 kg
      expect(result.biomassFeed, closeTo(54.0, 0.1));
    });

    test('Low survival assumption (70%) - Reduces biomass feed', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 10.0,
        seedCount: 100000,
        survivalRate: 0.70, // Lower survival
        sampleAgeDays: 1,
        fcr: null,
        fcrAgeDays: null,
      );

      // biomassKg = (10 * 100000 * 0.70) / 1000 = 700 kg
      // feed = 700 * 0.03 = 21.0 kg
      expect(result.biomassFeed, closeTo(21.0, 0.1));
    });

    test('Stale sampling (8 days) - Falls back to DOC feed base', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 10.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 8, // Stale!
        fcr: null,
        fcrAgeDays: null,
      );

      // Sampling is stale → falls back to SMART mode (DOC > 30) with DOC feed
      // Nursery DOC 40: baseFeed = 4.0 + (40-1)*0.25 = 4.0 + 9.75 = 13.75
      expect(result.mode, FeedMode.smart);
      expect(result.finalFeed, closeTo(13.75, 0.1));
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('older') || w.contains('7 days')),
        true,
      );
    });

    test('Missing ABW - Falls back to SMART mode with DOC base', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: null, // No sampling
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // No ABW data at DOC 35 (>30) → SMART mode with DOC base
      // Nursery DOC 35: baseFeed = 4.0 + (35-1)*0.25 = 4.0 + 8.5 = 12.5
      expect(result.mode, FeedMode.smart);
      expect(result.docFeed, closeTo(12.5, 0.1));
      expect(result.biomassFeed, isNull);
    });

    test('Different seed counts - Linear scaling', () {
      final low = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 50000,
        stockingType: 'nursery',
        abw: 10.0,
        seedCount: 50000,
        survivalRate: 0.90,
        sampleAgeDays: 1,
        fcr: null,
        fcrAgeDays: null,
      );

      final high = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: 10.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 1,
        fcr: null,
        fcrAgeDays: null,
      );

      // Double the seedCount → double the biomass feed
      expect(high.biomassFeed! / low.biomassFeed!, closeTo(2.0, 0.01));
    });

    test('Debug trace contains biomass calculation details', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.5,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: null,
        fcrAgeDays: null,
      );

      expect(result.debugTrace, contains('Sampling valid'));
      expect(result.debugTrace, contains('ABW=12.50g'));
      expect(result.hasValidSampling, true);
    });
  });
}
