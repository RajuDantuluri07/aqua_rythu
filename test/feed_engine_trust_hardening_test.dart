// Feed Engine Trust Hardening Test Cases
//
// Test cases for all new trust hardening features:
// - Dynamic ABW handling + confidence
// - Feed rate based on ABW (not just DOC)
// - Zero-data fallback (no blind smart adjustment)
// - Proper reasoning for BOTH decrease & increase
// - Clear "Today's Feed Action" output
//
// These test cases ensure the system transforms from "algorithm"
// to "trusted advisor" for pilot launch readiness

import 'package:flutter_test/flutter_test.dart';
import '../lib/systems/feed/baseline_calculator.dart';
import '../lib/systems/feed/smart_feed_service.dart';
import '../lib/systems/feed/feed_pipeline.dart';
import '../lib/systems/feed/reason_builder.dart';

void main() {
  group('Trust Hardening - ABW & Confidence', () {
    test('Case 5: No Data - no tray, no sampling', () async {
      // Test zero-data fallback scenario
      final pond = PondData(
        id: 'test-pond-5',
        doc: 45,
        shrimpCount: 10000,
        sampledAbw: null, // No sampling data
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        hasTrayData: false, // No tray data
        hasSampling: false, // No sampling data
        trayFactor: 1.0,
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      // Verify zero-data fallback behavior
      expect(result.isError, isFalse);
      expect(result.actualFeed, equals(result.baselineFeed)); // No adjustments
      expect(result.dailySavings, equals(0.0)); // No savings
      expect(result.confidence, equals('low')); // Low confidence
      expect(result.reason, contains('Insufficient data')); // Fallback reason
      expect(result.action, contains('Feed')); // Action string present
    });

    test('Dynamic ABW with sampling data', () async {
      // Test ABW resolution and confidence downgrade
      final pond = PondData(
        id: 'test-pond-6',
        doc: 60,
        shrimpCount: 10000,
        sampledAbw: 15.0, // Has sampling data
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        hasTrayData: true,
        hasSampling: true,
        trayFactor: 1.0,
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      // Verify ABW-based calculation
      expect(result.isError, isFalse);
      expect(result.abw, equals(15.0)); // Uses sampled ABW
      expect(result.confidence, equals('high')); // High confidence with sampling
      expect(result.feedRate, greaterThan(0.025)); // ABW-based feed rate
    });

    test('Smooth ABW progression - no sudden jumps', () async {
      // Test smooth ABW estimation across DOC range
      for (int doc = 15; doc <= 120; doc += 15) {
        final abw = BaselineCalculator.estimateAbwFromDoc(doc);
        final prevAbw = doc > 15 ? BaselineCalculator.estimateAbwFromDoc(doc - 15) : 0.0;
        
        // Verify smooth progression (no sudden jumps)
        expect(abw - prevAbw, lessThanOrEqualTo(3.0)); // Max 3g jump per 15 days
      }
    });
  });

  group('Trust Hardening - Feed Rate & Reasoning', () {
    test('Case 6: Increase Case - actual > baseline', () async {
      // Test proper reasoning for feed increase
      final pond = PondData(
        id: 'test-pond-7',
        doc: 75,
        shrimpCount: 10000,
        sampledAbw: 22.0,
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        hasTrayData: true,
        hasSampling: true,
        trayFactor: 1.08, // Slight increase
        growthFactor: 1.0,
        fcrFactor: 1.0,
        trayLeftover: false,
        growthSlow: true, // Growth behind - should increase
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      // Verify increase reasoning
      expect(result.isError, isFalse);
      expect(result.actualFeed, greaterThan(result.baselineFeed)); // Increase applied
      expect(result.reason, contains('increased feed')); // Explains increase
      expect(result.action, contains('Feed')); // Clear action
    });

    test('Case 7: Smooth ABW - realistic growth curves', () async {
      // Test ABW-based feed rates work correctly
      final testCases = [
        {'doc': 30, 'abw': 3.5, 'expectedRate': 0.05},
        {'doc': 60, 'abw': 11.0, 'expectedRate': 0.035},
        {'doc': 90, 'abw': 20.0, 'expectedRate': 0.025},
        {'doc': 120, 'abw': 28.0, 'expectedRate': 0.02},
      ];

      for (final testCase in testCases) {
        final feedRate = BaselineCalculator.getFeedRate(testCase['doc'] as int, testCase['abw'] as double);
        
        // Verify ABW-based feed rates
        expect(feedRate, equals(testCase['expectedRate'] as double));
      }
    });
  });

  group('Trust Hardening - Safety & Validation', () {
    test('Safety caps enforced - extreme adjustments', () async {
      // Test that extreme adjustments are properly capped
      final pond = PondData(
        id: 'test-pond-8',
        doc: 45,
        shrimpCount: 10000,
        sampledAbw: 12.0,
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        hasTrayData: true,
        hasSampling: true,
        trayFactor: 1.30, // Would be 30% increase
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      // Verify safety caps (max +12%)
      expect(result.isError, isFalse);
      expect(result.actualFeed, lessThanOrEqualTo(result.baselineFeed * 1.12)); // Capped at +12%
      expect(result.reason, contains('capped')); // Should mention capping
    });

    test('Input validation - edge cases', () {
      // Test robust input validation
      final validation1 = BaselineCalculator.validateParameters(
        doc: -1, // Invalid DOC
        shrimpCount: 10000,
        sampledAbw: 12.0,
        survivalRate: 0.85,
      );
      expect(validation1.isValid, isFalse);
      expect(validation1.errorMessage, contains('DOC must be positive'));

      final validation2 = BaselineCalculator.validateParameters(
        doc: 45,
        shrimpCount: -1000, // Invalid count
        sampledAbw: 12.0,
        survivalRate: 0.85,
      );
      expect(validation2.isValid, isFalse);
      expect(validation2.errorMessage, contains('shrimp count must be positive'));
    });
  });

  group('Trust Hardening - API Response Format', () {
    test('API response includes all required fields', () async {
      // Test complete API response format
      final pond = PondData(
        id: 'test-pond-9',
        doc: 60,
        shrimpCount: 15000,
        sampledAbw: 18.0,
        survivalRate: 0.90,
        feedCostPerKg: 65.0,
        hasTrayData: true,
        hasSampling: true,
        trayFactor: 0.95,
        growthFactor: 1.08,
        fcrFactor: 0.92,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);
      final jsonResponse = result.toJson();

      // Verify all required fields are present
      expect(jsonResponse['baseline_feed'], isNotNull);
      expect(jsonResponse['actual_feed'], isNotNull);
      expect(jsonResponse['daily_savings'], isNotNull);
      expect(jsonResponse['total_savings'], isNotNull);
      expect(jsonResponse['confidence'], isNotNull);
      expect(jsonResponse['reason'], isNotNull);
      expect(jsonResponse['action'], isNotNull); // Action field present
      expect(jsonResponse['abw'], isNotNull);
      expect(jsonResponse['biomass'], isNotNull);
    });
  });
}
