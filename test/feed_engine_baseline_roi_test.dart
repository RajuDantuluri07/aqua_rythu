// Feed Engine Baseline + ROI System Test Cases
//
// Comprehensive test suite for the new feed engine components:
// - Baseline Calculator
// - Smart Feed Service  
// - ROI Calculator
// - Confidence Service
// - Reason Builder
// - Feed Pipeline (Orchestrator)
//
// Test cases cover all scenarios from the DEV TICKET requirements

import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/feed/baseline_calculator.dart';
import 'package:aqua_rythu/systems/feed/smart_feed_service.dart';
import 'package:aqua_rythu/systems/feed/roi_calculator.dart';
import 'package:aqua_rythu/systems/feed/confidence_service.dart';
import 'package:aqua_rythu/systems/feed/reason_builder.dart';
import 'package:aqua_rythu/systems/feed/feed_pipeline.dart';
import 'package:aqua_rythu/features/tray/enums/tray_status.dart';

void main() {
  group('Baseline Calculator Tests', () {
    test('Case 1: Normal DOC 30 with sampling data', () {
      final result = BaselineCalculator.calculateBaselineFeed(
        doc: 30,
        shrimpCount: 10000,
        sampledAbw: 5.0,
        survivalRate: 0.85,
      );

      expect(result, greaterThan(0.0));
      expect(result, lessThan(100.0)); // Reasonable upper bound
    });

    test('Case 2: Early DOC without sampling data', () {
      final result = BaselineCalculator.calculateBaselineFeed(
        doc: 15,
        shrimpCount: 10000,
        sampledAbw: null,
        survivalRate: 0.85,
      );

      expect(result, greaterThan(0.0));
      // Should use estimated ABW for DOC 15
    });

    test('Case 3: Late DOC with high survival rate', () {
      final result = BaselineCalculator.calculateBaselineFeed(
        doc: 90,
        shrimpCount: 10000,
        sampledAbw: 20.0,
        survivalRate: 0.90,
      );

      expect(result, greaterThan(0.0));
      expect(result, lessThan(200.0));
    });

    test('ABW estimation from DOC', () {
      expect(BaselineCalculator.estimateAbwFromDoc(15), equals(3.5));
      expect(BaselineCalculator.estimateAbwFromDoc(45), equals(11.0));
      expect(BaselineCalculator.estimateAbwFromDoc(75), equals(17.0));
      expect(BaselineCalculator.estimateAbwFromDoc(105), equals(22.5));
    });

    test('Feed rate by DOC and ABW', () {
      expect(BaselineCalculator.getFeedRate(15, 3.0), equals(0.06));
      expect(BaselineCalculator.getFeedRate(45, 12.0), equals(0.05));
      expect(BaselineCalculator.getFeedRate(75, 18.0), equals(0.025));
      expect(BaselineCalculator.getFeedRate(105, 25.0), equals(0.02));
    });

    test('Invalid inputs validation', () {
      final validation = BaselineCalculator.validateParameters(
        doc: -1,
        shrimpCount: 10000,
        sampledAbw: 5.0,
        survivalRate: 0.85,
      );

      expect(validation.isValid, isFalse);
      expect(validation.errorMessage, contains('DOC must be positive'));
    });
  });

  group('Smart Feed Service Tests', () {
    test('Case 1: Normal optimization - 10% reduction', () {
      final result = SmartFeedService.applySmartAdjustments(
        baselineFeed: 30.0,
        trayFactor: 0.90,
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      expect(result, equals(27.0)); // 30 * 0.90
    });

    test('Case 2: Feed increase within safety caps', () {
      final result = SmartFeedService.applySmartAdjustments(
        baselineFeed: 30.0,
        trayFactor: 1.10,
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      expect(result, equals(33.0)); // 30 * 1.10 (within +12% cap)
    });

    test('Case 3: Extreme adjustment attempt - capped at +12%', () {
      final result = SmartFeedService.applySmartAdjustments(
        baselineFeed: 30.0,
        trayFactor: 1.30, // Would be 39kg (30% increase)
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      expect(result, equals(33.6)); // Capped at 30 * 1.12 = 33.6
    });

    test('Case 4: Extreme reduction attempt - capped at -12%', () {
      final result = SmartFeedService.applySmartAdjustments(
        baselineFeed: 30.0,
        trayFactor: 0.70, // Would be 21kg (30% reduction)
        growthFactor: 1.0,
        fcrFactor: 1.0,
      );

      expect(result, equals(26.4)); // Capped at 30 * 0.88 = 26.4
    });

    test('Tray factor calculation', () {
      // Mostly full trays
      final fullFactor = SmartFeedService.calculateTrayFactor([
        TrayStatus.full,
        TrayStatus.full,
        TrayStatus.full,
        TrayStatus.partial,
      ]);
      expect(fullFactor, equals(0.85));

      // Mostly empty trays
      final emptyFactor = SmartFeedService.calculateTrayFactor([
        TrayStatus.empty,
        TrayStatus.empty,
        TrayStatus.empty,
        TrayStatus.partial,
      ]);
      expect(emptyFactor, equals(1.08));

      // No data
      final noDataFactor = SmartFeedService.calculateTrayFactor(null);
      expect(noDataFactor, equals(1.0));
    });

    test('Growth factor calculation', () {
      // Growth behind target
      final behindFactor = SmartFeedService.calculateGrowthFactor(
        currentAbw: 8.0,
        expectedAbw: 10.0,
        previousGrowthRate: 0.2,
      );
      expect(behindFactor, equals(1.08));

      // Growth ahead of target
      final aheadFactor = SmartFeedService.calculateGrowthFactor(
        currentAbw: 12.0,
        expectedAbw: 10.0,
        previousGrowthRate: 0.3,
      );
      expect(aheadFactor, equals(0.92));
    });
  });

  group('ROI Calculator Tests', () {
    test('Case 1: Normal optimization - savings > 0', () {
      final result = RoiCalculator.calculateDailySavings(
        baselineFeed: 30.0,
        actualFeed: 27.0,
        feedCost: 60.0,
      );

      expect(result, equals(180.0)); // (30-27) * 60 = 180
    });

    test('Case 2: Feed increased - savings = 0', () {
      final result = RoiCalculator.calculateDailySavings(
        baselineFeed: 30.0,
        actualFeed: 32.0,
        feedCost: 60.0,
      );

      expect(result, equals(0.0)); // No negative savings
    });

    test('Case 3: No savings - same amounts', () {
      final result = RoiCalculator.calculateDailySavings(
        baselineFeed: 30.0,
        actualFeed: 30.0,
        feedCost: 60.0,
      );

      expect(result, equals(0.0));
    });

    test('Cumulative savings calculation', () {
      final result = RoiCalculator.updateCumulativeSavings(
        previousTotal: 8000.0,
        todaySavings: 180.0,
      );

      expect(result, equals(8180.0));
    });

    test('Feed efficiency calculation', () {
      final result = RoiCalculator.calculateFeedEfficiency(
        baselineFeed: 30.0,
        actualFeed: 27.0,
      );

      expect(result, equals(90.0)); // 27/30 * 100 = 90%
    });

    test('ROI percentage calculation', () {
      final result = RoiCalculator.calculateRoiPercentage(
        totalSavings: 1800.0,
        totalFeedCost: 18000.0,
      );

      expect(result, equals(10.0)); // 1800/18000 * 100 = 10%
    });

    test('Invalid inputs validation', () {
      final validation = RoiCalculator.validateInputs(
        baselineFeed: -1.0,
        actualFeed: 27.0,
        feedCost: 60.0,
      );

      expect(validation.isValid, isFalse);
      expect(validation.errors, contains('Baseline feed must be positive'));
    });
  });

  group('Confidence Service Tests', () {
    test('Case 1: High confidence - tray + sampling data', () {
      final result = ConfidenceService.getConfidence(
        hasTrayData: true,
        hasSampling: true,
        hasWaterQuality: true,
        dataRecencyHours: 1,
        trayConsistency: 0.9,
      );

      expect(result, equals('high'));
    });

    test('Case 2: Medium confidence - tray data only', () {
      final result = ConfidenceService.getConfidence(
        hasTrayData: true,
        hasSampling: false,
        hasWaterQuality: false,
        dataRecencyHours: 4,
        trayConsistency: 0.7,
      );

      expect(result, equals('medium'));
    });

    test('Case 3: Low confidence - no data', () {
      final result = ConfidenceService.getConfidence(
        hasTrayData: false,
        hasSampling: false,
        hasWaterQuality: false,
        dataRecencyHours: 48,
        trayConsistency: 0.0,
      );

      expect(result, equals('low'));
    });

    test('Tray consistency calculation', () {
      // Highly consistent
      final highConsistency = ConfidenceService.calculateTrayConsistency([
        TrayStatus.full,
        TrayStatus.full,
        TrayStatus.full,
        TrayStatus.full,
      ]);
      expect(highConsistency, equals(1.0));

      // Mixed consistency
      final mediumConsistency = ConfidenceService.calculateTrayConsistency([
        TrayStatus.full,
        TrayStatus.empty,
        TrayStatus.partial,
        TrayStatus.full,
      ]);
      expect(mediumConsistency, equals(0.5));
    });

    test('Data recency evaluation', () {
      final now = DateTime.now();
      
      // Very recent
      final veryRecent = ConfidenceService.evaluateDataRecency(
        now.subtract(const Duration(hours: 1))
      );
      expect(veryRecent, equals(1.0));

      // Same day
      final sameDay = ConfidenceService.evaluateDataRecency(
        now.subtract(const Duration(hours: 12))
      );
      expect(sameDay, equals(0.4));

      // Stale data
      final stale = ConfidenceService.evaluateDataRecency(
        now.subtract(const Duration(hours: 72))
      );
      expect(stale, equals(0.0));
    });
  });

  group('Reason Builder Tests', () {
    test('Case 1: Tray leftover detected', () {
      final result = ReasonBuilder.buildReason(
        trayLeftover: true,
        growthSlow: false,
        confidenceLevel: 'medium',
      );

      expect(result, contains('Tray leftover detected'));
    });

    test('Case 2: Growth below expected', () {
      final result = ReasonBuilder.buildReason(
        trayLeftover: false,
        growthSlow: true,
        confidenceLevel: 'medium',
      );

      expect(result, contains('Growth below expected'));
    });

    test('Case 3: Standard optimization', () {
      final result = ReasonBuilder.buildReason(
        trayLeftover: false,
        growthSlow: false,
        confidenceLevel: 'high',
      );

      expect(result, equals('Standard optimization applied'));
    });

    test('Detailed reason with multiple factors', () {
      final result = ReasonBuilder.buildDetailedReason(
        trayStatuses: [TrayStatus.full, TrayStatus.full, TrayStatus.empty],
        currentAbw: 8.0,
        expectedAbw: 10.0,
        currentFcr: 1.6,
        targetFcr: 1.4,
        confidenceLevel: 'medium',
      );

      expect(result, contains('tray'));
      expect(result, contains('growth'));
      expect(result, contains('FCR'));
    });

    test('Tray pattern analysis', () {
      // Mostly full
      final fullPattern = ReasonBuilder.analyzeTrayPattern([
        TrayStatus.full,
        TrayStatus.full,
        TrayStatus.full,
        TrayStatus.partial,
      ]);
      expect(fullPattern, contains('poor appetite'));
      expect(fullPattern, contains('reduced feeding'));

      // Mostly empty
      final emptyPattern = ReasonBuilder.analyzeTrayPattern([
        TrayStatus.empty,
        TrayStatus.empty,
        TrayStatus.empty,
        TrayStatus.partial,
      ]);
      expect(emptyPattern, contains('good appetite'));
      expect(emptyPattern, contains('increased feeding'));
    });

    test('Growth pattern analysis', () {
      // Behind target
      final behindGrowth = ReasonBuilder.analyzeGrowthPattern(8.0, 10.0);
      expect(behindGrowth, contains('behind target'));
      expect(behindGrowth, contains('increased feeding'));

      // Ahead of target
      final aheadGrowth = ReasonBuilder.analyzeGrowthPattern(12.0, 10.0);
      expect(aheadGrowth, contains('ahead of target'));
      expect(aheadGrowth, contains('reduced feeding'));
    });
  });

  group('Feed Pipeline Integration Tests', () {
    test('Case 1: Normal optimization pipeline', () async {
      final pond = PondData(
        id: 'test-pond-1',
        doc: 45,
        shrimpCount: 10000,
        sampledAbw: 12.0,
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        trayFactor: 0.92,
        growthFactor: 1.0,
        fcrFactor: 1.0,
        hasTrayData: true,
        hasSampling: true,
        trayLeftover: true,
        growthSlow: false,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      expect(result.isError, isFalse);
      expect(result.baselineFeed, greaterThan(0.0));
      expect(result.actualFeed, lessThan(result.baselineFeed)); // Reduction applied
      expect(result.dailySavings, greaterThan(0.0));
      expect(result.confidence, equals('high'));
      expect(result.reason, contains('Tray leftover'));
    });

    test('Case 2: Feed increased scenario', () async {
      final pond = PondData(
        id: 'test-pond-2',
        doc: 60,
        shrimpCount: 10000,
        sampledAbw: 18.0,
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        trayFactor: 1.08,
        growthFactor: 1.0,
        fcrFactor: 1.0,
        hasTrayData: true,
        hasSampling: true,
        trayLeftover: false,
        growthSlow: false,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      expect(result.isError, isFalse);
      expect(result.actualFeed, greaterThan(result.baselineFeed)); // Increase applied
      expect(result.dailySavings, equals(0.0)); // No savings when feed increased
    });

    test('Case 3: No data - low confidence', () async {
      final pond = PondData(
        id: 'test-pond-3',
        doc: 30,
        shrimpCount: 10000,
        sampledAbw: null, // No sampling
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
        trayFactor: 1.0,
        growthFactor: 1.0,
        fcrFactor: 1.0,
        hasTrayData: false,
        hasSampling: false,
        trayLeftover: false,
        growthSlow: false,
      );

      final result = await FeedPipeline.runDailyFeedEngine(pond);

      expect(result.isError, isFalse);
      expect(result.confidence, equals('low'));
      expect(result.actualFeed, closeTo(result.baselineFeed, 0.1)); // Minimal adjustments
      expect(result.reason, contains('Standard optimization'));
    });

    test('Pond data validation', () {
      final invalidPond = PondData(
        id: '', // Invalid ID
        doc: -1, // Invalid DOC
        shrimpCount: 0, // Invalid count
        sampledAbw: null,
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
      );

      final validation = FeedPipeline.validatePondData(invalidPond);

      expect(validation.isValid, isFalse);
      expect(validation.errors.length, greaterThan(2));
    });

    test('Error handling in pipeline', () async {
      final invalidPond = PondData(
        id: 'test-pond-error',
        doc: 45,
        shrimpCount: -1000, // Should cause error
        sampledAbw: 12.0,
        survivalRate: 0.85,
        feedCostPerKg: 60.0,
      );

      final result = await FeedPipeline.runDailyFeedEngine(invalidPond);

      expect(result.isError, isTrue);
      expect(result.error, isNotNull);
      expect(result.error, isNotEmpty);
    });
  });

  group('Edge Cases and Boundary Tests', () {
    test('Zero shrimp count handling', () {
      final result = BaselineCalculator.calculateBaselineFeed(
        doc: 45,
        shrimpCount: 0,
        sampledAbw: 12.0,
        survivalRate: 0.85,
      );

      expect(result, equals(0.0));
    });

    test('Maximum reasonable values', () {
      final result = BaselineCalculator.calculateBaselineFeed(
        doc: 120,
        shrimpCount: 1000000,
        sampledAbw: 30.0,
        survivalRate: 0.95,
      );

      expect(result, greaterThan(0.0));
      expect(result, lessThan(10000.0)); // Reasonable upper bound
    });

    test('Negative savings prevention', () {
      final result = RoiCalculator.calculateDailySavings(
        baselineFeed: 25.0,
        actualFeed: 30.0, // More than baseline
        feedCost: 60.0,
      );

      expect(result, equals(0.0)); // Never negative
    });

    test('Confidence score boundaries', () {
      // Test exact boundary at 80 points (should be high)
      final highBoundary = ConfidenceService.getConfidence(
        hasTrayData: true, // 30 points
        hasSampling: true, // 30 points
        dataRecencyHours: 1, // 15 points
        trayConsistency: 0.8, // 10 points bonus
      );
      expect(highBoundary, equals('high'));

      // Test exact boundary at 50 points (should be medium)
      final mediumBoundary = ConfidenceService.getConfidence(
        hasTrayData: true, // 30 points
        hasSampling: false, // 0 points
        dataRecencyHours: 6, // 10 points
        trayConsistency: 0.8, // 10 points bonus = 50
      );
      expect(mediumBoundary, equals('medium'));
    });
  });

  group('Performance Tests', () {
    test('Pipeline performance with large dataset', () async {
      final stopwatch = Stopwatch()..start();

      // Run pipeline multiple times to test performance
      for (int i = 0; i < 100; i++) {
        final pond = PondData(
          id: 'perf-test-$i',
          doc: 45 + (i % 60),
          shrimpCount: 10000 + (i * 100),
          sampledAbw: 12.0 + (i * 0.1),
          survivalRate: 0.85,
          feedCostPerKg: 60.0,
          hasTrayData: i % 2 == 0,
          hasSampling: i % 3 == 0,
        );

        await FeedPipeline.runDailyFeedEngine(pond);
      }

      stopwatch.stop();

      // Should complete 100 iterations in reasonable time (< 5 seconds)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
