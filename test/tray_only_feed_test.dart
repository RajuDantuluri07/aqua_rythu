// Tray-Only Feed Test - Validate simplified feed engine behavior
//
// This test validates that the refactored feed system is TRAY-DRIVEN ONLY:
// - Sampling has 0 effect on feed
// - Water has 0 effect on feed (except safety stops)
// - Tray changes drive feed changes

import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/feed/models/feed_input.dart';
import 'package:aqua_rythu/features/tray/enums/tray_status.dart';
import 'package:aqua_rythu/features/pond/enums/stocking_type.dart';
import 'package:aqua_rythu/systems/feed/master_feed_engine.dart';
import 'package:aqua_rythu/systems/feed/feed_calculations.dart';

void main() {
  group('Tray-Only Feed Engine Tests', () {
    late FeedInput baseInput;

    setUp(() {
      // Base input for testing
      baseInput = FeedInput(
        pondId: 'test-pond',
        doc: 45,
        seedCount: 100000,
        stockingType: StockingType.normal,
        dissolvedOxygen: 5.0,
        ammonia: 0.1,
        temperature: 28.0,
        pH: 7.5,
        trayStatuses: [TrayStatus.partial, TrayStatus.partial, TrayStatus.partial],
        feedsPerDay: 4,
      );
    });

    test('Case 1: Change sampling → feed MUST NOT change', () {
      // Test with no sampling
      final inputNoSampling = baseInput.copyWith(abw: null, sampleAgeDays: 0);
      final resultNoSampling = MasterFeedEngine.orchestrate(inputNoSampling);

      // Test with sampling (different ABW)
      final inputWithSampling = baseInput.copyWith(abw: 15.0, sampleAgeDays: 2);
      final resultWithSampling = MasterFeedEngine.orchestrate(inputWithSampling);

      // Feed should be identical
      expect(
        resultWithSampling.finalFeed,
        resultNoSampling.finalFeed,
        reason: 'Feed should not change when sampling is added/modified',
      );

      expect(
        resultWithSampling.correction.trayFactor,
        resultNoSampling.correction.trayFactor,
        reason: 'Tray factor should be identical',
      );
    });

    test('Case 2: Change water (normal range) → feed MUST NOT change', () {
      // Test with normal water
      final inputNormalWater = baseInput.copyWith(
        dissolvedOxygen: 5.0,
        ammonia: 0.1,
      );
      final resultNormalWater = MasterFeedEngine.orchestrate(inputNormalWater);

      // Test with different but still safe water
      final inputDifferentWater = baseInput.copyWith(
        dissolvedOxygen: 6.5,
        ammonia: 0.05,
      );
      final resultDifferentWater = MasterFeedEngine.orchestrate(inputDifferentWater);

      // Feed should be identical
      expect(
        resultDifferentWater.finalFeed,
        resultNormalWater.finalFeed,
        reason: 'Feed should not change with normal water variations',
      );

      expect(
        resultDifferentWater.correction.trayFactor,
        resultNormalWater.correction.trayFactor,
        reason: 'Tray factor should be identical',
      );
    });

    test('Case 3: Change tray → feed MUST change', () {
      // Test with empty trays (should increase feed)
      final inputEmptyTrays = baseInput.copyWith(
        trayStatuses: [TrayStatus.empty, TrayStatus.empty, TrayStatus.empty],
      );
      final resultEmptyTrays = MasterFeedEngine.orchestrate(inputEmptyTrays);

      // Test with full trays (should decrease feed)
      final inputFullTrays = baseInput.copyWith(
        trayStatuses: [TrayStatus.full, TrayStatus.full, TrayStatus.full],
      );
      final resultFullTrays = MasterFeedEngine.orchestrate(inputFullTrays);

      // Test with partial trays (baseline)
      final inputPartialTrays = baseInput.copyWith(
        trayStatuses: [TrayStatus.partial, TrayStatus.partial, TrayStatus.partial],
      );
      final resultPartialTrays = MasterFeedEngine.orchestrate(inputPartialTrays);

      // Feed should be different based on tray status
      expect(
        resultEmptyTrays.finalFeed,
        greaterThan(resultPartialTrays.finalFeed),
        reason: 'Empty trays should increase feed compared to partial trays',
      );

      expect(
        resultPartialTrays.finalFeed,
        greaterThan(resultFullTrays.finalFeed),
        reason: 'Partial trays should increase feed compared to full trays',
      );

      // Tray factors should be different
      expect(
        resultEmptyTrays.correction.trayFactor,
        greaterThan(resultPartialTrays.correction.trayFactor),
        reason: 'Empty trays should have higher tray factor',
      );

      expect(
        resultPartialTrays.correction.trayFactor,
        greaterThan(resultFullTrays.correction.trayFactor),
        reason: 'Partial trays should have higher tray factor than full trays',
      );
    });

    test('Case 4: DO critical → feed MUST STOP', () {
      // Test with critical DO
      final inputCriticalDO = baseInput.copyWith(dissolvedOxygen: 2.0);
      final resultCriticalDO = MasterFeedEngine.orchestrate(inputCriticalDO);

      // Feed should be stopped
      expect(
        resultCriticalDO.finalFeed,
        0.0,
        reason: 'Feed should stop when DO is critical',
      );

      expect(
        resultCriticalDO.correction.safetyStatus,
        'stopped',
        reason: 'Safety status should be stopped',
      );

      expect(
        resultCriticalDO.correction.isCriticalStop,
        true,
        reason: 'Should be marked as critical stop',
      );
    });

    test('Case 5: Extreme ammonia → feed MUST STOP', () {
      // Test with extreme ammonia
      final inputExtremeAmmonia = baseInput.copyWith(ammonia: 3.0);
      final resultExtremeAmmonia = MasterFeedEngine.orchestrate(inputExtremeAmmonia);

      // Feed should be stopped
      expect(
        resultExtremeAmmonia.finalFeed,
        0.0,
        reason: 'Feed should stop when ammonia is extreme',
      );

      expect(
        resultExtremeAmmonia.correction.safetyStatus,
        'stopped',
        reason: 'Safety status should be stopped',
      );

      expect(
        resultExtremeAmmonia.correction.isCriticalStop,
        true,
        reason: 'Should be marked as critical stop',
      );
    });

    test('Validation: Feed calculation uses only DOC, shrimp count, tray', () {
      // Test that feed calculation pipeline is simplified
      final result = MasterFeedEngine.orchestrate(baseInput);

      // Verify base feed is calculated from DOC and shrimp count
      expect(
        result.baseFeed,
        greaterThan(0.0),
        reason: 'Base feed should be calculated from DOC curve',
      );

      // Verify only tray factor is applied
      expect(
        result.correction.trayFactor,
        1.0, // Partial trays should give neutral factor
        reason: 'Partial trays should give neutral tray factor',
      );

      // Verify safety status is normal
      expect(
        result.correction.safetyStatus,
        'normal',
        reason: 'Safety status should be normal with good conditions',
      );

      // Verify final feed equals base feed * tray factor
      expect(
        result.finalFeed,
        result.baseFeed * result.correction.trayFactor,
        reason: 'Final feed should equal base feed times tray factor',
      );
    });

    test('Validation: Growth and environment factors are neutralized', () {
      // Test that removed factors return neutral values
      final growthFactor = calculateGrowthFactor(15.0, 45, 2);
      final envFactor = calculateEnvironmentFactor(5.0, 0.1);

      // These functions should still exist but return 1.0 (neutral)
      expect(
        growthFactor,
        1.0,
        reason: 'Growth factor should be neutral (1.0) - not used in feed calc',
      );

      expect(
        envFactor,
        1.0,
        reason: 'Environment factor should be neutral (1.0) - not used in feed calc',
      );
    });

    test('Validation: Blind phase (DOC ≤ 30) has no adjustments', () {
      // Test with DOC in blind phase
      final blindInput = baseInput.copyWith(
        doc: 25,
        trayStatuses: [TrayStatus.empty, TrayStatus.empty, TrayStatus.empty],
      );
      final blindResult = MasterFeedEngine.orchestrate(blindInput);

      // In blind phase, tray factor should be 1.0 (no adjustments)
      expect(
        blindResult.correction.trayFactor,
        1.0,
        reason: 'Blind phase should not apply tray adjustments',
      );

      expect(
        blindResult.correction.isSmartApplied,
        false,
        reason: 'Smart feeding should not be applied in blind phase',
      );

      // Final feed should equal base feed
      expect(
        blindResult.finalFeed,
        blindResult.baseFeed,
        reason: 'Final feed should equal base feed in blind phase',
      );
    });
  });
}
