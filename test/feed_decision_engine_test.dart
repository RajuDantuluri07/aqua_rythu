import 'package:aqua_rythu/core/engines/feed_decision_engine.dart';
import 'package:aqua_rythu/core/engines/feed_intelligence_engine.dart';
import 'package:aqua_rythu/core/enums/feed_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedDecisionEngine', () {
    const baseFeed = 10.0;
    const decisionTrace = <String>[];

    test('Case 1: Clean system maintains feeding', () {
      final decision = FeedDecisionEngine.compute(
        baseFeed: baseFeed,
        finalFeed: baseFeed,
        intelligence: IntelligenceResult(
          expectedFeed: baseFeed,
          status: FeedStatus.onTrack,
        ),
        stage: FeedStage.intelligent,
        trayFactor: 1.0,
        growthFactor: 1.0,
        environmentFactor: 1.0,
        fcrFactor: 1.0,
        intelligenceStatus: FeedStatus.onTrack,
        hasActualData: false,
        confidenceScore: FeedDecisionEngine.confidenceForStage(FeedStage.intelligent),
        alerts: const [],
        existingRecommendations: const [],
        decisionTrace: decisionTrace,
      );

      expect(decision.action, 'Maintain Feeding');
      expect(decision.reason, 'All signals normal');
    });

    test('Case 2: Overfeeding yesterday reduces feeding', () {
      final decision = FeedDecisionEngine.compute(
        baseFeed: baseFeed,
        finalFeed: 9.0,
        intelligence: IntelligenceResult(
          expectedFeed: baseFeed,
          actualFeed: 12.0,
          deviation: 2.0,
          deviationPercent: 20.0,
          status: FeedStatus.overfeeding,
        ),
        stage: FeedStage.intelligent,
        trayFactor: 1.0,
        growthFactor: 1.0,
        environmentFactor: 1.0,
        fcrFactor: 1.0,
        intelligenceStatus: FeedStatus.overfeeding,
        hasActualData: true,
        confidenceScore: FeedDecisionEngine.confidenceForStage(FeedStage.intelligent),
        alerts: const [],
        existingRecommendations: const [],
        decisionTrace: decisionTrace,
      );

      expect(decision.action, 'Reduce Feeding');
      expect(decision.reason, 'Excess feed detected yesterday');
    });

    test('Case 3: Tray empty but overfeeding yesterday still reduces feeding', () {
      final decision = FeedDecisionEngine.compute(
        baseFeed: baseFeed,
        finalFeed: 11.0,
        intelligence: IntelligenceResult(
          expectedFeed: baseFeed,
          actualFeed: 12.0,
          deviation: 2.0,
          deviationPercent: 20.0,
          status: FeedStatus.overfeeding,
        ),
        stage: FeedStage.intelligent,
        trayFactor: 1.10,
        growthFactor: 1.0,
        environmentFactor: 1.0,
        fcrFactor: 1.0,
        intelligenceStatus: FeedStatus.overfeeding,
        hasActualData: true,
        confidenceScore: FeedDecisionEngine.confidenceForStage(FeedStage.intelligent),
        alerts: const [],
        existingRecommendations: const [],
        decisionTrace: decisionTrace,
      );

      expect(decision.action, 'Reduce Feeding');
      expect(decision.reason, 'Excess feed detected yesterday');
    });

    test('Case 4: Low DO always stops feeding', () {
      final decision = FeedDecisionEngine.compute(
        baseFeed: baseFeed,
        finalFeed: 0.0,
        intelligence: IntelligenceResult(
          expectedFeed: baseFeed,
          status: FeedStatus.onTrack,
        ),
        stage: FeedStage.intelligent,
        trayFactor: 1.0,
        growthFactor: 1.0,
        environmentFactor: 0.0,
        fcrFactor: 1.0,
        intelligenceStatus: FeedStatus.onTrack,
        hasActualData: false,
        confidenceScore: FeedDecisionEngine.confidenceForStage(FeedStage.intelligent),
        alerts: const ['Low dissolved oxygen'],
        existingRecommendations: const [],
        decisionTrace: decisionTrace,
        isCriticalStop: true,
      );

      expect(decision.action, 'Stop Feeding');
      expect(decision.reason,
          'Critical water condition (low DO / high ammonia)');
    });

    test('Case 5: Blind stage includes low confidence in reason', () {
      final decision = FeedDecisionEngine.compute(
        baseFeed: baseFeed,
        finalFeed: baseFeed,
        intelligence: IntelligenceResult(
          expectedFeed: baseFeed,
          status: FeedStatus.onTrack,
        ),
        stage: FeedStage.blind,
        trayFactor: 1.0,
        growthFactor: 1.0,
        environmentFactor: 1.0,
        fcrFactor: 1.0,
        intelligenceStatus: FeedStatus.onTrack,
        hasActualData: false,
        confidenceScore: FeedDecisionEngine.confidenceForStage(FeedStage.blind),
        alerts: const [],
        existingRecommendations: const [],
        decisionTrace: decisionTrace,
      );

      expect(decision.action, 'Maintain Feeding');
      expect(decision.reason, 'All signals normal (low confidence)');
    });
  });
}
