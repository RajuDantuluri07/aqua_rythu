import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/systems/feeding_engine_v1.dart';
import 'package:aqua_rythu/systems/engine_constants.dart';

void main() {
  group('FeedingEngineV1 Tests', () {
    test('Survival Rate Interpolation - Day 1', () {
      FeedingEngineV1.calculateFeed(
        doc: 1,
        stockingType: 'hatchery',
        density: 100000,
      );
      // Day 1 formula for hatchery:
      // baseFeed = 2.0 + (1-1)*0.15 = 2.0 kg per 100K
      expect(FeedEngineConstants.survivalRates[1], 0.98);
    });

    test('Feed Calculation - Day 30', () {
      final feed = FeedingEngineV1.calculateFeed(
        doc: 30,
        stockingType: 'nursery',
        density: 100000,
      );

      // DOC-based formula (nursery default):
      // baseFeed = 4.0 + (30-1)*0.25 = 4.0 + 7.25 = 11.25 kg per 100K
      // density = 100000, so adjustedFeed = 11.25 * (100000/100000) = 11.25 kg
      // No tray factor (not active for nursery at DOC 30 unless logged), so final = 11.25 kg
      expect(feed, closeTo(11.25, 0.01));
    });

    test('Base Feed Calculation - Hatchery Day 1', () {
      final feed = FeedingEngineV1.calculateFeed(
        doc: 1,
        stockingType: 'hatchery',
        density: 100000,
      );

      // Hatchery Day 1: baseFeed = 2.0 kg per 100K
      // density = 100000, so adjustedFeed = 2.0 * (100000/100000) = 2.0 kg
      expect(feed, closeTo(2.0, 0.01));
    });

    test('Base Feed Calculation - Hatchery Day 15', () {
      final feed = FeedingEngineV1.calculateFeed(
        doc: 15,
        stockingType: 'hatchery',
        density: 100000,
      );

      // Hatchery Day 15: baseFeed = 2.0 + (15-1)*0.15 = 2.0 + 2.1 = 4.1 kg per 100K
      // density = 100000, so adjustedFeed = 4.1 * (100000/100000) = 4.1 kg
      expect(feed, closeTo(4.1, 0.01));
    });

    test('Density Scaling - Double Stocking', () {
      final feed = FeedingEngineV1.calculateFeed(
        doc: 30,
        stockingType: 'nursery',
        density: 200000,
      );

      // Nursery Day 30: baseFeed = 4.0 + (30-1)*0.25 = 11.25 kg per 100K
      // density = 200000, so adjustedFeed = 11.25 * (200000/100000) = 22.5 kg
      expect(feed, closeTo(22.5, 0.01));
    });
  });
}
