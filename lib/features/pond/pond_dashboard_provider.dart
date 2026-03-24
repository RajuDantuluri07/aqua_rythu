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
  final Map<String, String> waterTreatmentLogs; // supplementId_doc -> 'applied' | 'skipped'

  PondDashboardState({
    required this.selectedPond,
    required this.doc,
    required this.currentFeed,
    required this.feedDone,
    required this.trayResults,
    required this.waterTreatmentLogs,
  });

  PondDashboardState copyWith({
    String? selectedPond,
    int? doc,
    double? currentFeed,
    Map<int, bool>? feedDone,
    Map<int, TrayStatus>? trayResults,
    Map<String, String>? waterTreatmentLogs,
  }) {
    return PondDashboardState(
      selectedPond: selectedPond ?? this.selectedPond,
      doc: doc ?? this.doc,
      currentFeed: currentFeed ?? this.currentFeed,
      feedDone: feedDone ?? this.feedDone,
      trayResults: trayResults ?? this.trayResults,
      waterTreatmentLogs: waterTreatmentLogs ?? this.waterTreatmentLogs,
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
          waterTreatmentLogs: {},
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
      waterTreatmentLogs: {},
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
    // 🔒 SAFETY: Prevent duplicate actions
    if (state.feedDone[round] == true) return;

    final newMap = Map<int, bool>.from(state.feedDone);
    newMap[round] = true;

    state = state.copyWith(feedDone: newMap);
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
  }

  // =========================================================
  // 💧 WATER TREATMENT LOGIC
  // =========================================================

  void markWaterTreatmentApplied(String supplementId, int scheduledDoc) {
    final key = "${supplementId}_$scheduledDoc";
    if (state.waterTreatmentLogs[key] == 'applied') return;

    final newLogs = Map<String, String>.from(state.waterTreatmentLogs);
    newLogs[key] = 'applied';

    state = state.copyWith(waterTreatmentLogs: newLogs);
  }

  void markWaterTreatmentSkipped(String supplementId, int scheduledDoc) {
    final key = "${supplementId}_$scheduledDoc";
    if (state.waterTreatmentLogs[key] == 'skipped') return;

    final newLogs = Map<String, String>.from(state.waterTreatmentLogs);
    newLogs[key] = 'skipped';

    state = state.copyWith(waterTreatmentLogs: newLogs);
  }
}


/// =======================
/// PROVIDER
/// =======================

final pondDashboardProvider =
    StateNotifierProvider<PondDashboardNotifier, PondDashboardState>((ref) {
  return PondDashboardNotifier(ref);
});