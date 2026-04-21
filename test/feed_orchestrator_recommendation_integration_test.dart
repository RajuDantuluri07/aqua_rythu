import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/feed/feed_orchestrator.dart';
import 'package:aqua_rythu/systems/feed/feed_recommendation_engine.dart';
import 'package:aqua_rythu/features/feed/models/feed_input.dart';
import 'package:aqua_rythu/features/tray/enums/tray_status.dart';
import 'package:aqua_rythu/features/pond/enums/stocking_type.dart';

void main() {
  group('FeedOrchestrator V1 Simplified (Tray-only)', () {
    test('Low intake + partial tray → maintain with tray factor', () {
      // V1 SIMPLIFIED: No longer makes complex Reduce/Increase decisions.
      // Only decision is: Maintain Feeding (using tray factor).
      // This test verifies the simplified flow works correctly.
      final input = FeedInput(
        seedCount: 100000,
        doc: 20,
        abw: null,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 65.0, // Low intake (was triggering Reduce in old logic)
        dissolvedOxygen: 6.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.05,
        mortality: 0,
        trayStatuses: const [], // No tray adjustment
        sampleAgeDays: 0,
        recentTrayLeftoverPct: const [],
        lastFcr: null,
        actualFeedYesterday: 14.0,
        lastFeedTime: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final result = FeedOrchestrator.compute(input);
      
      // ✅ V1 SIMPLIFIED: Always "Maintain Feeding" (decision engine disabled)
      expect(result.decision.action, equals('Maintain Feeding'));
      
      // ✅ Feed is deterministic (tray only, no intake-based adjustment)
      expect(result.finalFeed, greaterThan(0.0));
    });

    test('High intake + empty tray → feed increased via tray factor', () {
      // V1 SIMPLIFIED: Feed increase comes from empty tray (factor 1.1),
      // NOT from complex decision engine logic.
      final input = FeedInput(
        seedCount: 100000,
        doc: 20,
        abw: null,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 95.0, // High intake (was triggering Increase in old logic)
        dissolvedOxygen: 6.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.05,
        mortality: 0,
        trayStatuses: const [
          TrayStatus.empty,
          TrayStatus.empty,
          TrayStatus.empty,
        ],
        sampleAgeDays: 0,
        recentTrayLeftoverPct: const [],
        lastFcr: null,
        actualFeedYesterday: 7.0,
        lastFeedTime: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      final result = FeedOrchestrator.compute(input);
      
      // ✅ V1 SIMPLIFIED: Always "Maintain Feeding"
      expect(result.decision.action, equals('Maintain Feeding'));
      
      // ✅ But feed is increased via tray factor (1.1)
      expect(result.correction.trayFactor, equals(1.1));
      expect(result.finalFeed, greaterThan(result.baseFeed));
    });

    test('Critical DO stop → zero feed', () {
      // Critical safety logic still applies (unchanged in V1)
      final input = FeedInput(
        seedCount: 100000,
        doc: 35,
        abw: 3.0,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 95.0,
        dissolvedOxygen: 2.0, // CRITICAL
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
      expect(result.decision.action, equals('Stop Feeding'));
      expect(result.finalFeed, equals(0.0));
    });
  });
}

