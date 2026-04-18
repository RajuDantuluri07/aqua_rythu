import 'package:aqua_rythu/core/engines/feed/feed_orchestrator.dart';
import 'package:aqua_rythu/core/models/feed_input.dart';
import 'package:aqua_rythu/core/enums/tray_status.dart';
import 'package:aqua_rythu/core/enums/stocking_type.dart';

void main() {
  simulateDay();
}

void simulateDay() {
  print('--- Manual farm simulation start ---');

  final morningFeedInput = FeedInput(
    seedCount: 120000,
    doc: 5,
    abw: 0.35,
    stockingType: StockingType.nursery,
    feedingScore: 3.0,
    intakePercent: 85.0,
    dissolvedOxygen: 5.5,
    temperature: 28.0,
    phChange: 0.05,
    ammonia: 0.04,
    mortality: 0,
    trayStatuses: [TrayStatus.full, TrayStatus.full],
    sampleAgeDays: 1,
    recentTrayLeftoverPct: [70.0, 60.0],
    lastFcr: 1.2,
    actualFeedYesterday: 4.5,
    lastFeedTime: null,
  );

  final morningResult = FeedOrchestrator.compute(morningFeedInput);
  print('Morning recommendation: ${morningResult.recommendation.instruction}');
  print('Next feed at ${morningResult.recommendation.nextFeedTime}');

  final eveningFeedInput = FeedInput(
    seedCount: 120000,
    doc: 5,
    abw: 0.38,
    stockingType: StockingType.nursery,
    feedingScore: 3.0,
    intakePercent: 88.0,
    dissolvedOxygen: 6.2,
    temperature: 27.5,
    phChange: 0.03,
    ammonia: 0.03,
    mortality: 0,
    trayStatuses: [TrayStatus.full, TrayStatus.partial],
    sampleAgeDays: 2,
    recentTrayLeftoverPct: [70.0, 50.0],
    lastFcr: 1.15,
    actualFeedYesterday: 4.8,
    lastFeedTime: DateTime.now().subtract(const Duration(hours: 8)),
  );

  final eveningResult = FeedOrchestrator.compute(eveningFeedInput);
  print('Evening recommendation: ${eveningResult.recommendation.instruction}');
  print('Next feed at ${eveningResult.recommendation.nextFeedTime}');

  print('--- Manual farm simulation complete ---');
}
