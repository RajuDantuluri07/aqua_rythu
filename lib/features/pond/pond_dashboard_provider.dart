import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';

/// Holds the ephemeral state of the Dashboard UI (Active Pond, Daily Inputs)
class PondDashboardState {
  final String selectedPond;
  final int doc;
  final double currentFeed;
  final Map<int, bool> feedDone;
  final Map<int, String> trayResults;

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
    Map<int, String>? trayResults,
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

class PondDashboardNotifier extends StateNotifier<PondDashboardState> {
  final Ref ref;
  PondDashboardNotifier(this.ref)
      : super(PondDashboardState(
          selectedPond: "Pond 1",
          doc: 1, // Default, will be updated immediately
          currentFeed: 15.0,
          feedDone: {},
          trayResults: {},
        )) {
    // Initialize with the correct DOC for the default pond
    _updateStateForPond(state.selectedPond);
  }

  void _updateStateForPond(String pondId) {
    final doc = ref.read(docProvider(pondId));
    state = state.copyWith(
      doc: doc,
      // Reset daily progress when switching ponds
      feedDone: {},
      trayResults: {},
    );
  }

  void selectPond(String pondId) {
    state = state.copyWith(selectedPond: pondId);
    _updateStateForPond(pondId);
  }

  void markFeedDone(int round) {
    final newMap = Map<int, bool>.from(state.feedDone);
    newMap[round] = true;
    state = state.copyWith(feedDone: newMap);
  }

  void logTray(int round, String result) {
    final newMap = Map<int, String>.from(state.trayResults);
    newMap[round] = result;

    // Apply Tray Logic
    double newFeed = state.currentFeed;
    if (result == "empty") newFeed *= 1.10; // +10%
    if (result == "half") newFeed *= 0.90;  // -10%
    if (result == "full") newFeed *= 0.80;  // -20%

    state = state.copyWith(
      trayResults: newMap,
      currentFeed: newFeed,
    );
  }
}

final pondDashboardProvider =
    StateNotifierProvider<PondDashboardNotifier, PondDashboardState>((ref) {
  return PondDashboardNotifier(ref);
});