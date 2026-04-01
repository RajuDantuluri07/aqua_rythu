import '../../core/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed_state_engine.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';
import '../../services/pond_service.dart';
import '../../services/feed_service.dart';

/// =======================
/// STATE
/// =======================

class PondDashboardState {
  final String selectedPond;
  final int doc;
  final double currentFeed;
  final Map<int, bool> feedDone;
  final Map<int, TrayStatus> trayResults;
  final Map<int, String> roundToFeedId;
  final Map<int, double> roundFeedAmounts;
  PondDashboardState({
    required this.selectedPond,
    required this.doc,
    required this.currentFeed,
    required this.feedDone,
    required this.trayResults,
    this.roundToFeedId = const {},
    this.roundFeedAmounts = const {},
  });

  PondDashboardState copyWith({
    String? selectedPond,
    int? doc,
    double? currentFeed,
    final Map<int, bool>? feedDone,
    final Map<int, TrayStatus>? trayResults,
    Map<int, String>? roundToFeedId,
    Map<int, double>? roundFeedAmounts,
  }) {
    return PondDashboardState(
      selectedPond: selectedPond ?? this.selectedPond,
      doc: doc ?? this.doc,
      currentFeed: currentFeed ?? this.currentFeed,
      feedDone: feedDone ?? this.feedDone,
      trayResults: trayResults ?? this.trayResults,
      roundToFeedId: roundToFeedId ?? this.roundToFeedId,
      roundFeedAmounts: roundFeedAmounts ?? this.roundFeedAmounts,
    );
  }
}

/// =======================
/// NOTIFIER
/// =======================

class PondDashboardNotifier extends StateNotifier<PondDashboardState> {
  final Ref ref;

  /// Per-pond cache to preserve state across pond switches
  final Map<String, Map<String, dynamic>> _pondCache = {};

  PondDashboardNotifier(this.ref)
      : super(PondDashboardState(
          selectedPond: "Pond 1",
          doc: 1,
          currentFeed: 15.0,
          feedDone: {},
          trayResults: <int, TrayStatus>{},
          roundToFeedId: {},
          roundFeedAmounts: {},
        )) {
    _updateStateForPond(state.selectedPond);
  }

  // =========================================================
  // 🔁 POND SWITCH
  // =========================================================

  void _saveCurrentPondState() {
    _pondCache[state.selectedPond] = {
      'feedDone': Map<int, bool>.from(state.feedDone),
      'trayResults': Map<int, TrayStatus>.from(state.trayResults),
      'roundToFeedId': Map<int, String>.from(state.roundToFeedId),
      'roundFeedAmounts': Map<int, double>.from(state.roundFeedAmounts),
    };
  }

  Future<void> loadTodayFeed(String pondId) async {
    final farmState = ref.read(farmProvider);
    final pond = farmState.currentFarm?.ponds.firstWhere((p) => p.id == pondId);
    
    if (pond == null) return;

    final data = await PondService().getTodayFeed(
      pondId: pondId,
      stockingDate: pond.stockingDate.toIso8601String(),
    );

    Map<int, double> feedMap = {};
    Map<int, String> idMap = {};
    Map<int, bool> doneMap = {};

    for (var item in data) {
      final round = item['round'] as int;
      feedMap[round] = (item['feed_amount'] as num).toDouble();
      idMap[round] = item['id'].toString();
      doneMap[round] = item['is_completed'] ?? false;
    }

    state = state.copyWith(
      roundFeedAmounts: feedMap,
      roundToFeedId: idMap,
      feedDone: doneMap,
    );
  }

  Future<void> _updateStateForPond(String pondId) async {
    final doc = ref.read(docProvider(pondId));
    final cached = _pondCache[pondId];

    await loadTodayFeed(pondId);

    state = state.copyWith(
      doc: doc,
      currentFeed: 15.0,
      trayResults: cached != null
          ? Map<int, TrayStatus>.from(cached['trayResults'])
          : <int, TrayStatus>{},
    );
  }

  void selectPond(String pondId) {
    _saveCurrentPondState();
    state = state.copyWith(selectedPond: pondId);
    _updateStateForPond(pondId);
  }

  void resetPondState(String pondId) {
    _pondCache.remove(pondId);
    if (state.selectedPond == pondId) {
      _updateStateForPond(pondId);
    }
  }

  // =========================================================
  // 🍽 FEED MARKING
  // =========================================================

  Future<void> markFeedDone(int round) async {
    if (state.feedDone[round] == true) return;

    final feedId = state.roundToFeedId[round];
    if (feedId == null) return;

    await FeedService().markFeedPlanCompleted(
      feedPlanId: feedId,
    );

    final newMap = Map<int, bool>.from(state.feedDone);
    newMap[round] = true;

    state = state.copyWith(feedDone: newMap);

    // Optional: Keep history logging using the actual DB amount
    final qty = state.roundFeedAmounts[round] ?? 0.0;
    if (qty > 0) {
      ref.read(feedHistoryProvider.notifier).logFeeding(
          pondId: state.selectedPond, doc: state.doc, round: round, qty: qty);
    }
  }

  // =========================================================
  // 🧠 TRAY LOGIC (FIXED)
  // =========================================================

  void logTray(int round) {
    final trayLogs = ref.read(trayProvider(state.selectedPond));
    if (trayLogs.isEmpty) return;

    final latest = trayLogs.last;

    // The tray log now directly provides a list of TrayStatus enums.
    final List<TrayStatus> trayStatuses = latest.trays;
    if (trayStatuses.isEmpty) return;

    final finalStatus = FeedStateEngine.aggregateTrayStatus(trayStatuses);

    ref.read(feedHistoryProvider.notifier).logTray(
          pondId: state.selectedPond,
          doc: state.doc,
          round: round,
          status: finalStatus,
        );

    final newMap = Map<int, TrayStatus>.from(state.trayResults);
    newMap[round] = finalStatus;

    state = state.copyWith(
      trayResults: newMap,
    );
  }
}

/// =======================
/// PROVIDER
/// =======================

final pondDashboardProvider =
    StateNotifierProvider<PondDashboardNotifier, PondDashboardState>((ref) {
  return PondDashboardNotifier(ref);
});
