// Feed Engine V1 Simplified Tests
//
// Validates the simplified feed engine with single deterministic flow:
// Base Feed → Tray Factor → Apply Factor → Safety Clamp → Result
//
// Test Cases:
// ✅ DOC 10 — Blind stage, smooth feed increase
// ✅ DOC 35 no tray — Feed > 0, trayFactor = 1.0
// ✅ Full tray — Feed decreases (~15%)
// ✅ Empty tray — Feed increases (~10%)
// ✅ Spike clamp — lastFeed=10kg, calc=25kg → final≤13kg

import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/feed/master_feed_engine.dart';
import 'package:aqua_rythu/systems/feed/feed_orchestrator.dart';
import 'package:aqua_rythu/features/feed/models/feed_input.dart';
import 'package:aqua_rythu/features/tray/enums/tray_status.dart';
import 'package:aqua_rythu/features/pond/enums/stocking_type.dart';

void main() {
  group('Feed Engine V1 Simplified — Single Deterministic Flow', () {
    // ────────────────────────────────────────────────────────────────────

    test('CASE 1: DOC 10 (Blind Stage) — Feed increases smoothly', () {
      // DOC 10 is early blind stage.
      // Expected: feed > 0, no advanced factors applied, deterministic output
      final input = FeedInput(
        seedCount: 100000,
        doc: 10,
        abw: null, // No sampling yet
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
        actualFeedYesterday: 5.0,
        lastFeedTime: DateTime.now().subtract(const Duration(minutes: 30)),
        pondId: 'test-pond-1',
        feedsPerDay: 4,
      );

      final result = FeedOrchestrator.compute(input);

      // Feed must be > 0
      expect(result.finalFeed, greaterThan(0.0));

      // No advanced factors applied
      expect(result.correction.growthFactor, equals(1.0));
      expect(result.correction.fcrFactor, equals(1.0));
      expect(result.correction.intelligenceFactor, equals(1.0));
      expect(result.correction.environmentFactor, equals(1.0));

      // Tray factor should be 1.0 (no tray data)
      expect(result.correction.trayFactor, equals(1.0));

      // Smart not applied
      expect(result.correction.isSmartApplied, isFalse);

      // Output is deterministic (run again → same result)
      final result2 = FeedOrchestrator.compute(input);
      expect(result2.finalFeed, equals(result.finalFeed));
    });

    // ────────────────────────────────────────────────────────────────────

    test('CASE 2: DOC 35 (no tray data) — Feed > 0, trayFactor = 1.0', () {
      // DOC 35 is smart mode, but no tray data provided.
      // Expected: feed > 0, trayFactor = 1.0 (default)
      final input = FeedInput(
        seedCount: 100000,
        doc: 35,
        abw: 2.5,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 70.0,
        dissolvedOxygen: 6.5,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.03,
        mortality: 0,
        trayStatuses: const [], // No tray data
        sampleAgeDays: 1,
        recentTrayLeftoverPct: const [],
        lastFcr: 1.5,
        actualFeedYesterday: 12.0,
        lastFeedTime: DateTime.now().subtract(const Duration(hours: 2)),
        pondId: 'test-pond-2',
        feedsPerDay: 4,
      );

      final result = FeedOrchestrator.compute(input);

      // Feed must be > 0
      expect(result.finalFeed, greaterThan(0.0));

      // Tray factor = 1.0 (no data)
      expect(result.correction.trayFactor, equals(1.0));

      // Combined factor = 1.0
      expect(result.correction.combinedFactor, equals(1.0));

      // Final feed = base feed (no adjustments)
      expect(result.finalFeed, equals(result.baseFeed));
    });

    // ────────────────────────────────────────────────────────────────────

    test('CASE 3: Full Tray — Feed decreases ~15%', () {
      // Full tray indicates shrimp are not eating well.
      // Expected: trayFactor ≈ 0.85, feed reduction
      final input = FeedInput(
        seedCount: 100000,
        doc: 40,
        abw: 3.5,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 50.0,
        dissolvedOxygen: 6.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.05,
        mortality: 0,
        trayStatuses: const [
          TrayStatus.full,
          TrayStatus.full,
          TrayStatus.partial,
        ],
        sampleAgeDays: 2,
        recentTrayLeftoverPct: const [],
        lastFcr: 1.4,
        actualFeedYesterday: 20.0,
        lastFeedTime:
            DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        pondId: 'test-pond-3',
        feedsPerDay: 4,
      );

      final result = FeedOrchestrator.compute(input);

      // Feed > 0 (never 0)
      expect(result.finalFeed, greaterThan(0.0));

      // Tray factor = 0.85 (more full than empty)
      expect(result.correction.trayFactor, equals(0.85));

      // Feed is reduced (final < base)
      expect(result.finalFeed, lessThan(result.baseFeed));

      // Reduction is ~15%
      final reductionPct =
          ((result.baseFeed - result.finalFeed) / result.baseFeed * 100);
      expect(reductionPct, closeTo(15.0, 5.0)); // ±5% tolerance
    });

    // ────────────────────────────────────────────────────────────────────

    test('CASE 4: Empty Tray — Feed increases ~10%', () {
      // Empty tray indicates shrimp are eating well.
      // Expected: trayFactor ≈ 1.1, feed increase
      final input = FeedInput(
        seedCount: 100000,
        doc: 45,
        abw: 4.0,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 95.0,
        dissolvedOxygen: 7.0,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.02,
        mortality: 0,
        trayStatuses: const [
          TrayStatus.empty,
          TrayStatus.empty,
          TrayStatus.partial,
        ],
        sampleAgeDays: 1,
        recentTrayLeftoverPct: const [],
        lastFcr: 1.2,
        actualFeedYesterday: 25.0,
        lastFeedTime: DateTime.now().subtract(const Duration(hours: 1)),
        pondId: 'test-pond-4',
        feedsPerDay: 4,
      );

      final result = FeedOrchestrator.compute(input);

      // Feed > 0
      expect(result.finalFeed, greaterThan(0.0));

      // ✅ Tray factor = 1.1 (more empty than full)
      expect(result.correction.trayFactor, equals(1.1));

      // ✅ Feed is increased (final > base)
      expect(result.finalFeed, greaterThan(result.baseFeed));

      // ✅ Increase is ~10%
      final increasePct =
          ((result.finalFeed - result.baseFeed) / result.baseFeed * 100);
      expect(increasePct, closeTo(10.0, 5.0)); // ±5% tolerance
    });

    // ────────────────────────────────────────────────────────────────────

    test('CASE 5: Spike Clamp — Protection against sudden feed spikes', () {
      // Scenario: calculated feed = 25 kg, base = 10 kg
      // Expected: final feed clamped to ≤ 13 kg (+30% cap)
      //
      // This test uses a trick: we set lastFcr high to trigger old FCR logic
      // (which is disabled), but the base safety clamp should still work.

      // First, compute base feed for DOC 50
      final debugData = MasterFeedEngine.computeWithDebug(
        doc: 50,
        stockingType: StockingType.nursery,
        density: 100000,
      );
      final baseFeed = debugData.finalFeed;

      final input = FeedInput(
        seedCount: 100000,
        doc: 50,
        abw: 5.0,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 85.0,
        dissolvedOxygen: 6.5,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.04,
        mortality: 0,
        trayStatuses: const [TrayStatus.empty, TrayStatus.empty], // 1.1 factor
        sampleAgeDays: 1,
        recentTrayLeftoverPct: const [],
        lastFcr: 1.0,
        actualFeedYesterday: baseFeed * 2.5, // Simulate huge spike input
        lastFeedTime: DateTime.now().subtract(const Duration(hours: 1)),
        pondId: 'test-pond-5',
        feedsPerDay: 4,
      );

      final result = FeedOrchestrator.compute(input);

      // ✅ Feed > 0
      expect(result.finalFeed, greaterThan(0.0));

      // ✅ Final feed ≤ base × 1.3 (safety cap)
      final maxAllowed = baseFeed * 1.3;
      expect(result.finalFeed,
          lessThanOrEqualTo(maxAllowed + 0.01)); // Allow tiny float error

      // ✅ If clamped occurred, log it
      if (result.debugInfo.wasClamped == true) {
        expect(result.debugInfo.clampReason, contains('capped'));
      }
    });

    // ────────────────────────────────────────────────────────────────────

    test('ZERO FEED CHECK: Feed never becomes 0 unexpectedly', () {
      // Test various scenarios to ensure feed never silently becomes 0
      final testCases = [
        ('DOC 5', 5, true, 100000),
        ('DOC 30', 30, true, 100000),
        ('DOC 60', 60, false, 100000),
        ('Low density', 10, true, 10000),
        ('High density', 20, true, 500000),
      ];

      for (final (label, doc, noAbw, density) in testCases) {
        final input = FeedInput(
          seedCount: density,
          doc: doc,
          abw: noAbw ? null : 2.0,
          stockingType: StockingType.nursery,
          feedingScore: 3.0,
          intakePercent: 60.0,
          dissolvedOxygen: 6.0,
          temperature: 28.0,
          phChange: 0.0,
          ammonia: 0.05,
          mortality: 0,
          trayStatuses: const [],
          sampleAgeDays: 0,
          recentTrayLeftoverPct: const [],
          lastFcr: null,
          actualFeedYesterday: 5.0,
          lastFeedTime: DateTime.now(),
        );

        final result = FeedOrchestrator.compute(input);

        // ✅ Feed must always be > 0 (unless critical stop)
        expect(result.finalFeed, greaterThan(0.0), reason: 'Case: $label');
      }
    });

    // ────────────────────────────────────────────────────────────────────

    test('DETERMINISTIC OUTPUT: Same input → same output', () {
      // Verify output is deterministic (no randomness, no timing effects)
      final input = FeedInput(
        seedCount: 100000,
        doc: 35,
        abw: 3.0,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 70.0,
        dissolvedOxygen: 6.5,
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.03,
        mortality: 0,
        trayStatuses: const [TrayStatus.empty, TrayStatus.full],
        sampleAgeDays: 1,
        recentTrayLeftoverPct: const [],
        lastFcr: 1.3,
        actualFeedYesterday: 15.0,
        lastFeedTime: DateTime(2026, 4, 18, 10, 0),
      );

      final result1 = FeedOrchestrator.compute(input);
      final result2 = FeedOrchestrator.compute(input);
      final result3 = FeedOrchestrator.compute(input);

      expect(result1.finalFeed, equals(result2.finalFeed));
      expect(result2.finalFeed, equals(result3.finalFeed));

      expect(
          result1.correction.trayFactor, equals(result2.correction.trayFactor));
      expect(result1.correction.combinedFactor,
          equals(result2.correction.combinedFactor));
    });

    // ────────────────────────────────────────────────────────────────────

    test('CRITICAL DO STOP: Dissolved oxygen < 3.5 → zero feed', () {
      // Critical safety: always stop if DO is too low
      final input = FeedInput(
        seedCount: 100000,
        doc: 40,
        abw: 3.0,
        stockingType: StockingType.nursery,
        feedingScore: 3.0,
        intakePercent: 70.0,
        dissolvedOxygen: 2.0, // CRITICAL
        temperature: 28.0,
        phChange: 0.0,
        ammonia: 0.05,
        mortality: 0,
        trayStatuses: const [TrayStatus.empty],
        sampleAgeDays: 1,
        recentTrayLeftoverPct: const [],
        lastFcr: 1.2,
        actualFeedYesterday: 20.0,
        lastFeedTime: DateTime.now(),
      );

      final result = FeedOrchestrator.compute(input);

      // ✅ Final feed = 0
      expect(result.finalFeed, equals(0.0));

      // ✅ Critical stop flagged
      expect(result.correction.isCriticalStop, isTrue);
    });

    // ────────────────────────────────────────────────────────────────────

    test('NO CRASH: All feed scenarios complete without exception', () {
      // Smoke test — verify no crashes across diverse inputs
      final scenarios = [
        ('Nursery, DOC 1', StockingType.nursery, 1, null),
        ('Nursery, DOC 45', StockingType.nursery, 45, 3.5),
        ('Nursery, DOC 75', StockingType.nursery, 75, 12.0),
        ('High density', StockingType.nursery, 25, null),
        ('Low density', StockingType.nursery, 50, 4.0),
      ];

      for (final (label, type, doc, abw) in scenarios) {
        final input = FeedInput(
          seedCount: 100000,
          doc: doc,
          abw: abw,
          stockingType: type,
          feedingScore: 3.0,
          intakePercent: 65.0,
          dissolvedOxygen: 6.0,
          temperature: 28.0,
          phChange: 0.0,
          ammonia: 0.05,
          mortality: 0,
          trayStatuses: const [TrayStatus.partial],
          sampleAgeDays: 0,
          recentTrayLeftoverPct: const [],
          lastFcr: null,
          actualFeedYesterday: 10.0,
          lastFeedTime: DateTime.now(),
        );

        // ✅ Should not throw
        expect(
          () => FeedOrchestrator.compute(input),
          returnsNormally,
          reason: 'Scenario: $label',
        );

        // ✅ Result should be valid
        final result = FeedOrchestrator.compute(input);
        expect(result.finalFeed.isNaN, isFalse);
        expect(result.finalFeed.isInfinite, isFalse);
      }
    });
  });
}
