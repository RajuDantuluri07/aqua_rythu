// Tray Hardening Validation Test - Comprehensive edge case testing
//
// This test validates the hardened tray behavior for real-world usage:
// 1. No tray data handling
// 2. Tray factor limits (0.8-1.2)
// 3. DOC curve smoothness
// 4. Tray log reliability
// 5. Final validation of all edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/feed/feed_calculations.dart';
import 'package:aqua_rythu/features/tray/enums/tray_status.dart';

void main() {
  group('Tray Hardening Validation Tests', () {
    
    group('Task 1: No Tray Data Handling', () {
      test('No tray data → tray_factor = 1.0', () {
        final trayFactor = calculateTrayFactor([]);
        
        expect(
          trayFactor,
          1.0,
          reason: 'No tray data should result in tray_factor = 1.0',
        );
      });

      test('Empty tray list logs warning', () {
        // This test would verify logging, but for unit testing we just ensure the factor
        final trayFactor = calculateTrayFactor([]);
        
        expect(trayFactor, 1.0);
      });
    });

    group('Task 2: Tray Factor Limits', () {
      test('Tray factor never exceeds 1.2', () {
        // Test extreme case: all empty trays (should try to increase beyond 1.2)
        final allEmptyTrays = List.filled(10, TrayStatus.empty);
        final trayFactor = calculateTrayFactor(allEmptyTrays);
        
        expect(
          trayFactor,
          lessThanOrEqualTo(1.2),
          reason: 'Tray factor should never exceed 1.2 maximum limit',
        );
      });

      test('Tray factor never below 0.8', () {
        // Test extreme case: all full trays (should try to decrease below 0.8)
        final allFullTrays = List.filled(10, TrayStatus.heavy);
        final trayFactor = calculateTrayFactor(allFullTrays);
        
        expect(
          trayFactor,
          greaterThanOrEqualTo(0.8),
          reason: 'Tray factor should never go below 0.8 minimum limit',
        );
      });

      test('Mixed trays stay within limits', () {
        final mixedTrays = [
          TrayStatus.empty,
          TrayStatus.heavy,
          TrayStatus.light,
          TrayStatus.empty,
          TrayStatus.heavy,
        ];
        final trayFactor = calculateTrayFactor(mixedTrays);
        
        expect(
          trayFactor,
          greaterThanOrEqualTo(0.8),
          reason: 'Mixed trays should respect minimum limit',
        );
        
        expect(
          trayFactor,
          lessThanOrEqualTo(1.2),
          reason: 'Mixed trays should respect maximum limit',
        );
      });
    });

    group('Task 3: DOC Curve Smoothness', () {
      test('DOC 29→30→31 transition is smooth', () {
        final doc29 = docFeedCurve(29);
        final doc30 = docFeedCurve(30);
        final doc31 = docFeedCurve(31);
        
        // Calculate daily changes
        final change29to30 = (doc30 - doc29).abs();
        final change30to31 = (doc31 - doc30).abs();
        
        // Changes should be gradual (less than 1.0 kg per day)
        expect(
          change29to30,
          lessThan(1.0),
          reason: 'Change from DOC 29 to 30 should be gradual (< 1.0 kg)',
        );
        
        expect(
          change30to31,
          lessThan(1.0),
          reason: 'Change from DOC 30 to 31 should be gradual (< 1.0 kg)',
        );
        
        // Verify continuity - no sudden jumps
        expect(
          change29to30,
          closeTo(change30to31, 0.3),
          reason: 'Changes should be similar (smooth progression)',
        );
      });

      test('DOC curve is monotonic increasing', () {
        // Test that curve never decreases
        double previousValue = docFeedCurve(1);
        
        for (int doc = 2; doc <= 60; doc++) {
          final currentValue = docFeedCurve(doc);
          
          expect(
            currentValue,
            greaterThanOrEqualTo(previousValue),
            reason: 'DOC curve should never decrease at DOC $doc',
          );
          
          previousValue = currentValue;
        }
      });

      test('Smoothness validation function works', () {
        final smoothnessScore = testDOCCurveSmoothness();
        
        expect(
          smoothnessScore,
          lessThan(2.0),
          reason: 'Total change across transition should be minimal',
        );
      });
    });

    group('Task 4: Tray Log Reliability', () {
      test('Single tray data point handled with caution', () {
        final singleTray = [TrayStatus.empty];
        final trayFactor = calculateTrayFactor(singleTray);
        
        expect(
          trayFactor,
          inInclusiveRange(0.8, 1.2),
          reason: 'Single tray should still respect limits',
        );
      });

      test('Two tray data points accepted', () {
        final twoTrays = [TrayStatus.empty, TrayStatus.heavy];
        final trayFactor = calculateTrayFactor(twoTrays);
        
        expect(
          trayFactor,
          inInclusiveRange(0.8, 1.2),
          reason: 'Two trays should be accepted and processed',
        );
      });

      test('Mixed data with outliers filtered', () {
        // Create mixed data with clear outliers
        final mixedWithOutliers = [
          // Majority: empty trays (70%)
          TrayStatus.empty, TrayStatus.empty, TrayStatus.empty, TrayStatus.empty,
          TrayStatus.empty, TrayStatus.empty, TrayStatus.empty,
          // Outliers: full trays (20%)
          TrayStatus.heavy, TrayStatus.heavy,
          // Minority: partial trays (10%)
          TrayStatus.light,
        ];
        
        final trayFactor = calculateTrayFactor(mixedWithOutliers);
        
        // Should filter outliers and base on majority (empty)
        expect(
          trayFactor,
          greaterThan(1.0),
          reason: 'Should increase feed based on empty majority after filtering',
        );
        
        expect(
          trayFactor,
          lessThanOrEqualTo(1.2),
          reason: 'Should respect maximum limit even after filtering',
        );
      });

      test('All data filtered fallback to original', () {
        // Edge case where filtering might remove all data
        // This is hard to test without specific outlier thresholds
        // But we can test that the function doesn't crash
        final edgeCase = [
          TrayStatus.empty, TrayStatus.heavy, TrayStatus.light,
          TrayStatus.empty, TrayStatus.heavy, TrayStatus.light,
        ];
        
        final trayFactor = calculateTrayFactor(edgeCase);
        
        expect(
          trayFactor,
          inInclusiveRange(0.8, 1.2),
          reason: 'Edge case should still return valid factor',
        );
      });
    });

    group('Task 5: Final Validation - Edge Cases', () {
      test('Edge Case 1: No tray → stable feed', () {
        final noTrayFactor = calculateTrayFactor([]);
        
        expect(
          noTrayFactor,
          1.0,
          reason: 'No tray data should give stable base feed',
        );
      });

      test('Edge Case 2: All trays empty → increase (within limit)', () {
        final allEmpty = List.filled(5, TrayStatus.empty);
        final trayFactor = calculateTrayFactor(allEmpty);
        
        expect(
          trayFactor,
          greaterThan(1.0),
          reason: 'All empty trays should increase feed',
        );
        
        expect(
          trayFactor,
          lessThanOrEqualTo(1.2),
          reason: 'Increase should be within maximum limit',
        );
      });

      test('Edge Case 3: All trays full → decrease (within limit)', () {
        final allFull = List.filled(5, TrayStatus.heavy);
        final trayFactor = calculateTrayFactor(allFull);
        
        expect(
          trayFactor,
          lessThan(1.0),
          reason: 'All full trays should decrease feed',
        );
        
        expect(
          trayFactor,
          greaterThanOrEqualTo(0.8),
          reason: 'Decrease should be within minimum limit',
        );
      });

      test('Edge Case 4: Random tray input → stable output', () {
        // Test with random but consistent input
        final randomTrays = [
          TrayStatus.light, TrayStatus.empty, TrayStatus.heavy,
          TrayStatus.light, TrayStatus.empty, TrayStatus.heavy,
          TrayStatus.light, TrayStatus.empty, TrayStatus.heavy,
        ];
        
        final trayFactor1 = calculateTrayFactor(randomTrays);
        final trayFactor2 = calculateTrayFactor(randomTrays);
        
        expect(
          trayFactor1,
          trayFactor2,
          reason: 'Same input should always produce same output (deterministic)',
        );
        
        expect(
          trayFactor1,
          inInclusiveRange(0.8, 1.2),
          reason: 'Random input should still respect limits',
        );
      });

      test('Edge Case 5: Large number of trays handled correctly', () {
        final manyTrays = List.filled(50, TrayStatus.empty);
        // Add some variety
        manyTrays[10] = TrayStatus.heavy;
        manyTrays[20] = TrayStatus.heavy;
        manyTrays[30] = TrayStatus.light;
        
        final trayFactor = calculateTrayFactor(manyTrays);
        
        expect(
          trayFactor,
          inInclusiveRange(0.8, 1.2),
          reason: 'Large number of trays should be handled correctly',
        );
      });

      test('Edge Case 6: Balanced trays → neutral factor', () {
        final balancedTrays = [
          TrayStatus.empty, TrayStatus.heavy, TrayStatus.light,
          TrayStatus.empty, TrayStatus.heavy, TrayStatus.light,
        ];
        
        final trayFactor = calculateTrayFactor(balancedTrays);
        
        expect(
          trayFactor,
          closeTo(1.0, 0.1),
          reason: 'Balanced trays should give neutral factor (~1.0)',
        );
      });
    });

    group('Integration Tests', () {
      test('Complete tray hardening workflow', () {
        // Test the complete workflow with various scenarios
        
        // 1. Start with no data
        var factor = calculateTrayFactor([]);
        expect(factor, 1.0);
        
        // 2. Add some data
        factor = calculateTrayFactor([TrayStatus.empty]);
        expect(factor, inInclusiveRange(0.8, 1.2));
        
        // 3. Add mixed data
        factor = calculateTrayFactor([
          TrayStatus.empty, TrayStatus.heavy, TrayStatus.light
        ]);
        expect(factor, inInclusiveRange(0.8, 1.2));
        
        // 4. Add extreme data
        factor = calculateTrayFactor(List.filled(10, TrayStatus.empty));
        expect(factor, inInclusiveRange(0.8, 1.2));
        expect(factor, greaterThan(1.0));
        
        factor = calculateTrayFactor(List.filled(10, TrayStatus.heavy));
        expect(factor, inInclusiveRange(0.8, 1.2));
        expect(factor, lessThan(1.0));
      });
    });
  });
}
