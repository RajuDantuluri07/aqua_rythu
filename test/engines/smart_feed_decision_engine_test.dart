import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/smart_feed_decision_engine.dart';
import 'package:aqua_rythu/models/feed_result.dart';

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
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: false,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 20,
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
        final score = SmartFeedDecisionEngine.calculateConfidenceScore(
          hasRecentSampling: true,
          samplingAgeDays: 12,
          hasFcrData: false,
          hasTrayData: false,
          hasGrowthData: false,
          doc: 20,
        );

        expect(score, greaterThan(0.5));
        expect(score, lessThan(0.7)); // Should be modest increase
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

      test('recommends tray monitoring when tray factor is high', () {
        final recs = SmartFeedDecisionEngine.generateRecommendations(
          fcrFactor: null,
          trayFactor: 1.25,
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
}
