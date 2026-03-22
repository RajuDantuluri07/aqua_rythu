import '../../core/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
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

    /// ✅ Convert tray values → status (Map generic enum/string to TrayStatus)
    final trayStatuses = latest.trays.map((fill) {
      final val = fill.toString().toLowerCase();
      if (val.contains('empty') || val == '0') return TrayStatus.empty;
      if (val.contains('mostly') || val == '1') return TrayStatus.mostlyEaten;
      if (val.contains('half') || val == '2') return TrayStatus.halfEaten;
      return TrayStatus.untouched;
    }).toList();

    if (trayStatuses.isEmpty) return;

    /// ✅ Save first tray result
    final newMap = Map<int, TrayStatus>.from(state.trayResults);
    newMap[round] = trayStatuses.first;

    state = state.copyWith(
      trayResults: newMap,
    );

    // 🔧 DEBUG LOGS
    print("✅ Tray Logged for Round $round: ${newMap[round]}");
    print("Tray Results: $newMap");
  }
}

/// =======================
/// PROVIDER
/// =======================

final pondDashboardProvider =
    StateNotifierProvider<PondDashboardNotifier, PondDashboardState>((ref) {
  return PondDashboardNotifier(ref);
});