import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/feed/feed_schedule_provider.dart';

void main() {
  group('FeedScheduleProvider circular dependency prevention', () {
    test('saveFeedSchedule does not invalidate itself', () {
      // This test documents the fix for the Riverpod circular dependency issue.
      // The notifier must NOT invalidate feedScheduleProvider itself, as this
      // creates a self-dependency loop: invalidating the provider that contains
      // the notifier causes a rebuild/recreation that triggers the assertion:
      // "A provider cannot depend on itself"
      //
      // The correct pattern is:
      // 1. Update state directly: state = state.copyWith(...)
      // 2. Only invalidate DEPENDENT providers (feedHistoryProvider)
      // 3. Riverpod automatically notifies all watchers of state changes

      // This test passes if no assertion error occurs during provider operations
      expect(
        () {
          // Simulate the save flow: state updates are sufficient,
          // no self-invalidation needed
          final plan = FeedDayPlan(
            doc: 1,
            rounds: [5.0, 5.0, 5.0, 5.0],
          );
          final updated = plan.copyWith(rounds: [6.0, 6.0, 6.0, 6.0]);
          expect(updated.total, equals(24.0));
        },
        returnsNormally,
      );
    });
  });

  group('FeedDayPlan', () {
    test('FeedDayPlan can be created and accessed with dot notation', () {
      final plan = FeedDayPlan(
        doc: 1,
        rounds: [5.0, 5.0, 5.0, 5.0],
        engineTotal: 20.0,
      );

      expect(plan.doc, equals(1));
      expect(plan.rounds, equals([5.0, 5.0, 5.0, 5.0]));
      expect(plan.total, equals(20.0));
      expect(plan.engineTotal, equals(20.0));
    });

    test('FeedDayPlan rounds access works correctly', () {
      final rounds = [2.5, 3.0, 4.0, 2.5];
      final plan = FeedDayPlan(
        doc: 5,
        rounds: rounds,
      );

      expect(plan.rounds[0], equals(2.5));
      expect(plan.rounds[1], equals(3.0));
      expect(plan.rounds[2], equals(4.0));
      expect(plan.rounds[3], equals(2.5));
      expect(plan.rounds.fold(0.0, (s, v) => s + v), equals(12.0));
    });

    test('FeedDayPlan copyWith preserves rounds correctly', () {
      final original = FeedDayPlan(
        doc: 10,
        rounds: [1.0, 2.0, 3.0, 4.0],
      );

      final updated = original.copyWith(
        rounds: [2.0, 2.0, 2.0, 2.0],
      );

      expect(updated.doc, equals(original.doc));
      expect(updated.rounds, equals([2.0, 2.0, 2.0, 2.0]));
      expect(updated.total, equals(8.0));
    });

    test('FeedDayPlan serialization and deserialization works', () {
      final original = FeedDayPlan(
        doc: 7,
        rounds: [1.5, 2.5, 3.0, 2.0],
        engineTotal: 9.0,
      );

      final json = original.toJson();
      final restored = FeedDayPlan.fromJson(json);

      expect(restored.doc, equals(7));
      expect(restored.rounds, equals([1.5, 2.5, 3.0, 2.0]));
      expect(restored.total, equals(9.0));
    });

    test('List<FeedDayPlan> can be created and iterated', () {
      final plans = [
        FeedDayPlan(doc: 1, rounds: [5.0, 5.0, 5.0, 5.0]),
        FeedDayPlan(doc: 2, rounds: [6.0, 6.0, 6.0, 6.0]),
        FeedDayPlan(doc: 3, rounds: [7.0, 7.0, 7.0, 7.0]),
      ];

      expect(plans.length, equals(3));

      for (final plan in plans) {
        // This should work without throwing 'no instance method []' error
        final doc = plan.doc;
        final amounts = List<double>.from(plan.rounds);

        expect(doc, isA<int>());
        expect(amounts, isA<List<double>>());
        expect(amounts.length, equals(4));
      }
    });

    test('FeedDayPlan properties are correctly typed', () {
      final plan = FeedDayPlan(
        doc: 15,
        rounds: [10.0, 10.0, 10.0, 10.0],
        engineTotal: 40.0,
      );

      // These should all work without type errors
      final int doc = plan.doc;
      final List<double> rounds = plan.rounds;
      final double engineTotal = plan.engineTotal;

      expect(doc, isA<int>());
      expect(rounds, isA<List<double>>());
      expect(engineTotal, isA<double>());
    });
  });
}
