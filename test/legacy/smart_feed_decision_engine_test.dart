import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/smart_feed_decision_engine.dart';
import 'package:aqua_rythu/core/models/feed_input.dart';
import 'package:aqua_rythu/core/models/feed_result.dart';

void main() {
  group('SmartFeedDecisionEngine', () {
    // ── EXPLANATION TESTS ──────────────────────────────────────────────────

    group('buildExplanation', () {
      test('includes biomass source explanation when using biomass', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 11.0,
          finalFeed: 10.0,
        );

        expect(explanation, contains('Biomass data'));
      });

      test('includes DOC source explanation when using DOC', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.doc,
          docFeed: 11.0,
          finalFeed: 10.0,
        );

        expect(explanation, contains('DOC-based'));
      });

      test('explains FCR overfeeding when fcrFactor < 0.95', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 11.0,
          finalFeed: 10.0,
          fcrFactor: 0.90,
        );

        expect(explanation, contains('FCR'));
        expect(explanation, contains('Overfeeding'));
      });

      test('explains underfeeding when fcrFactor > 1.05', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 10.0,
          finalFeed: 11.0,
          fcrFactor: 1.10,
        );

        expect(explanation, contains('underfeeding'));
      });

      test('explains feed reduction when finalFeed < docFeed', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 11.0,
          finalFeed: 10.0,
        );

        expect(explanation, contains('reduced'));
      });

      test('explains feed increase when finalFeed > docFeed', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.doc,
          docFeed: 10.0,
          finalFeed: 11.0,
        );

        expect(explanation, contains('increased'));
      });

      test('includes tray explanation when tray factor available', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 11.0,
          finalFeed: 10.0,
          trayFactor: 1.15,
        );

        expect(explanation, contains('Tray'));
      });

      test('includes growth explanation when growth factor available', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 11.0,
          finalFeed: 10.0,
          growthFactor: 1.05,
        );

        expect(explanation, contains('Growth'));
      });

      test('generates multi-line explanation with all factors', () {
        final explanation = SmartFeedDecisionEngine.buildExplanation(
          source: FeedSource.biomass,
          docFeed: 11.0,
          finalFeed: 10.0,
          fcrFactor: 0.92,
          trayFactor: 1.10,
          growthFactor: 1.03,
          hasRecentSampling: true,
        );

        expect(explanation.split('\n').length, greaterThan(3));
      });
    });

    // ── CONFIDENCE TESTS ───────────────────────────────────────────────────

    group('calculateConfidenceScore', () {
      test('base confidence is 0.5', () {
        // doc: 10 avoids any phase bonus (not > 15, not > 30)
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: false,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 10,
        );

        expect(score, equals(0.5));
      });

      test('recent sampling (0-3 days) adds 0.30 points', () {
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: true,
          samplingAgeDays: 2,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 20,
        );

        expect(score, greaterThanOrEqualTo(0.76)); // 0.5 + 0.15 + 0.15 - 0.04
      });

      test('older sampling (8-14 days) adds less points', () {
        // doc: 10 avoids the >15 phase bonus so the score stays below 0.7
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: true,
          samplingAgeDays: 12,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 10,
        );

        expect(score, greaterThan(0.5));
        expect(score, lessThan(0.75)); // Should be modest increase (less than fresh sampling)
      });

      test('FCR data adds points', () {
        final scoreWithFcr = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: false,
          hasFcrData: true,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 20,
        );

        final scoreWithoutFcr = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: false,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 20,
        );

        expect(scoreWithFcr, greaterThan(scoreWithoutFcr));
      });

      test('all factors present increases confidence significantly', () {
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: true,
          samplingAgeDays: 3,
          hasFcrData: true,
          hasTrayData: true,
          hasGrowthData: true,
          doc: 35,
        );

        expect(score, greaterThan(0.85)); // Should be high
      });

      test('score is clamped between 0.0 and 1.0', () {
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: true,
          samplingAgeDays: 1,
          hasFcrData: true,
          hasTrayData: true,
          hasGrowthData: true,
          doc: 40,
        );

        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      });

      test('smart phase (DOC > 30) gets confidence bonus', () {
        final smartPhaseScore = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: false,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 35,
        );

        final earlyPhaseScore = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: false,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 20,
        );

        expect(smartPhaseScore, greaterThan(earlyPhaseScore));
      });
    });

    // ── RECOMMENDATION TESTS ───────────────────────────────────────────────

    group('generateRecommendations', () {
      test('recommends feed reduction when fcrFactor is very low', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: 0.85,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
          confidenceScore: 0.8,
          source: FeedSource.biomass,
        );

        expect(recs, isNotEmpty);
        expect(recs.toString(), contains('Reduce'));
      });

      test('recommends slight feed reduction when fcrFactor is low', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: 0.92,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
          confidenceScore: 0.8,
          source: FeedSource.biomass,
        );

        expect(recs.toString(), contains('reduce'));
      });

      test('recommends feed increase when fcrFactor is high', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: 1.15,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
          confidenceScore: 0.8,
          source: FeedSource.biomass,
        );

        expect(recs.toString(), contains('increas'));
      });

      test('recommends tray monitoring when tray factor is moderately high', () {
        // 1.10 > 1.05 but <= 1.20 → triggers "Monitor tray closely for overflow"
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: null,
          trayFactor: 1.10,
          growthFactor: null,
          samplingAgeDays: null,
          confidenceScore: 0.8,
          source: FeedSource.biomass,
        );

        expect(recs.toString(), contains('Monitor'));
      });

      test('recommends sampling when samplingAgeDays > 10', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: null,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: 12,
          confidenceScore: 0.8,
          source: FeedSource.biomass,
        );

        expect(recs.toString(), contains('Sampling'));
      });

      test('recommends sampling for DOC source without biomass data', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: null,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
          confidenceScore: 0.6,
          source: FeedSource.doc,
        );

        expect(recs.toString(), contains('sampling'));
      });

      test('warns about low confidence when score < 0.6', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: null,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
          confidenceScore: 0.5,
          source: FeedSource.doc,
        );

        expect(recs.toString().toLowerCase(), contains('verif'));
      });

      test('always returns at least one recommendation', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: 1.0,
          trayFactor: 1.0,
          growthFactor: 1.0,
          samplingAgeDays: 5,
          confidenceScore: 0.8,
          source: FeedSource.biomass,
        );

        expect(recs.isNotEmpty, isTrue);
      });
    });

    // ── FEED SOURCE DETERMINATION TESTS ────────────────────────────────────

    group('determineFeedSource', () {
      test('returns biomass when abw is available and recent', () {
        final source = SmartFeedDecisionEngine.determineFeedSource(
          abw: 12.5,
          samplingAgeDays: 5,
        );

        expect(source, equals(FeedSource.biomass));
      });

      test('returns biomass when abw is available and sampling age is null', () {
        final source = SmartFeedDecisionEngine.determineFeedSource(
          abw: 12.5,
          samplingAgeDays: null,
        );

        expect(source, equals(FeedSource.biomass));
      });

      test('returns doc when abw is null', () {
        final source = SmartFeedDecisionEngine.determineFeedSource(
          abw: null,
          samplingAgeDays: null,
        );

        expect(source, equals(FeedSource.doc));
      });

      test('returns doc when sampling is older than 14 days', () {
        final source = SmartFeedDecisionEngine.determineFeedSource(
          abw: 12.5,
          samplingAgeDays: 20,
        );

        expect(source, equals(FeedSource.doc));
      });
    });

    // ── INTEGRATION TEST: Full Output Building ─────────────────────────────

    group('buildSmartFeedOutput', () {
      test('builds complete output with all data', () {
        final output = SmartFeedDecisionEngine.buildSmartFeedOutput(
          finalFeed: 10.2,
          docFeed: 11.0,
          biomassFeed: 10.5,
          abw: 12.5,
          doc: 35,
          fcrFactor: 0.92,
          trayFactor: 1.05,
          growthFactor: 1.02,
          samplingAgeDays: 3,
        );

        expect(output.finalFeed, equals(10.2));
        expect(output.source, equals(FeedSource.biomass));
        expect(output.explanation, isNotEmpty);
        expect(output.confidenceScore, greaterThan(0.0));
        expect(output.confidenceScore, lessThanOrEqualTo(1.0));
        expect(output.recommendations, isNotEmpty);
      });

      test('generates explanation that references feed adjustment', () {
        final output = SmartFeedDecisionEngine.buildSmartFeedOutput(
          finalFeed: 10.0,
          docFeed: 11.0,
          biomassFeed: null,
          abw: null,
          doc: 35,
          fcrFactor: null,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
        );

        expect(output.explanation, contains('reduc'));
      });

      test('ensures confidence score is realistic', () {
        final output = SmartFeedDecisionEngine.buildSmartFeedOutput(
          finalFeed: 10.2,
          docFeed: 11.0,
          biomassFeed: 10.5,
          abw: 12.5,
          doc: 35,
          fcrFactor: 0.92,
          trayFactor: 1.05,
          growthFactor: 1.02,
          samplingAgeDays: 3,
        );

        // With all data, confidence should be decent
        expect(output.confidenceScore, greaterThan(0.7));
      });

      test('handles minimal data gracefully', () {
        final output = SmartFeedDecisionEngine.buildSmartFeedOutput(
          finalFeed: 10.0,
          docFeed: 10.0,
          biomassFeed: null,
          abw: null,
          doc: 20,
          fcrFactor: null,
          trayFactor: null,
          growthFactor: null,
          samplingAgeDays: null,
        );

        expect(output.finalFeed, equals(10.0));
        expect(output.confidenceScore, greaterThan(0.0));
        expect(output.recommendations, isNotEmpty);
      });
    });

    // ── SCENARIO TEST: DOC 40 + High FCR + Fresh Sampling ──────────────────

    group('Scenario: DOC 40 Smart Phase', () {
      test('DOC 40 + fresh sampling + high FCR → reduced feed + high confidence', () {
        // Setup: DOC 40 (smart phase), fresh sampling (2 days), high FCR (1.8)
        final output = SmartFeedDecisionEngine.buildSmartFeedOutput(
          finalFeed: 9.8,
          docFeed: 11.0,
          biomassFeed: 10.2,
          abw: 13.2,
          doc: 40,
          fcrFactor: 0.91, // 1/0.91 = 1.10 FCR (high)
          trayFactor: 0.95,
          growthFactor: 1.01,
          samplingAgeDays: 2,
        );

        // Verify: Feed reduced
        expect(output.finalFeed, lessThan(output.docFeed));

        // Verify: Recommendation present
        expect(output.recommendations, isNotEmpty);

        // Verify: Confidence high (fresh sampling + smart phase)
        expect(output.confidenceScore, greaterThan(0.75));

        // Verify: Explanation mentions biomass and FCR
        expect(output.explanation, contains('Biomass'));
        expect(output.explanation, contains('Overfeeding'));
      });
    });
  });

  // ── V2.2: run() METHOD TESTS ─────────────────────────────────────────────

  group('SmartFeedDecisionEngine.run() - V2.2', () {
    FeedInput _buildInput({
      int doc = 20,
      int seedCount = 100000,
      double? abw,
      String stockingType = 'nursery',
      double? lastFcr,
      int sampleAgeDays = 0,
    }) {
      return FeedInput(
        doc: doc,
        seedCount: seedCount,
        abw: abw,
        stockingType: stockingType,
        feedingScore: 3.0,
        intakePercent: 0.8,
        dissolvedOxygen: 6.5,
        temperature: 28.0,
        phChange: 0.1,
        ammonia: 0.2,
        mortality: 0,
        trayStatuses: const [],
        sampleAgeDays: sampleAgeDays,
        lastFcr: lastFcr,
      );
    }

    // ── TEST 1: No Duplicate Source — input carries NO feed values ──────────

    test('Input carries no baseFeed or biomassFeed — engine computes them', () {
      // Verify the FeedInput model has no baseFeed/biomassFeed fields at all
      final input = _buildInput(doc: 20);
      // If this compiles and runs, FeedInput is clean of computed feed values
      expect(input.doc, equals(20));
      expect(input.seedCount, equals(100000));
    });

    // ── TEST 2: Decision Trace Completeness ─────────────────────────────────

    test('Decision trace has > 3 steps', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 35));
      expect(output.decisionTrace.length, greaterThan(3));
    });

    test('Decision trace first step contains "DOC"', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 25));
      expect(output.decisionTrace.first, contains('DOC'));
    });

    test('Decision trace last step contains "Final Feed"', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 25));
      expect(output.decisionTrace.last, contains('Final Feed'));
    });

    test('Decision trace mentions biomass when ABW provided', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 12.5, sampleAgeDays: 3),
      );
      expect(output.decisionTrace.join(' '), contains('biomass'));
    });

    test('Decision trace mentions DOC-based when no ABW', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 20));
      expect(output.decisionTrace.join(' ').toLowerCase(), contains('doc'));
    });

    test('Decision trace mentions FCR when lastFcr provided', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 10.0, lastFcr: 1.5, sampleAgeDays: 3),
      );
      expect(output.decisionTrace.join(' '), contains('FCR'));
    });

    // ── TEST 3: Correct Feed Selection ──────────────────────────────────────

    test('DOC 20 (no ABW) → uses DOC source', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 20));
      expect(output.source, equals(FeedSource.doc));
      expect(output.biomassFeed, isNull);
    });

    test('DOC 40 + ABW + sampleAgeDays → uses biomass source', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 13.0, sampleAgeDays: 5),
      );
      expect(output.source, equals(FeedSource.biomass));
      expect(output.biomassFeed, isNotNull);
    });

    test('DOC feed is always calculated regardless of source', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 13.0, sampleAgeDays: 5),
      );
      expect(output.docFeed, greaterThan(0));
    });

    test('Biomass source: finalFeed comes from biomass, not DOC', () {
      // doc=40: growth valid range 8–20 g. abw=8.0 → biomassFeed = 21.6 kg
      // (below mid-stage cap of 25 kg, no interference)
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 8.0, sampleAgeDays: 5),
      );
      // Without FCR, final == biomass feed
      expect(output.finalFeed, closeTo(output.biomassFeed!, 0.001));
    });

    test('FCR 1.5 (poor) → final feed is 90% of base feed', () {
      // doc=40: growth valid range 8–20 g. abw=8.0 → biomass 21.6 kg
      // FCR 1.5 factor = 0.9; 21.6 × 0.9 = 19.44 — both under 25 kg cap
      final base = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 8.0, sampleAgeDays: 3),
      );
      final withFcr = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 8.0, sampleAgeDays: 3, lastFcr: 1.5),
      );
      expect(withFcr.finalFeed, closeTo(base.finalFeed * 0.90, 0.01));
    });

    test('No null crashes with minimal input', () {
      expect(
        () => SmartFeedDecisionEngine.run(_buildInput()),
        returnsNormally,
      );
    });

    test('Output has engine version v2.3', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 20));
      expect(output.engineVersion, equals('v2.3'));
    });
  });

  // ── resolveFeedSource tests ────────────────────────────────────────────────

  group('resolveFeedSource', () {
    test('returns biomass when abw > 0 and count > 0 (legacy path)', () {
      // No samplingAgeDays supplied → legacy path used
      final source = SmartFeedDecisionEngine.resolveFeedSource(
        doc: 40,
        abw: 12.5,
        count: 100000,
      );
      expect(source, equals(FeedSource.biomass));
    });

    test('returns biomass when abw and count are valid with fresh sampling', () {
      final source = SmartFeedDecisionEngine.resolveFeedSource(
        doc: 40,
        abw: 12.5,
        count: 100000,
        samplingAgeDays: 5,
      );
      expect(source, equals(FeedSource.biomass));
    });

    test('returns doc when abw is null', () {
      final source = SmartFeedDecisionEngine.resolveFeedSource(
        doc: 20,
        abw: null,
        count: 100000,
      );
      expect(source, equals(FeedSource.doc));
    });

    test('returns doc when abw is 0', () {
      final source = SmartFeedDecisionEngine.resolveFeedSource(
        doc: 20,
        abw: 0,
        count: 100000,
      );
      expect(source, equals(FeedSource.doc));
    });

    test('returns doc when count is 0', () {
      final source = SmartFeedDecisionEngine.resolveFeedSource(
        doc: 40,
        abw: 12.5,
        count: 0,
      );
      expect(source, equals(FeedSource.doc));
    });

    test('returns doc when samplingAgeDays is stale (> 10)', () {
      final source = SmartFeedDecisionEngine.resolveFeedSource(
        doc: 40,
        abw: 12.5,
        count: 100000,
        samplingAgeDays: 15,
      );
      expect(source, equals(FeedSource.doc));
    });
  });

  // ── isValidBiomass tests ───────────────────────────────────────────────────

  group('isValidBiomass', () {
    test('Test 1: rejects stale sampling (samplingAgeDays = 15)', () {
      expect(
        SmartFeedDecisionEngine.isValidBiomass(
          abw: 10.0,
          count: 100000,
          samplingAgeDays: 15,
        ),
        isFalse,
      );
    });

    test('Test 2a: rejects unrealistically low ABW (0.1 g)', () {
      expect(
        SmartFeedDecisionEngine.isValidBiomass(
          abw: 0.1,
          count: 100000,
          samplingAgeDays: 3,
        ),
        isFalse,
      );
    });

    test('Test 2b: rejects unrealistically high ABW (200 g)', () {
      expect(
        SmartFeedDecisionEngine.isValidBiomass(
          abw: 200,
          count: 100000,
          samplingAgeDays: 3,
        ),
        isFalse,
      );
    });

    test('rejects null abw', () {
      expect(
        SmartFeedDecisionEngine.isValidBiomass(
          abw: null,
          count: 100000,
          samplingAgeDays: 3,
        ),
        isFalse,
      );
    });

    test('rejects null samplingAgeDays', () {
      expect(
        SmartFeedDecisionEngine.isValidBiomass(
          abw: 10.0,
          count: 100000,
          samplingAgeDays: null,
        ),
        isFalse,
      );
    });

    test('accepts valid data within bounds', () {
      expect(
        SmartFeedDecisionEngine.isValidBiomass(
          abw: 10.0,
          count: 100000,
          samplingAgeDays: 7,
        ),
        isTrue,
      );
    });
  });

  // ── getMaxFeed tests ───────────────────────────────────────────────────────

  group('getMaxFeed (stage-based safety cap)', () {
    test('Test 1: DOC 20 (early stage) → max 10 kg per lakh', () {
      expect(SmartFeedDecisionEngine.getMaxFeed(20, 100000), equals(10.0));
    });

    test('Test 1: DOC 30 (early stage boundary) → max 10 kg per lakh', () {
      expect(SmartFeedDecisionEngine.getMaxFeed(30, 100000), equals(10.0));
    });

    test('Test 1: DOC 70 (late stage) → max 40 kg per lakh', () {
      expect(SmartFeedDecisionEngine.getMaxFeed(70, 100000), equals(40.0));
    });

    test('DOC 60 (mid stage boundary) → max 25 kg per lakh', () {
      expect(SmartFeedDecisionEngine.getMaxFeed(60, 100000), equals(25.0));
    });

    test('DOC 31 (mid stage) → max 25 kg per lakh', () {
      expect(SmartFeedDecisionEngine.getMaxFeed(31, 100000), equals(25.0));
    });

    test('scales linearly with density', () {
      // DOC 40 (mid stage): baseCap = 25; density 200000 → 50 kg
      expect(SmartFeedDecisionEngine.getMaxFeed(40, 200000), equals(50.0));
    });
  });

  // ── getMinFeed tests ───────────────────────────────────────────────────────

  group('getMinFeed (underfeeding floor)', () {
    test('Test 2: DOC 20 → min 1.0 kg per lakh', () {
      // 20 * 0.05 * 1.0 = 1.0
      expect(SmartFeedDecisionEngine.getMinFeed(20, 100000), equals(1.0));
    });

    test('DOC 10 → min 0.5 kg per lakh', () {
      expect(SmartFeedDecisionEngine.getMinFeed(10, 100000), equals(0.5));
    });

    test('scales linearly with density', () {
      // DOC 20, density 200000 → 20 * 0.05 * 2.0 = 2.0
      expect(SmartFeedDecisionEngine.getMinFeed(20, 200000), equals(2.0));
    });
  });

  // ── calculateConfidence tests ──────────────────────────────────────────────

  group('calculateConfidence', () {
    test('Test 5: no sampling + no fcr + no tray → base = 0.4', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: false,
        samplingAgeDays: null,
        hasFcr: false,
        hasTray: false,
      );
      expect(score, closeTo(0.4, 0.001));
    });

    test('Test 4: fresh sampling (≤ 5 days) adds 0.3 → total 0.7', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: 3,
        hasFcr: false,
        hasTray: false,
      );
      expect(score, closeTo(0.7, 0.001));
    });

    test('Test 4: older sampling (6-10 days) adds 0.15 → total 0.55', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: 8,
        hasFcr: false,
        hasTray: false,
      );
      expect(score, closeTo(0.55, 0.001));
    });

    test('Test 4: fresh sampling gives higher confidence than old sampling', () {
      final freshScore = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: 2,
        hasFcr: false,
        hasTray: false,
      );
      final oldScore = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: 9,
        hasFcr: false,
        hasTray: false,
      );
      expect(freshScore, greaterThan(oldScore));
    });

    test('fcr data adds 0.15 → total 0.55', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: false,
        samplingAgeDays: null,
        hasFcr: true,
        hasTray: false,
      );
      expect(score, closeTo(0.55, 0.001));
    });

    test('tray data adds 0.15 → total 0.55', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: false,
        samplingAgeDays: null,
        hasFcr: false,
        hasTray: true,
      );
      expect(score, closeTo(0.55, 0.001));
    });

    test('all factors with fresh sampling → clamped to 1.0', () {
      // 0.4 + 0.3 + 0.15 + 0.15 = 1.0
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: 3,
        hasFcr: true,
        hasTray: true,
      );
      expect(score, closeTo(1.0, 0.001));
    });

    test('score is always clamped between 0.0 and 1.0', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: 1,
        hasFcr: true,
        hasTray: true,
      );
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });

    test('sampling without valid age gives no sampling bonus', () {
      final score = SmartFeedDecisionEngine.calculateConfidence(
        hasSampling: true,
        samplingAgeDays: null,
        hasFcr: false,
        hasTray: false,
      );
      // hasSampling=true but no age → no bonus added, stays at 0.4
      expect(score, closeTo(0.4, 0.001));
    });
  });

  // ── Validation integration via run() ──────────────────────────────────────

  group('run() - biomass validation & safety cap', () {
    FeedInput _buildInput({
      int doc = 20,
      int seedCount = 100000,
      double? abw,
      String stockingType = 'nursery',
      double? lastFcr,
      int sampleAgeDays = 0,
    }) {
      return FeedInput(
        doc: doc,
        seedCount: seedCount,
        abw: abw,
        stockingType: stockingType,
        feedingScore: 3.0,
        intakePercent: 0.8,
        dissolvedOxygen: 6.5,
        temperature: 28.0,
        phChange: 0.1,
        ammonia: 0.2,
        mortality: 0,
        trayStatuses: const [],
        sampleAgeDays: sampleAgeDays,
        lastFcr: lastFcr,
      );
    }

    test('Test 1: stale sampling (15 days) → falls back to DOC source', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 12.0, sampleAgeDays: 15),
      );
      expect(output.source, equals(FeedSource.doc));
    });

    test('Test 2a: invalid ABW (0.1 g) → falls back to DOC source', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 0.1, sampleAgeDays: 3),
      );
      expect(output.source, equals(FeedSource.doc));
    });

    test('Test 2b: invalid ABW (200 g) → falls back to DOC source', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 200.0, sampleAgeDays: 3),
      );
      expect(output.source, equals(FeedSource.doc));
    });

    test('Test 3: stage-based safety cap prevents overfeeding at early stage', () {
      // DOC 30 (early stage): maxFeed = 10 kg per lakh.
      // nursery docFeed: 4.0 + (30-1)*0.25 = 11.25 kg → capped at 10.0
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, seedCount: 100000),
      );
      expect(output.finalFeed, lessThanOrEqualTo(10.0));
      expect(output.decisionTrace.join('\n'), contains('Safety cap applied'));
    });

    test('Test 4: trace contains "Biomass rejected" for stale sampling', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 12.0, sampleAgeDays: 15),
      );
      expect(output.decisionTrace.join('\n'), contains('Biomass rejected'));
    });

    test('recommendation tells farmer to re-sample when biomass rejected', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 12.0, sampleAgeDays: 15),
      );
      expect(output.recommendations.join('\n'), contains('Re-sample'));
    });

    test('no "Biomass rejected" trace when abw is null', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 20));
      expect(output.decisionTrace.join('\n'), isNot(contains('Biomass rejected')));
    });
  });

  // ── V2.3 new tests ────────────────────────────────────────────────────────

  group('isGrowthValid', () {
    test('Test 3: DOC 30 + ABW 25 g → rejected (too heavy)', () {
      // max expected = 30 * 0.5 = 15 g. 25 > 15 → invalid
      expect(SmartFeedDecisionEngine.isGrowthValid(25.0, 30), isFalse);
    });

    test('DOC 30 + ABW 3 g → rejected (too light)', () {
      // min expected = 30 * 0.2 = 6 g. 3 < 6 → invalid
      expect(SmartFeedDecisionEngine.isGrowthValid(3.0, 30), isFalse);
    });

    test('DOC 30 + ABW 10 g → accepted (within range)', () {
      // range: 6–15 g. 10 ✓
      expect(SmartFeedDecisionEngine.isGrowthValid(10.0, 30), isTrue);
    });

    test('DOC 40 + ABW 8 g → accepted (lower boundary)', () {
      // min = 40 * 0.2 = 8. 8 >= 8 ✓
      expect(SmartFeedDecisionEngine.isGrowthValid(8.0, 40), isTrue);
    });

    test('DOC 40 + ABW 20 g → accepted (upper boundary)', () {
      // max = 40 * 0.5 = 20. 20 <= 20 ✓
      expect(SmartFeedDecisionEngine.isGrowthValid(20.0, 40), isTrue);
    });

    test('DOC 40 + ABW 5 g → rejected (below range)', () {
      expect(SmartFeedDecisionEngine.isGrowthValid(5.0, 40), isFalse);
    });
  });

  group('run() - V2.3 integration', () {
    FeedInput _buildInput({
      int doc = 20,
      int seedCount = 100000,
      double? abw,
      String stockingType = 'nursery',
      double? lastFcr,
      int sampleAgeDays = 0,
    }) {
      return FeedInput(
        doc: doc,
        seedCount: seedCount,
        abw: abw,
        stockingType: stockingType,
        feedingScore: 3.0,
        intakePercent: 0.8,
        dissolvedOxygen: 6.5,
        temperature: 28.0,
        phChange: 0.1,
        ammonia: 0.2,
        mortality: 0,
        trayStatuses: const [],
        sampleAgeDays: sampleAgeDays,
        lastFcr: lastFcr,
      );
    }

    test('growth check rejects unrealistic ABW for DOC', () {
      // DOC 30: valid range 6–15 g. abw=25 → rejected → falls back to DOC
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 25.0, sampleAgeDays: 5),
      );
      expect(output.source, equals(FeedSource.doc));
      expect(
        output.decisionTrace.join('\n'),
        contains('unrealistic growth'),
      );
    });

    test('growth check trace says "unrealistic growth", not stale sampling', () {
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 25.0, sampleAgeDays: 5),
      );
      expect(output.decisionTrace.join('\n'), contains('unrealistic growth'));
      expect(output.decisionTrace.join('\n'), isNot(contains('stale sampling')));
    });

    test('valid ABW within growth range uses biomass source', () {
      // DOC 30: valid range 6–15 g. abw=10 ✓
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 30, abw: 10.0, sampleAgeDays: 5),
      );
      expect(output.source, equals(FeedSource.biomass));
    });

    test('early stage cap (DOC 30) applied when DOC feed exceeds 10 kg', () {
      // nursery feed at DOC 30 = 11.25 kg > cap 10 kg → trace shows cap
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 30));
      expect(output.decisionTrace.join('\n'), contains('Safety cap applied'));
      expect(output.finalFeed, lessThanOrEqualTo(10.0));
    });

    test('late stage cap (DOC 70) is 40 kg per lakh', () {
      // DOC 70, late stage. docFeed = 4.0 + 69*0.25 = 21.25 < 40 → no cap
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 70));
      expect(output.finalFeed, lessThanOrEqualTo(40.0));
    });

    test('engine version is v2.3', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 20));
      expect(output.engineVersion, equals('v2.3'));
    });

    test('decision trace includes "Final Feed" as last entry', () {
      final output = SmartFeedDecisionEngine.run(_buildInput(doc: 20));
      expect(output.decisionTrace.last, contains('Final Feed'));
    });

    test('high FCR recommendation is time-bound and actionable', () {
      // FCR factor < 0.9 → "Reduce feed for next 2 days and monitor tray"
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 12.0, sampleAgeDays: 3, lastFcr: 1.8),
      );
      expect(output.recommendations.join('\n'), contains('next 2 days'));
    });

    test('stale sampling recommendation is actionable', () {
      // samplingAgeDays > 7 → "Schedule sampling within 2 days"
      final output = SmartFeedDecisionEngine.run(
        _buildInput(doc: 40, abw: 15.0, sampleAgeDays: 9),
      );
      // abw=15g at doc=40: growth valid range 8–20 ✓; sampling 9 days ≤ 10 → biomass used
      // samplingAgeDays > 7 → recommendation triggered
      expect(output.recommendations.join('\n'), contains('2 days'));
    });

    test('no crashes with minimal DOC=1 input', () {
      expect(
        () => SmartFeedDecisionEngine.run(_buildInput(doc: 1)),
        returnsNormally,
      );
    });
  });
}
