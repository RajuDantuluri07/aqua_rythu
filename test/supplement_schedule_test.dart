import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/models/supplement_schedule.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SupplementSchedule _makeSchedule({
  required DateTime startDate,
  int? frequencyDays,
  DateTime? stopDate,
  bool isPaused = false,
}) {
  final endDate = frequencyDays != null && frequencyDays > 0
      ? DateTime(2099, 12, 31)
      : startDate;
  return SupplementSchedule(
    id: 'test-id',
    pondId: 'pond-1',
    applicationType: 'water_mix',
    startDate: startDate,
    endDate: endDate,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    frequencyDays: frequencyDays,
    stopDate: stopDate,
    isPaused: isPaused,
  );
}

DateTime d(int year, int month, int day) => DateTime(year, month, day);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── recurrenceLabel (T5) ──────────────────────────────────────────────────

  group('recurrenceLabel', () {
    test('one-time returns Only This Time', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1));
      expect(s.recurrenceLabel(), 'Only This Time');
    });

    test('7-day returns Every 7 Days', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 7);
      expect(s.recurrenceLabel(), 'Every 7 Days');
    });

    test('10-day returns Every 10 Days', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 10);
      expect(s.recurrenceLabel(), 'Every 10 Days');
    });

    test('15-day returns Every 15 Days', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 15);
      expect(s.recurrenceLabel(), 'Every 15 Days');
    });

    test('30-day returns Every 30 Days', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 30);
      expect(s.recurrenceLabel(), 'Every 30 Days');
    });
  });

  // ── isActiveOnDate — one-time (T7) ────────────────────────────────────────

  group('isActiveOnDate — one-time', () {
    final s = _makeSchedule(startDate: d(2026, 5, 10));

    test('active on exact start date', () {
      expect(s.isActiveOnDate(d(2026, 5, 10)), isTrue);
    });

    test('not active before start date', () {
      expect(s.isActiveOnDate(d(2026, 5, 9)), isFalse);
    });

    test('not active after start date', () {
      expect(s.isActiveOnDate(d(2026, 5, 11)), isFalse);
    });
  });

  // ── isActiveOnDate — recurring (T7) ──────────────────────────────────────

  group('isActiveOnDate — every 7 days', () {
    final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 7);

    test('active on start date (day 0)', () {
      expect(s.isActiveOnDate(d(2026, 5, 1)), isTrue);
    });

    test('active on day 7', () {
      expect(s.isActiveOnDate(d(2026, 5, 8)), isTrue);
    });

    test('active on day 14', () {
      expect(s.isActiveOnDate(d(2026, 5, 15)), isTrue);
    });

    test('not active on day 3', () {
      expect(s.isActiveOnDate(d(2026, 5, 4)), isFalse);
    });

    test('not active before start date', () {
      expect(s.isActiveOnDate(d(2026, 4, 30)), isFalse);
    });
  });

  group('isActiveOnDate — every 10 days', () {
    final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 10);

    test('active on day 0', () => expect(s.isActiveOnDate(d(2026, 5, 1)), isTrue));
    test('active on day 10', () => expect(s.isActiveOnDate(d(2026, 5, 11)), isTrue));
    test('active on day 20', () => expect(s.isActiveOnDate(d(2026, 5, 21)), isTrue));
    test('not active on day 5', () => expect(s.isActiveOnDate(d(2026, 5, 6)), isFalse));
  });

  group('isActiveOnDate — every 15 days', () {
    final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 15);

    test('active on day 0', () => expect(s.isActiveOnDate(d(2026, 5, 1)), isTrue));
    test('active on day 15', () => expect(s.isActiveOnDate(d(2026, 5, 16)), isTrue));
    test('not active on day 7', () => expect(s.isActiveOnDate(d(2026, 5, 8)), isFalse));
  });

  group('isActiveOnDate — every 30 days', () {
    final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 30);

    test('active on day 0', () => expect(s.isActiveOnDate(d(2026, 5, 1)), isTrue));
    test('active on day 30', () => expect(s.isActiveOnDate(d(2026, 5, 31)), isTrue));
    test('not active on day 15', () => expect(s.isActiveOnDate(d(2026, 5, 16)), isFalse));
  });

  // ── Paused / stopped edge cases (T7) ─────────────────────────────────────

  group('isActiveOnDate — lifecycle', () {
    test('paused schedule is never active', () {
      final s = _makeSchedule(
        startDate: d(2026, 5, 1),
        frequencyDays: 7,
        isPaused: true,
      );
      expect(s.isActiveOnDate(d(2026, 5, 1)), isFalse);
      expect(s.isActiveOnDate(d(2026, 5, 8)), isFalse);
    });

    test('stopped schedule not active after stop date', () {
      // Cadence: May 1, May 8, May 15, May 22 …
      // Stop date May 15 is inclusive — the cadence hit on that day still fires.
      final s = _makeSchedule(
        startDate: d(2026, 5, 1),
        frequencyDays: 7,
        stopDate: d(2026, 5, 15),
      );
      expect(s.isActiveOnDate(d(2026, 5, 1)), isTrue);   // day 0 — active
      expect(s.isActiveOnDate(d(2026, 5, 8)), isTrue);   // day 7 — active
      expect(s.isActiveOnDate(d(2026, 5, 15)), isTrue);  // day 14 — on stop date, still fires
      expect(s.isActiveOnDate(d(2026, 5, 22)), isFalse); // day 21 — past stop date
    });
  });

  // ── getNextOccurrence (T1) ────────────────────────────────────────────────

  group('getNextOccurrence — one-time', () {
    final s = _makeSchedule(startDate: d(2026, 5, 10));

    test('returns startDate when afterDate is before start', () {
      expect(s.getNextOccurrence(d(2026, 5, 5)), d(2026, 5, 10));
    });

    test('returns startDate when afterDate equals start', () {
      expect(s.getNextOccurrence(d(2026, 5, 10)), d(2026, 5, 10));
    });

    test('returns null when afterDate is after start', () {
      expect(s.getNextOccurrence(d(2026, 5, 11)), isNull);
    });
  });

  group('getNextOccurrence — every 7 days', () {
    final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 7);

    test('returns start when asked from start', () {
      expect(s.getNextOccurrence(d(2026, 5, 1)), d(2026, 5, 1));
    });

    test('returns start when asked before start', () {
      expect(s.getNextOccurrence(d(2026, 4, 28)), d(2026, 5, 1));
    });

    test('returns day 7 when asked from day 2', () {
      expect(s.getNextOccurrence(d(2026, 5, 3)), d(2026, 5, 8));
    });

    test('returns day 14 when asked from day 9', () {
      expect(s.getNextOccurrence(d(2026, 5, 9)), d(2026, 5, 15));
    });

    test('returns exact day when asked on occurrence date', () {
      expect(s.getNextOccurrence(d(2026, 5, 8)), d(2026, 5, 8));
    });
  });

  group('getNextOccurrence — stopped', () {
    test('returns null when next occurrence is beyond stop date', () {
      final s = _makeSchedule(
        startDate: d(2026, 5, 1),
        frequencyDays: 7,
        stopDate: d(2026, 5, 12),
      );
      expect(s.getNextOccurrence(d(2026, 5, 9)), isNull);
    });

    test('returns occurrence when within stop date', () {
      final s = _makeSchedule(
        startDate: d(2026, 5, 1),
        frequencyDays: 7,
        stopDate: d(2026, 5, 12),
      );
      expect(s.getNextOccurrence(d(2026, 5, 7)), d(2026, 5, 8));
    });

    test('paused returns null', () {
      final s = _makeSchedule(
        startDate: d(2026, 5, 1),
        frequencyDays: 7,
        isPaused: true,
      );
      expect(s.getNextOccurrence(d(2026, 5, 1)), isNull);
    });
  });

  // ── getUpcomingOccurrences (T1) ───────────────────────────────────────────

  group('getUpcomingOccurrences', () {
    test('one-time returns single occurrence from start', () {
      final s = _makeSchedule(startDate: d(2026, 5, 10));
      final occ = s.getUpcomingOccurrences(fromDate: d(2026, 5, 1));
      expect(occ, [d(2026, 5, 10)]);
    });

    test('one-time returns empty after start date', () {
      final s = _makeSchedule(startDate: d(2026, 5, 10));
      final occ = s.getUpcomingOccurrences(fromDate: d(2026, 5, 11));
      expect(occ, isEmpty);
    });

    test('7-day returns 3 occurrences', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 7);
      final occ = s.getUpcomingOccurrences(fromDate: d(2026, 5, 1));
      expect(occ, [d(2026, 5, 1), d(2026, 5, 8), d(2026, 5, 15)]);
    });

    test('10-day respects limit=2', () {
      final s = _makeSchedule(startDate: d(2026, 5, 1), frequencyDays: 10);
      final occ = s.getUpcomingOccurrences(fromDate: d(2026, 5, 1), limit: 2);
      expect(occ, [d(2026, 5, 1), d(2026, 5, 11)]);
    });

    test('stops at stop date boundary', () {
      final s = _makeSchedule(
        startDate: d(2026, 5, 1),
        frequencyDays: 7,
        stopDate: d(2026, 5, 15),
      );
      final occ = s.getUpcomingOccurrences(fromDate: d(2026, 5, 1));
      expect(occ, [d(2026, 5, 1), d(2026, 5, 8), d(2026, 5, 15)]);
    });
  });

  // ── Leap year edge case (T7) ──────────────────────────────────────────────

  group('leap year', () {
    test('7-day schedule crosses Feb 29 in leap year 2028', () {
      final s = _makeSchedule(startDate: d(2028, 2, 22), frequencyDays: 7);
      expect(s.getNextOccurrence(d(2028, 2, 23)), d(2028, 2, 29));
      expect(s.isActiveOnDate(d(2028, 2, 29)), isTrue);
    });
  });
}
