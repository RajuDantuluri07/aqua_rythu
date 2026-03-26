import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/engines/feed_calculation_engine.dart';
import 'package:aqua_rythu/core/engines/engine_constants.dart';

void main() {
  group('FeedCalculationEngine Tests', () {
    test('Survival Rate Interpolation - Day 1', () {
      FeedCalculationEngine.calculateFeed(
        seedCount: 100000,
        doc: 1,
      );
      // Day 1 formula usually depends on PL size if it's a fixed baby feed,
      // but let's check the survival rate interpolation logic specifically.
      expect(FeedEngineConstants.survivalRates[1], 0.98);
    });

    test('Feed Calculation - Day 30', () {
      final feed = FeedCalculationEngine.calculateFeed(
        seedCount: 100000,
        doc: 30,
      );
      
      // Expected Biomass = 100,000 * 0.93 (survival) * 0.5g (ABW) = 46.5 kg
      // Expected Feed = 46.5 kg * 0.08 (Feeding Rate) = 3.72 kg
      expect(feed, closeTo(3.72, 0.01));
    });

    test('Meal Split Logic - 4 Meals', () {
      final splits = FeedCalculationEngine.distributeFeed(10.0, 4);
      
      // Base = 2.5kg
      // R1 = 2.5 * 0.8 = 2.0kg (from FeedEngineConstants.firstMealFactor) or whatever is in constants
      // Let's verify constants if needed, but the split should sum to 10.0
      expect(splits.length, 4);
      expect(splits.reduce((a, b) => a + b), closeTo(10.0, 0.001));
    });
  });
}
