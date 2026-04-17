import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/smart_feed_engine_v2.dart';

void main() {
  group('SmartFeedEngineV2 - Smart Feed & FCR Tests', () {
    setUp(() {
      SmartFeedEngineV2.debugMode = false;
    });

    // ── FEED MODE TESTS ──────────────────────────────────────────────────────

    test('Mode resolution: DOC 20 → FeedMode.doc', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 20,
        density: 100000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      expect(result.mode, FeedMode.doc);
    });

    test('Mode resolution: DOC 35 no sampling → FeedMode.smart', () {
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

      expect(result.mode, FeedMode.smart);
    });

    test('Mode resolution: Sampling valid → FeedMode.biomass', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 25, // Even early DOC
        density: 100000,
        stockingType: 'nursery',
        abw: 8.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 1, // Valid
        fcr: null,
        fcrAgeDays: null,
      );

      expect(result.mode, FeedMode.biomass);
    });

    // ── FCR CORRECTION TESTS ─────────────────────────────────────────────────

    test('FCR 1.0 (exceptional) → +15% feed increase', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 1.0,
        fcrAgeDays: 5, // Fresh
      );

      // Base feed: biomass = (12 * 100000 * 0.90) / 1000 = 1080 kg
      // biomass feed = 1080 * 0.03 = 32.4 kg
      // FCR factor = 1.15 → 32.4 * 1.15 = 37.26 kg
      expect(result.fcrAdjustedFeed, closeTo(37.26, 0.5));
      expect(result.finalFeed, closeTo(37.26, 0.5));
      expect(result.hasValidFcr, true);
    });

    test('FCR 1.2 (very good) → +10% feed increase', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 1.2,
        fcrAgeDays: 3,
      );

      // Base feed = 32.4 kg
      // FCR factor = 1.10 → 32.4 * 1.10 = 35.64 kg
      expect(result.fcrAdjustedFeed, closeTo(35.64, 0.5));
    });

    test('FCR 1.4 (acceptable) → no change', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 1.4,
        fcrAgeDays: 2,
      );

      // Base feed = 32.4 kg
      // FCR factor = 1.0 → 32.4 * 1.0 = 32.4 kg (no change)
      expect(result.fcrAdjustedFeed, closeTo(32.4, 0.1));
    });

    test('FCR 1.5 (poor) → -10% feed decrease', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 1.5,
        fcrAgeDays: 4,
      );

      // Base feed = 32.4 kg
      // FCR factor = 0.90 → 32.4 * 0.90 = 29.16 kg
      expect(result.fcrAdjustedFeed, closeTo(29.16, 0.5));
    });

    test('FCR 2.0 (very poor) → -15% feed decrease', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 2.0,
        fcrAgeDays: 5,
      );

      // Base feed = 32.4 kg
      // FCR factor = 0.85 → 32.4 * 0.85 = 27.54 kg
      expect(result.fcrAdjustedFeed, closeTo(27.54, 0.5));
    });

    test('FCR too old (11 days) → ignored', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 1.0, // Would be +15%, but too old
        fcrAgeDays: 11, // Beyond 10-day freshness
      );

      // FCR ignored, biomass feed applies
      // biomass feed = (12 * 100000 * 0.90) / 1000 * 0.03 = 32.4 kg
      expect(result.fcrAdjustedFeed, isNull);
      expect(result.finalFeed, closeTo(32.4, 0.1));
      expect(result.hasValidFcr, false);
    });

    test('No FCR data → baseline feed only', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 40,
        density: 100000,
        stockingType: 'nursery',
        abw: 12.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: null,
        fcrAgeDays: null,
      );

      // No FCR → biomass feed only
      expect(result.fcrAdjustedFeed, isNull);
      expect(result.biomassFeed, closeTo(32.4, 0.1));
      expect(result.hasValidFcr, false);
    });

    // ── HYBRID MODE INTEGRATION TESTS ────────────────────────────────────────

    test('Hybrid complete flow: DOC + sampling + FCR', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 50,
        density: 150000,
        stockingType: 'nursery',
        abw: 15.0,
        seedCount: 150000,
        survivalRate: 0.88,
        sampleAgeDays: 3,
        fcr: 1.15,
        fcrAgeDays: 6,
      );

      // Mode: biomass (sampling present)
      expect(result.mode, FeedMode.biomass);

      // Biomass feed: (15 * 150000 * 0.88) / 1000 * 0.03 = 59.4 kg
      expect(result.biomassFeed, closeTo(59.4, 0.5));

      // FCR factor: 1.10 (for FCR 1.15, which is "very good")
      expect(result.fcrFactor, closeTo(1.10, 0.01));

      // Final: 59.4 * 1.10 = 65.34 kg
      expect(result.finalFeed, closeTo(65.34, 0.5));
      expect(result.hasValidSampling, true);
      expect(result.hasValidFcr, true);
    });

    // ── EDGE CASES ───────────────────────────────────────────────────────────

    test('Zero ABW → uses SMART fallback at DOC 35', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: 0.0, // Invalid
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 1,
        fcr: null,
        fcrAgeDays: null,
      );

      // ABW = 0 is invalid → DOC base, but DOC > 30 → SMART mode
      expect(result.mode, FeedMode.smart);
      // Should still calculate using DOC base since biomass data invalid
      expect(result.docFeed, isNotNull);
    });

    test('Very high stocking 500k → scales correctly', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 30,
        density: 500000,
        stockingType: 'nursery',
        abw: null,
        seedCount: null,
        survivalRate: null,
        sampleAgeDays: null,
        fcr: null,
        fcrAgeDays: null,
      );

      // Nursery DOC 30: baseFeed = 11.25
      // Density: 500000 → 11.25 * (500000/100000) = 56.25 kg
      expect(result.finalFeed, closeTo(56.25, 0.1));
    });

    test('Result toString shows all key info', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: 8.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 2,
        fcr: 1.2,
        fcrAgeDays: 5,
      );

      final str = result.toString();
      expect(str, contains('biomass'));
      expect(str, contains('FeedResult'));
    });

    test('Stale sampling triggers warning message', () {
      final result = SmartFeedEngineV2.calculateSmartFeed(
        doc: 35,
        density: 100000,
        stockingType: 'nursery',
        abw: 5.0,
        seedCount: 100000,
        survivalRate: 0.90,
        sampleAgeDays: 10, // Stale!
        fcr: null,
        fcrAgeDays: null,
      );

      // Stale sampling should generate a warning
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('stale') || w.contains('older')),
        true,
      );
    });
  });
}
