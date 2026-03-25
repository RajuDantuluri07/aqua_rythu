import '../../core/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed_state_engine.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';


/// =======================
/// STATE
/// =======================

class PondDashboardState {
  final String selectedPond;
  final int doc;
  final double currentFeed;
  final Map<int, bool> feedDone;
  final Map<int, TrayStatus> trayResults;
  PondDashboardState({
    required this.selectedPond,
    required this.doc,
    required this.currentFeed,
    required this.feedDone,
    required this.trayResults,
  });

  PondDashboardState copyWith({
    String? selectedPond,
    int? doc,
    double? currentFeed,
    final Map<int, bool>? feedDone,
    final Map<int, TrayStatus>? trayResults,
  }) {
    return PondDashboardState(
      selectedPond: selectedPond ?? this.selectedPond,
      doc: doc ?? this.doc,
      currentFeed: currentFeed ?? this.currentFeed,
      feedDone: feedDone ?? this.feedDone,
      trayResults: trayResults ?? this.trayResults,
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
    };
  }

  void _updateStateForPond(String pondId) {
    final doc = ref.read(docProvider(pondId));
    final cached = _pondCache[pondId];

    state = state.copyWith(
      doc: doc,
      feedDone: cached != null
          ? Map<int, bool>.from(cached['feedDone'])
          : {},
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

  // =========================================================
  // 🍽 FEED MARKING
  // =========================================================

  void markFeedDone(int round) {
    // 🔒 SAFETY: Prevent duplicate actions
    if (state.feedDone[round] == true) return;

    final newMap = Map<int, bool>.from(state.feedDone);
    newMap[round] = true;

    state = state.copyWith(feedDone: newMap);

    // 🕒 Persistence to History Ledger
    final planMap = ref.read(feedPlanProvider);
    final plan = planMap[state.selectedPond];
    if (plan != null) {
      final dayPlan = plan.days.firstWhere((d) => d.doc == state.doc, 
        orElse: () => FeedDayPlan(doc: state.doc, rounds: [1.0, 1.0, 1.0, 1.0]));
      
      // Access round index (0-based)
      final roundIdx = round - 1;
      double qty = (dayPlan.rounds.length > roundIdx) ? dayPlan.rounds[roundIdx] : 0.0;

      // Apply adjustment if round > 1
      if (round > 1) {
         final prevTray = state.trayResults[round - 1];
         if (prevTray != null) {
            // ✅ VERIFIED: Passing single aggregated tray as list to satisfy engine signature
            final mode = FeedStateEngine.getMode(state.doc);
            qty = FeedStateEngine.applyTrayAdjustment(
              [prevTray],
              qty,
              mode
            );
         }
      }

      ref.read(feedHistoryProvider.notifier).logFeeding(
        pondId: state.selectedPond, 
        doc: state.doc, 
        round: round, 
        qty: qty
      );
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