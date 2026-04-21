import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/smart_feed_engine_v2.dart';

void main() {
  group('SmartFeedEngineV2 - DOC Feed Tests', () {
    setUp(() {
      SmartFeedEngineV2.debugMode = false; // Disable debug output in tests
    });

    test('DOC 1 Hatchery - Minimal feeding', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 1,
        density: 100000,
        stockingType: 'hatchery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Hatchery DOC 1: baseFeed = 2.0 + (1-1)*0.15 = 2.0
      // Density: 100000, so adjustedFeed = 2.0 * (100000/100000) = 2.0 kg
      expect(result.mode, FeedMode.doc);
      expect(result.finalFeed, closeTo(2.0, 0.01));
      expect(result.docFeed, closeTo(2.0, 0.01));
    });

    test('DOC 15 Hatchery - Growth phase', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 15,
        density: 100000,
        stockingType: 'hatchery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Hatchery DOC 15: baseFeed = 2.0 + (15-1)*0.15 = 2.0 + 2.1 = 4.1
      // Density: 100000, so adjustedFeed = 4.1 kg
      expect(result.mode, FeedMode.doc);
      expect(result.finalFeed, closeTo(4.1, 0.01));
    });

    test('DOC 30 Nursery - Still DOC mode (no sampling)', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 30,
        density: 100000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Nursery DOC 30: baseFeed = 4.0 + (30-1)*0.25 = 4.0 + 7.25 = 11.25
      // Density: 100000, so adjustedFeed = 11.25 kg
      expect(result.mode, FeedMode.doc);
      expect(result.finalFeed, closeTo(11.25, 0.01));
      expect(result.docFeed, closeTo(11.25, 0.01));
    });

    test('DOC 35 Nursery - Transitions to SMART mode', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Nursery DOC 35: baseFeed = 4.0 + (35-1)*0.25 = 4.0 + 8.5 = 12.5
      // Density: 100000, so adjustedFeed = 12.5 kg
      // Should switch to SMART mode (DOC > 30, no sampling)
      expect(result.mode, FeedMode.smart);
      expect(result.finalFeed, closeTo(12.5, 0.01));
    });

    test('Double stocking (200k) - Feed scales linearly', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 15,
        density: 200000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Nursery DOC 15: baseFeed = 4.0 + (15-1)*0.25 = 4.0 + 3.5 = 7.5
      // Density: 200000, so adjustedFeed = 7.5 * (200000/100000) = 15.0 kg
      expect(result.finalFeed, closeTo(15.0, 0.01));
    });

    test('Half stocking (50k) - Feed scales down', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 20,
        density: 50000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Nursery DOC 20: baseFeed = 4.0 + (20-1)*0.25 = 4.0 + 4.75 = 8.75
      // Density: 50000, so adjustedFeed = 8.75 * (50000/100000) = 4.375 kg
      expect(result.finalFeed, closeTo(4.375, 0.01));
    });

    test('Mode debug trace captures calculation steps', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 25,
        density: 100000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      expect(result.debugTrace, contains('FEED CALCULATION'));
      expect(result.debugTrace, contains('Smart Feed Engine V2'));
      expect(result.debugTrace, contains('DOC=25'));
    });
  });
}
