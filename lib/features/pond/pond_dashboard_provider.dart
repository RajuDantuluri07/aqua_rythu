import '../../core/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed_state_engine.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_plan_provider.dart';
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
    Map<int, bool>? feedDone,
    Map<int, TrayStatus>? trayResults,
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

  void _updateStateForPond(String pondId) {
    final doc = ref.read(docProvider(pondId));

    state = state.copyWith(
      doc: doc,
      feedDone: {},
      currentFeed: 15.0, // Default baseline, UI overrides this per round
      trayResults: <int, TrayStatus>{},
    );
  }

  void selectPond(String pondId) {
    state = state.copyWith(selectedPond: pondId);
    _updateStateForPond(pondId);
  }

  // =========================================================
  // 🍽 FEED MARKING
  // =========================================================

  void markFeedDone(int round) {
    final newMap = Map<int, bool>.from(state.feedDone);
    newMap[round] = true;

    state = state.copyWith(feedDone: newMap);

    // 🔧 DEBUG LOGS
    print("✅ Round $round Marked Done");
    print("DOC: ${state.doc} | Feed Status: $newMap");
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

    /// ✅ Save first tray result to the dashboard state for immediate UI feedback.
    final newMap = Map<int, TrayStatus>.from(state.trayResults);
    newMap[round] = trayStatuses.first;

    state = state.copyWith(
      trayResults: newMap,
    );
    print("✅ Tray Logged for Round $round: ${newMap[round]}");

    // =========================================================
    // 🧠 AUTO-ADJUST NEXT ROUND
    // =========================================================
    final nextRound = round + 1;
    if (nextRound <= 4) { // Only adjust if there is a next round today
      final plans = ref.read(feedPlanProvider);
      final pondPlan = plans[state.selectedPond];
      
      // Safely get today's plan
      final dayPlan = pondPlan?.days.firstWhere(
        (d) => d.doc == state.doc,
        orElse: () => FeedDayPlan(doc: 0, r1: 0, r2: 0, r3: 0, r4: 0),
      );
      
      if (dayPlan != null && dayPlan.doc != 0) {
        // Get base quantity for the next round
        double plannedQtyForNextRound = 0;
        if (nextRound == 1) plannedQtyForNextRound = dayPlan.r1;
        if (nextRound == 2) plannedQtyForNextRound = dayPlan.r2;
        if (nextRound == 3) plannedQtyForNextRound = dayPlan.r3;
        if (nextRound == 4) plannedQtyForNextRound = dayPlan.r4;

        // Calculate new adjusted quantity
        final adjustedQty = FeedStateEngine.applyTrayAdjustment(
          plannedQty: plannedQtyForNextRound,
          trayResults: trayStatuses,
        );

        // Update the Feed Plan Provider, which will trigger UI rebuilds
        ref.read(feedPlanProvider.notifier).updateFeed(
          pondId: state.selectedPond,
          doc: state.doc,
          r1: nextRound == 1 ? adjustedQty : null,
          r2: nextRound == 2 ? adjustedQty : null,
          r3: nextRound == 3 ? adjustedQty : null,
          r4: nextRound == 4 ? adjustedQty : null,
        );

        print("⚖️ Auto-Adjusted Round $nextRound: $plannedQtyForNextRound kg -> ${adjustedQty.toStringAsFixed(2)} kg");
      }
    }
  }
}

/// =======================
/// PROVIDER
/// =======================

final pondDashboardProvider =
    StateNotifierProvider<PondDashboardNotifier, PondDashboardState>((ref) {
  return PondDashboardNotifier(ref);
});