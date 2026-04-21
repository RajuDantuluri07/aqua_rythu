import 'package:aqua_rythu/systems/feed_decision_engine.dart';
import 'package:aqua_rythu/systems/feed_intelligence_engine.dart';
import 'package:aqua_rythu/features/feed/enums/feed_stage.dart';
import '../models/farm_scenario.dart';

FeedDecision runScenario(FarmScenario scenario) {
  return FeedDecisionEngine.compute(
    baseFeed: 5,
    finalFeed: 5,
    intelligence: IntelligenceResult(
      expectedFeed: 5,
      status: scenario.intelligenceStatus,
      actualFeed: scenario.hasActualData ? 5 : null,
    ),
    stage: FeedStage.intelligent,
    trayFactor: scenario.trayFactor,
    growthFactor: scenario.growthFactor,
    environmentFactor: scenario.environmentFactor,
    fcrFactor: scenario.fcrFactor,
    intelligenceStatus: scenario.intelligenceStatus,
    hasActualData: scenario.hasActualData,
    confidenceScore: FeedDecisionEngine.confidenceForStage(FeedStage.intelligent),
    alerts: [],
    existingRecommendations: [],
    decisionTrace: [],
    isCriticalStop: scenario.isCriticalStop,
  );
}
