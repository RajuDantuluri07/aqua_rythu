import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/tray_status.dart';
import 'feed_plan_provider.dart';

class FeedHistoryLog {
  final DateTime date;
  final int doc;
  final List<double> rounds; // Actual feed logged
  final List<double>? smartFeedRecommendations; // Smart recommendations
  final List<TrayStatus?> trayStatuses;
  final double expected;
  final double cumulative;

  FeedHistoryLog({
    required this.date,
    required this.doc,
    required this.rounds,
    this.smartFeedRecommendations,
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
  FeedHistoryNotifier(this.ref) : super({});

  final Ref ref;

  double _expectedFeedForDoc(String pondId, int doc) {
    final plan = ref.read(feedPlanProvider)[pondId];
    if (plan == null) {
      return 0.0;
    }

    final dayPlan = plan.days.where((day) => day.doc == doc);
    if (dayPlan.isEmpty) {
      return 0.0;
    }

    return dayPlan.first.total;
  }

  /// 🍽 LOG REAL-TIME FEEDING
  void logFeeding({
    required String pondId,
    required int doc,
    required int round,
    required double qty,
    double? smartFeedQty,
  }) {
    if (qty <= 0) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expected = _expectedFeedForDoc(pondId, doc);

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
      final newSmartFeeds = existing.smartFeedRecommendations != null
          ? List<double>.from(existing.smartFeedRecommendations!)
          : List<double>.filled(4, 0.0);

      // Expand rounds if needed (e.g. if rounds was [0,0,0,0])
      if (newRounds.length < round) {
        final diff = round - newRounds.length;
        newRounds.addAll(List.filled(diff, 0.0));
        newTrays.addAll(List.filled(diff, null));
        newSmartFeeds.addAll(List.filled(diff, 0.0));
      }
      newRounds[round - 1] = qty;
      if (smartFeedQty != null) {
        newSmartFeeds[round - 1] = smartFeedQty;
      }

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
        smartFeedRecommendations: newSmartFeeds.any((v) => v > 0) ? newSmartFeeds : null,
        trayStatuses: newTrays,
        expected: expected,
        cumulative: prevCum + newTotal,
      );
    } else {
      // Create new today log
      final newRounds = List.filled(4, 0.0);
      newRounds[round - 1] = qty;
      final newTrays = List<TrayStatus?>.filled(4, null);
      final newSmartFeeds = List.filled(4, 0.0);
      if (smartFeedQty != null) {
        newSmartFeeds[round - 1] = smartFeedQty;
      }

      final prevCum = pondLogs.isNotEmpty ? pondLogs.first.cumulative : 0.0;

      pondLogs.insert(
          0,
          FeedHistoryLog(
            date: today,
            doc: doc,
            rounds: newRounds,
            smartFeedRecommendations: newSmartFeeds.any((v) => v > 0) ? newSmartFeeds : null,
            trayStatuses: newTrays,
            expected: expected,
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
      final newSmartFeeds = existing.smartFeedRecommendations != null
          ? List<double>.from(existing.smartFeedRecommendations!)
          : List<double>.filled(4, 0.0);

      // Ensure capacity if rounds are expanding dynamically
      if (newTrays.length < round) {
        newTrays.addAll(List.filled(round - newTrays.length, null));
        newSmartFeeds.addAll(List.filled(round - newSmartFeeds.length, 0.0));
      }

      newTrays[round - 1] = status;

      pondLogs[todayIdx] = FeedHistoryLog(
        date: existing.date,
        doc: existing.doc,
        rounds: existing.rounds,
        smartFeedRecommendations: newSmartFeeds.any((v) => v > 0) ? newSmartFeeds : null,
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
  return FeedHistoryNotifier(ref);
});
