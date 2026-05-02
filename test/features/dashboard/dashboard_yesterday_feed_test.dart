import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/features/feed/feed_history_provider.dart';

void main() {
  group('Dashboard Yesterday Feed Logic Test', () {
    test('Extracting yesterday feed from history map', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));

      final pondId = 'pond-1';
      final historyMap = {
        pondId: [
          FeedHistoryLog(
            date: today,
            doc: 10,
            rounds: [10.0, 10.0],
            trayStatuses: [],
            expected: 20.0,
            cumulative: 100.0,
          ),
          FeedHistoryLog(
            date: yesterday,
            doc: 9,
            rounds: [15.0, 15.0],
            trayStatuses: [],
            expected: 30.0,
            cumulative: 80.0,
          ),
        ],
      };

      // Simulating logic in DashboardScreen
      final pondHistory = historyMap[pondId] ?? [];
      final yesterdayLog = pondHistory.where((log) =>
        log.date.year == yesterday.year &&
        log.date.month == yesterday.month &&
        log.date.day == yesterday.day
      ).firstOrNull;
      final double yesterdayFeed = yesterdayLog?.total ?? 0.0;

      expect(yesterdayFeed, 30.0);
    });

    test('Yesterday feed missing from history map', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1));

      final pondId = 'pond-1';
      final historyMap = {
        pondId: [
          FeedHistoryLog(
            date: today,
            doc: 10,
            rounds: [10.0, 10.0],
            trayStatuses: [],
            expected: 20.0,
            cumulative: 100.0,
          ),
        ],
      };

      // Simulating logic in DashboardScreen
      final pondHistory = historyMap[pondId] ?? [];
      final yesterdayLog = pondHistory.where((log) =>
        log.date.year == yesterday.year &&
        log.date.month == yesterday.month &&
        log.date.day == yesterday.day
      ).firstOrNull;
      final double yesterdayFeed = yesterdayLog?.total ?? 0.0;

      expect(yesterdayFeed, 0.0);
    });
  });
}
