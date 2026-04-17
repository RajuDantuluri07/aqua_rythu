import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/feed_decision_engine.dart';
import 'package:aqua_rythu/core/engines/feed_recommendation_engine.dart';
import 'package:aqua_rythu/core/utils/time_provider.dart';

void main() {
  group('FeedRecommendationEngine', () {
    tearDown(() {
      TimeProvider.reset();
    });

    test('getFeedsPerDay returns correct DOC-based frequency', () {
      expect(FeedRecommendationEngine.getFeedsPerDay(5), 3);
      expect(FeedRecommendationEngine.getFeedsPerDay(20), 4);
      expect(FeedRecommendationEngine.getFeedsPerDay(40), 5);
    });

    test('First feed with no lastFeedTime uses the current time and clear instruction', () {
      const decision = FeedDecision(
        action: 'Maintain Feeding',
        deltaKg: 0.0,
        reason: 'All signals normal',
        recommendations: [],
        decisionTrace: [],
      );

      final now = DateTime(2026, 4, 16, 8, 0);
      TimeProvider.nowOverride = () => now;

      final recommendation = FeedRecommendationEngine.compute(
        finalFeedPerDay: 5.0,
        decision: decision,
        lastFeedTime: null,
        doc: 25,
      );

      expect(recommendation.nextFeedKg, 1.25);
      expect(recommendation.nextFeedTime, now);
      expect(recommendation.instruction,
          startsWith('Start first feed — give 1.25 kg at '));
      expect(recommendation.instruction,
          anyOf(endsWith('AM'), endsWith('PM')));
    });

    test('NaN feed input triggers fallback and preserves logging path', () {
      const decision = FeedDecision(
        action: 'Maintain Feeding',
        deltaKg: 0.0,
        reason: 'Invalid input',
        recommendations: [],
        decisionTrace: [],
      );

      final now = DateTime(2026, 4, 16, 9, 0);
      TimeProvider.nowOverride = () => now;

      final recommendation = FeedRecommendationEngine.compute(
        finalFeedPerDay: double.nan,
        decision: decision,
        lastFeedTime: DateTime(2026, 4, 16, 8, 0),
        doc: 20,
      );

      expect(recommendation.nextFeedKg, 0.0);
      expect(recommendation.nextFeedTime, now);
      expect(recommendation.instruction, 'System fallback — check manually');
    });

    test('Stop Feeding returns zero quantity and no feed amount in instruction', () {
      const decision = FeedDecision(
        action: 'Stop Feeding',
        deltaKg: 0.0,
        reason: 'Critical water condition',
        recommendations: [],
        decisionTrace: [],
      );

      final recommendation = FeedRecommendationEngine.compute(
        finalFeedPerDay: 5.0,
        decision: decision,
        lastFeedTime: DateTime(2026, 4, 16, 12, 0),
        doc: 35,
      );

      expect(recommendation.nextFeedKg, 0.0);
      expect(recommendation.instruction,
          'Do not feed now. Check water quality');
      expect(recommendation.instruction.contains('kg'), isFalse);
    });

    test('Time drift correction ensures nextFeedTime is not in the past', () {
      const decision = FeedDecision(
        action: 'Maintain Feeding',
        deltaKg: 0.0,
        reason: 'All signals normal',
        recommendations: [],
        decisionTrace: [],
      );
      final now = DateTime.now();
      final lastFeedTime = now.subtract(const Duration(minutes: 10));

      final recommendation = FeedRecommendationEngine.compute(
        finalFeedPerDay: 5.0,
        decision: decision,
        lastFeedTime: lastFeedTime,
        doc: 35,
      );

      expect(recommendation.nextFeedTime.isAfter(lastFeedTime), isTrue);
      expect(recommendation.nextFeedTime.isAfter(now.subtract(const Duration(seconds: 1))),
          isTrue);
    });

    test('Clamp upper bound when extreme values are provided', () {
      const decision = FeedDecision(
        action: 'Increase Feeding',
        deltaKg: 1000.0,
        reason: 'Extreme increase',
        recommendations: [],
        decisionTrace: [],
      );

      final recommendation = FeedRecommendationEngine.compute(
        finalFeedPerDay: 1000.0,
        decision: decision,
        lastFeedTime: DateTime(2026, 4, 16, 12, 0),
        doc: 35,
      );

      expect(recommendation.nextFeedKg,
          lessThanOrEqualTo(FeedRecommendationEngine.roundKg(1000.0 / 5 * 1.3)));
    });

    test('Clamp lower bound when extreme reduction is requested', () {
      const decision = FeedDecision(
        action: 'Reduce Feeding',
        deltaKg: -1000.0,
        reason: 'Extreme reduce',
        recommendations: [],
        decisionTrace: [],
      );

      final recommendation = FeedRecommendationEngine.compute(
        finalFeedPerDay: 1000.0,
        decision: decision,
        lastFeedTime: DateTime(2026, 4, 16, 12, 0),
        doc: 35,
      );

      expect(recommendation.nextFeedKg,
          greaterThanOrEqualTo(FeedRecommendationEngine.roundKg(1000.0 / 5 * 0.7)));
    });

    test('DOC-based interval uses 150 minutes for DOC 20 and 180 for DOC 40', () {
      const decision = FeedDecision(
        action: 'Maintain Feeding',
        deltaKg: 0.0,
        reason: 'All signals normal',
        recommendations: [],
        decisionTrace: [],
      );

      final now = DateTime.now();
      final time20 = now.subtract(const Duration(minutes: 10));
      final recommendation20 = FeedRecommendationEngine.compute(
        finalFeedPerDay: 5.0,
        decision: decision,
        lastFeedTime: time20,
        doc: 20,
      );
      expect(recommendation20.nextFeedTime,
          time20.add(const Duration(minutes: 150)));

      final time40 = now.subtract(const Duration(minutes: 10));
      final recommendation40 = FeedRecommendationEngine.compute(
        finalFeedPerDay: 5.0,
        decision: decision,
        lastFeedTime: time40,
        doc: 40,
      );
      expect(recommendation40.nextFeedTime,
          time40.add(const Duration(minutes: 180)));
    });

    test('RoundKg rounds correctly to two decimals', () {
      expect(FeedRecommendationEngine.roundKg(1.234), 1.23);
      expect(FeedRecommendationEngine.roundKg(1.235), 1.24);
    });
  });
}
