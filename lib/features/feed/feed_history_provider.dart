import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/tray_status.dart';
import '../../services/feed_service.dart';
import '../../core/utils/logger.dart';
import '../pond/pond_dashboard_provider.dart';

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
  final _feedService = FeedService();

  /// 🔄 SMART FEED TRIGGER: Trigger recalculation after tray update
  void _triggerSmartFeedRecalculation(String pondId) {
    // Fire-and-forget Smart Feed recalculation
    _feedService.recalculateFeedPlan(pondId).catchError((e) {
      AppLogger.error('Feed recalculation trigger failed', e);
    });
  }

  double _expectedFeedForDoc(String pondId, int doc) {
    final dashboardState = ref.read(pondDashboardProvider);
    if (dashboardState.selectedPond == pondId) {
      return dashboardState.roundFeedAmounts.values.fold(0.0, (sum, val) => sum + val);
    }
    // Fix #5: returns 0 for non-selected ponds — callers should supply expectedFeed
    // directly to avoid this broken path.
    return 0.0;
  }

  /// 🍽 LOG REAL-TIME FEEDING
  ///
  /// [expectedFeed] — total planned feed for the day (all rounds combined).
  /// Fix #5: pass this from the caller so the expected value is correct for every
  /// pond, not just the currently selected one (which was the previous broken path).
  Future<void> logFeeding({
    required String pondId,
    required int doc,
    required int round,
    required double qty,
    double? smartFeedQty,
    double expectedFeed = 0.0,
  }) async {
    if (qty <= 0) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Fix #5: prefer caller-supplied expected; only fall back to state lookup
    // for the currently-selected pond (still correct for that case).
    final expected = expectedFeed > 0
        ? expectedFeed
        : _expectedFeedForDoc(pondId, doc);

    final List<FeedHistoryLog> pondLogs =
    List<FeedHistoryLog>.from(state[pondId] ?? <FeedHistoryLog>[]);

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

    // ✅ Update local state with strict type safety
    state = Map<String, List<FeedHistoryLog>>.from(state)
      ..[pondId] = pondLogs;
    
    // ✅ Persist to database before returning so callers can safely reload
    //    the dashboard and reconstruct lastFeedTime from persisted data.
    final logToSave = pondLogs[todayIdx != -1 ? todayIdx : 0];
    await _persistFeedLog(
      pondId: pondId,
      log: logToSave,
    );

    // 🔄 SMART FEED TRIGGER: Recalculate after feed logged
    _triggerSmartFeedRecalculation(pondId);
  }
  
  /// ✅ Persist feed log to database
  Future<void> _persistFeedLog({
    required String pondId,
    required FeedHistoryLog log,
  }) async {
    try {
      await _feedService.saveFeed(
        pondId: pondId,
        date: log.date,
        doc: log.doc,
        rounds: log.rounds,
        expectedFeed: log.expected,
        cumulativeFeed: log.cumulative,
      );
      AppLogger.info('Feed log saved: pond $pondId DOC ${log.doc}');
    } catch (e) {
      AppLogger.error('Failed to save feed log to DB', e);
      // Data is still in local state, can retry later
    }
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

    final List<FeedHistoryLog> pondLogs =
    List<FeedHistoryLog>.from(state[pondId] ?? <FeedHistoryLog>[]);

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

      state = Map<String, List<FeedHistoryLog>>.from(state)
        ..[pondId] = pondLogs;
      // Smart feed adjustment is triggered via TrayService after DB persistence
    }
  }

  /// 📦 LOAD HISTORY FROM SUPABASE ON STARTUP
  Future<void> loadHistoryForPonds(List<String> pondIds) async {
    if (pondIds.isEmpty) return;

    final newState = Map<String, List<FeedHistoryLog>>.from(state);

    for (final pondId in pondIds) {
      try {
        final rows = await _feedService.fetchFeedLogs(pondId);
        if (rows.isEmpty) continue;

        // Group rows by calendar date, keeping the last (most complete) row per day.
        // saveFeed inserts once per logFeeding call with the running total for that
        // day's rounds — so the last row for a given day is the most up-to-date.
        final Map<String, Map<String, dynamic>> latestByDate = {};
        for (final row in rows) {
          final dateKey = (row['created_at'] as String).substring(0, 10);
          latestByDate[dateKey] = row; // rows are ordered ascending — last wins
        }

        double cumulative = 0.0;
        final logs = <FeedHistoryLog>[];

        for (final entry in latestByDate.entries) {
          final feedGiven = (entry.value['feed_given'] as num?)?.toDouble() ?? 0.0;
          final doc = (entry.value['doc'] as int?) ?? 0;
          cumulative += feedGiven;
          logs.add(FeedHistoryLog(
            date: DateTime.parse(entry.key),
            doc: doc, 
            rounds: [feedGiven], // single value representing day total
            trayStatuses: [],
            expected: 0.0,
            cumulative: cumulative,
          ));
        }

        // Reverse so newest is first (matches logFeeding's insert-at-0 pattern)
        newState[pondId] = logs.reversed.toList();
      } catch (e) {
        AppLogger.error('Failed to load feed history for pond $pondId', e);
      }
    }

    state = newState;
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
