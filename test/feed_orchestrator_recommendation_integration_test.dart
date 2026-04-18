import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/feed/feed_orchestrator.dart';
import 'package:aqua_rythu/core/engines/feed/feed_recommendation_engine.dart';
import 'package:aqua_rythu/core/models/feed_input.dart';
import 'package:aqua_rythu/core/enums/tray_status.dart';
import 'package:aqua_rythu/core/enums/stocking_type.dart';

void main() {
  group('FeedOrchestrator recommendation integration', () {
    test('Reduce decision results in lower next feed quantity', () {
      final input = FeedInput(
        seedCount: 100000,
        doc: 20,
        abw: null,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 65.0,
        dissolvedOxygen: 6.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.05,
        mortality: 0,
        trayStatuses: const [],
        sampleAgeDays: 0,
        recentTrayLeftoverPct: const [],
        lastFcr: null,
        actualFeedYesterday: 14.0,
        lastFeedTime: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final result = FeedOrchestrator.compute(input);
      expect(result.decision.action, 'Reduce Feeding');
      expect(result.recommendation.nextFeedKg,
          lessThan(result.finalFeed / FeedRecommendationEngine.getFeedsPerDay(20)));
    });

    test('Increase decision results in higher next feed quantity', () {
      final input = FeedInput(
        seedCount: 100000,
        doc: 20,
        abw: null,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 95.0,
        dissolvedOxygen: 6.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.05,
        mortality: 0,
        trayStatuses: const [],
        sampleAgeDays: 0,
        recentTrayLeftoverPct: const [],
        lastFcr: null,
        actualFeedYesterday: 7.0,
        lastFeedTime: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final result = FeedOrchestrator.compute(input);
      expect(result.decision.action, 'Increase Feeding');
      expect(result.recommendation.nextFeedKg,
          greaterThan(result.finalFeed / FeedRecommendationEngine.getFeedsPerDay(20)));
    });

    test('Stop feeding decision results in zero recommendation', () {
      final input = FeedInput(
        seedCount: 100000,
        doc: 35,
        abw: 3.0,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 95.0,
        dissolvedOxygen: 2.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 1.0,
        mortality: 0,
        trayStatuses: const [TrayStatus.empty],
        sampleAgeDays: 2,
        recentTrayLeftoverPct: const [100.0],
        lastFcr: 1.5,
        actualFeedYesterday: 5.0,
        lastFeedTime: DateTime(2026, 4, 16, 12, 0),
      );

      final result = FeedOrchestrator.compute(input);
      expect(result.decision.action, 'Stop Feeding');
      expect(result.recommendation.nextFeedKg, 0.0);
    });
  });
}
