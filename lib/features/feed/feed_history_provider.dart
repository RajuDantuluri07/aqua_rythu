import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/tray_status.dart';

class FeedHistoryLog {
  final DateTime date;
  final int doc;
  final List<double> rounds; // Use a list for flexibility
  final List<TrayStatus?> trayStatuses;
  final double expected;
  final double cumulative;

  FeedHistoryLog({
    required this.date,
    required this.doc,
    required this.rounds,
    required this.trayStatuses,
    required this.expected,
    required this.cumulative,
  });

  double get total => rounds.fold(0.0, (sum, item) => sum + item);
  double get delta => total - expected;

  // Logic: if delta < -1 => Warning
  bool get isWarning => delta < -1;
}

class FeedHistoryNotifier
    extends StateNotifier<Map<String, List<FeedHistoryLog>>> {
  FeedHistoryNotifier() : super({}) {
    _loadInitialMockData();
  }

  void _loadInitialMockData() {
    // Generate some history for 'Pond 1'
    final now = DateTime.now();
    final List<FeedHistoryLog> logs = [];
    double runningCum = 0;

    for (int i = 0; i < 31; i++) {
      final doc = i + 1;
      final date = now.subtract(Duration(days: 31 - i + 1)); // Past days

      final double baseFeed = doc * 0.5 + 5;
      final mockRounds = [
        baseFeed * 0.25,
        baseFeed * 0.25,
        baseFeed * 0.25,
        baseFeed * 0.25
      ];

      final total = mockRounds.reduce((a, b) => a + b);
      runningCum += total;

      logs.add(FeedHistoryLog(
        date: date,
        doc: doc,
        rounds: mockRounds,
        trayStatuses: List.filled(4, null),
        expected: total,
        cumulative: runningCum,
      ));
    }

    // Add Today as an empty placeholder or partially filled if needed
    // But better to add it on the fly from Dashboard

    state = {
      'Pond 1': logs.reversed.toList(),
    };
  }

  /// 🍽 LOG REAL-TIME FEEDING
  void logFeeding({
    required String pondId,
    required int doc,
    required int round,
    required double qty,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pondLogs = List<FeedHistoryLog>.from(state[pondId] ?? []);

    // Check if today already exists
    int todayIdx = pondLogs.indexWhere((log) =>
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day);

    if (todayIdx != -1) {
      final existing = pondLogs[todayIdx];
      final newRounds = List<double>.from(existing.rounds);
      final newTrays = List<TrayStatus?>.from(existing.trayStatuses);

      // Expand rounds if needed (e.g. if rounds was [0,0,0,0])
      if (newRounds.length < round) {
        final diff = round - newRounds.length;
        newRounds.addAll(List.filled(diff, 0.0));
        newTrays.addAll(List.filled(diff, null));
      }
      newRounds[round - 1] = qty;

      // Recalculate Cumulative
      double prevCum = 0.0;
      if (todayIdx + 1 < pondLogs.length) {
        prevCum = pondLogs[todayIdx + 1].cumulative;
      }
      final newTotal = newRounds.fold(0.0, (sum, val) => sum + val);

      pondLogs[todayIdx] = FeedHistoryLog(
        date: existing.date,
        doc: doc,
        rounds: newRounds,
        trayStatuses: newTrays,
        expected: existing.expected,
        cumulative: prevCum + newTotal,
      );
    } else {
      // Create new today log
      final newRounds = List.filled(4, 0.0);
      newRounds[round - 1] = qty;
      final newTrays = List<TrayStatus?>.filled(4, null);

      final prevCum = pondLogs.isNotEmpty ? pondLogs.first.cumulative : 0.0;

      pondLogs.insert(
          0,
          FeedHistoryLog(
            date: today,
            doc: doc,
            rounds: newRounds,
            trayStatuses: newTrays,
            expected: 10.0, // Mock expected
            cumulative: prevCum + qty,
          ));
    }

    state = {
      ...state,
      pondId: pondLogs,
    };
  }

  /// 📥 LOG TRAY STATUS
  void logTray({
    required String pondId,
    required int doc,
    required int round,
    required TrayStatus status,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pondLogs = List<FeedHistoryLog>.from(state[pondId] ?? []);

    final todayIdx = pondLogs.indexWhere((log) =>
        log.date.year == today.year &&
        log.date.month == today.month &&
        log.date.day == today.day);

    if (todayIdx != -1) {
      final existing = pondLogs[todayIdx];
      final newTrays = List<TrayStatus?>.from(existing.trayStatuses);

      // Ensure capacity if rounds are expanding dynamically
      if (newTrays.length < round) {
        newTrays.addAll(List.filled(round - newTrays.length, null));
      }

      newTrays[round - 1] = status;

      pondLogs[todayIdx] = FeedHistoryLog(
        date: existing.date,
        doc: existing.doc,
        rounds: existing.rounds,
        trayStatuses: newTrays,
        expected: existing.expected,
        cumulative: existing.cumulative,
      );

      state = {
        ...state,
        pondId: pondLogs,
      };
    }
  }

  /// 🗑 CLEAR HISTORY FOR NEW CYCLE
  void clearHistory(String pondId) {
    final newState = Map<String, List<FeedHistoryLog>>.from(state);
    newState.remove(pondId);
    state = newState;
  }
}

final feedHistoryProvider = StateNotifierProvider<FeedHistoryNotifier,
    Map<String, List<FeedHistoryLog>>>((ref) {
  return FeedHistoryNotifier();
});
