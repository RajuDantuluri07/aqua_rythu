import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/feed/feed_adjustment_engine.dart';
import 'package:aqua_rythu/features/tray/tray_model.dart';
import 'package:aqua_rythu/shared/constants/tray_status.dart';

void main() {
  group('FeedAdjustmentEngine Tests', () {
    // Helper to create logs
    TrayLog createLog(List<TrayFill> trays) {
      return TrayLog(
        pondId: 'test_pond',
        time: DateTime.now(),
        round: 1,
        trays: trays,
      );
    }

    test('should return 0.0 (Maintain) if less than 2 logs are present', () {
      final logs = [
        createLog([TrayFill.empty, TrayFill.empty]),
      ];
      expect(FeedAdjustmentEngine.getFeedAdjustment(logs), 0.0);
    });

    test('should return 0.0 if last 2 logs are inconsistent', () {
      final logs = [
        createLog([TrayFill.empty, TrayFill.empty]), // Hungry (0%)
        createLog([TrayFill.halfEaten, TrayFill.halfEaten]), // Overfed (50%)
      ];
      
      // One suggests increase, one suggests decrease -> Inconsistent -> Maintain
      expect(FeedAdjustmentEngine.getFeedAdjustment(logs), 0.0);
    });

    test('should return +0.10 (10%) for consistent Hungry result (Empty Trays)', () {
      final logs = [
        createLog([TrayFill.empty, TrayFill.empty]), // Hungry
        createLog([TrayFill.empty, TrayFill.empty]), // Hungry
      ];
      expect(FeedAdjustmentEngine.getFeedAdjustment(logs), 0.10);
    });

    test('should return 0.0 for consistent Normal result', () {
      // Normal: Avg score around 1.0 (mostlyEaten=1)
      final logs = [
        createLog([TrayFill.mostlyEaten, TrayFill.mostlyEaten]),
        createLog([TrayFill.mostlyEaten, TrayFill.mostlyEaten]),
      ];
      expect(FeedAdjustmentEngine.getFeedAdjustment(logs), 0.0);
    });

    test('should return -0.10 (-10%) for consistent Overfed result', () {
      // Overfed: Avg score around 2.0 (halfEaten=2)
      final logs = [
        createLog([TrayFill.halfEaten, TrayFill.halfEaten]),
        createLog([TrayFill.halfEaten, TrayFill.halfEaten]),
      ];
      expect(FeedAdjustmentEngine.getFeedAdjustment(logs), -0.10);
    });

    test('should return -0.20 (-20%) for consistent Severe Overfed result (Override Rule)', () {
      // Severe Rule: >= 50% trays are untouched
      // Here 2 out of 4 trays are untouched.
      final logs = [
        createLog([TrayFill.untouched, TrayFill.untouched, TrayFill.empty, TrayFill.empty]), 
        createLog([TrayFill.untouched, TrayFill.untouched, TrayFill.mostlyEaten, TrayFill.empty]), 
      ];
      
      // Even though average might vary, the severe override logic should catch the untouched trays
      expect(FeedAdjustmentEngine.getFeedAdjustment(logs), -0.20);
    });

    test('getSuggestionText returns correct user-friendly messages', () {
      expect(FeedAdjustmentEngine.getSuggestionText(0.10), 
          contains("Increase feed by 10%"));
      expect(FeedAdjustmentEngine.getSuggestionText(0.0), 
          contains("Maintain feed"));
      expect(FeedAdjustmentEngine.getSuggestionText(-0.10), 
          contains("Reduce feed by 10%"));
      expect(FeedAdjustmentEngine.getSuggestionText(-0.20), 
          contains("Reduce feed by 20%"));
    });
  });
}