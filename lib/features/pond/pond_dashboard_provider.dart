import '../../services/pond_service.dart';
import '../../services/farm_service.dart';
import '../../features/supplements/screens/supplement_item.dart';
import '../../core/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';
import '../../services/pond_service.dart';
import '../../services/feed_service.dart';
import '../../services/feed_plan_generator.dart';

/// =======================
/// STATE
/// =======================

class PondDashboardState {
  final String selectedPond;
  final int doc;
  final double currentFeed;
  final Map<int, TrayStatus> trayResults;
  final Map<int, String> roundToFeedId;
  final Map<int, double> roundFeedAmounts;
  PondDashboardState({
    required this.selectedPond,
    required this.doc,
    required this.currentFeed,
    required this.trayResults,
    required this.roundToFeedId,
    required this.roundFeedAmounts,
  });

  PondDashboardState copyWith({
    String? selectedPond,
    int? doc,
    double? currentFeed,
    Map<int, TrayStatus>? trayResults,
    Map<int, String>? roundToFeedId,
    Map<int, double>? roundFeedAmounts,
  }) {
    return PondDashboardState(
      selectedPond: selectedPond ?? this.selectedPond,
      doc: doc ?? this.doc,
      currentFeed: currentFeed ?? this.currentFeed,
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

  PondDashboardNotifier(this.ref)
      : super(PondDashboardState(
          selectedPond: "",
          doc: 1,
          currentFeed: 15.0,
          trayResults: <int, TrayStatus>{},
          roundToFeedId: {},
          roundFeedAmounts: {},
        )) {
    // Don't initialize with a default pond, wait for explicit selection
  }

  // =========================================================
  // 🔁 POND SWITCH
  // =========================================================

  Future<void> loadTodayFeed(String pondId) async {
    final farmState = ref.read(farmProvider);
    final pond = farmState.currentFarm?.ponds.firstWhere((p) => p.id == pondId);
    
    if (pond == null) return;

    var data = await PondService().getTodayFeed(
      pondId: pondId,
      stockingDate: pond.stockingDate.toIso8601String(),
    );

    Map<int, double> feedMap = {};
    Map<int, String> idMap = {};

    // If no feed data exists for today, auto-recover by regenerating feed
    if (data.isEmpty) {
      print("⚠️ Feed missing → regenerating");

      try {
        await generateFeedPlan(
          pondId: pondId,
          startDoc: 1,
          endDoc: 30,
          stockingCount: pond.seedCount,
          pondArea: pond.area,
          stockingDate: pond.stockingDate,
        );

        final retryData = await PondService().getTodayFeed(
          pondId: pondId,
          stockingDate: pond.stockingDate.toIso8601String(),
        );

        if (retryData.isEmpty) {
          print("❌ Feed still missing after regeneration");
          return;
        }

        print("✅ Feed auto-recovered: ${retryData.length} rounds");
        data = retryData;
      } catch (e) {
        print("❌ Feed regeneration failed: $e");
        return;
      }
    }

    // Use existing database data
    for (var item in data) {
      final round = item['round'] as int;
      feedMap[round] = (item['planned_amount'] as num?)?.toDouble() ?? 0.0;
      idMap[round] = item['id'] as String? ?? '';
    }
    
    print("📥 LOADED FEED FROM DB: ${feedMap.values.map((v) => v.toStringAsFixed(2)).join(' kg | ')}");

    state = state.copyWith(
      roundFeedAmounts: feedMap,
      roundToFeedId: idMap,
    );
  }

  Future<void> _updateStateForPond(String pondId) async {
    final doc = ref.read(docProvider(pondId));

    // Load today's feed data
    await loadTodayFeed(pondId);
    
    state = state.copyWith(
      doc: doc,
      currentFeed: 15.0,
    );
  }

  void selectPond(String pondId) {
    state = state.copyWith(selectedPond: pondId);
    _updateStateForPond(pondId);
  }

  void resetPondState(String pondId) {
    if (state.selectedPond == pondId) {
      _updateStateForPond(pondId);
    }
  }

  // =========================================================
  // 🍽 FEED MARKING
  // =========================================================

  Future<void> markFeedDone(int round) async {
    final feedId = state.roundToFeedId[round];
    if (feedId == null) return;

    await FeedService().markFeedPlanCompleted(
      feedPlanId: feedId,
    );

    // Optional: Keep history logging using the actual DB amount
    final qty = state.roundFeedAmounts[round] ?? 0.0;
    if (qty > 0) {
      ref.read(feedHistoryProvider.notifier).logFeeding(
          pondId: state.selectedPond, doc: state.doc, round: round, qty: qty);
    }

    // 🔄 REFRESH FEED DATA from DB to get updated completion status
    await loadTodayFeed(state.selectedPond);
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

    // Simple tray status aggregation (replaces FeedStateEngine)
    TrayStatus finalStatus;
    if (trayStatuses.isEmpty) {
      finalStatus = TrayStatus.partial;
    } else {
      int totalScore = 0;
      for (final status in trayStatuses) {
        if (status == TrayStatus.full) {
          totalScore += 3;
        } else if (status == TrayStatus.partial) {
          totalScore += 2;
        }
        // Empty contributes 0
      }
      final double avg = totalScore / trayStatuses.length;
      if (avg >= 2.5) {
        finalStatus = TrayStatus.full;
      } else if (avg >= 1.5) {
        finalStatus = TrayStatus.partial;
      } else {
        finalStatus = TrayStatus.empty;
      }
    }

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
