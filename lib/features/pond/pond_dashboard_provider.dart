import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../services/pond_service.dart';
import '../../services/tray_service.dart';
import '../../core/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';
import '../../services/feed_service.dart';
import '../../core/engines/feed_plan_generator.dart';
import '../../core/engines/feed_plan_constants.dart';

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
  /// 'pending' | 'completed' per round — single source of truth for feed status
  final Map<int, String> roundFeedStatus;
  final bool isFeedLoading;
  /// True for one frame after auto-recovery succeeds — screen listens and shows SnackBar
  final bool feedAutoRecovered;

  PondDashboardState({
    required this.selectedPond,
    required this.doc,
    required this.currentFeed,
    required this.trayResults,
    required this.roundToFeedId,
    required this.roundFeedAmounts,
    this.roundFeedStatus = const {},
    this.isFeedLoading = false,
    this.feedAutoRecovered = false,
  });

  PondDashboardState copyWith({
    String? selectedPond,
    int? doc,
    double? currentFeed,
    Map<int, TrayStatus>? trayResults,
    Map<int, String>? roundToFeedId,
    Map<int, double>? roundFeedAmounts,
    Map<int, String>? roundFeedStatus,
    bool? isFeedLoading,
    bool? feedAutoRecovered,
  }) {
    return PondDashboardState(
      selectedPond: selectedPond ?? this.selectedPond,
      doc: doc ?? this.doc,
      currentFeed: currentFeed ?? this.currentFeed,
      trayResults: trayResults ?? this.trayResults,
      roundToFeedId: roundToFeedId ?? this.roundToFeedId,
      roundFeedAmounts: roundFeedAmounts ?? this.roundFeedAmounts,
      roundFeedStatus: roundFeedStatus ?? this.roundFeedStatus,
      isFeedLoading: isFeedLoading ?? this.isFeedLoading,
      feedAutoRecovered: feedAutoRecovered ?? this.feedAutoRecovered,
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
          currentFeed: 0.0,
          trayResults: <int, TrayStatus>{},
          roundToFeedId: {},
          roundFeedAmounts: {},
          roundFeedStatus: {},
          isFeedLoading: false,
        )) {
    // Don't initialize with a default pond, wait for explicit selection
  }

  // =========================================================
  // 🔁 POND SWITCH
  // =========================================================

  Future<void> loadTodayFeed(String pondId) async {
    state = state.copyWith(isFeedLoading: true);

    final farmState = ref.read(farmProvider);

    Pond? pond;
    for (final farm in farmState.farms) {
      final index = farm.ponds.indexWhere((p) => p.id == pondId);
      if (index != -1) {
        pond = farm.ponds[index];
        break;
      }
    }

    if (pond == null) {
      AppLogger.error("Pond not found in state: $pondId");
      state = state.copyWith(isFeedLoading: false);
      return;
    }

    var data = await PondService().getTodayFeed(
      pondId: pondId,
      stockingDate: pond.stockingDate.toIso8601String(),
    );

    // Auto-recover: regenerate plan if today's rows are missing
    bool didAutoRecover = false;
    if (data.isEmpty) {
      AppLogger.info("Feed missing for pond $pondId → regenerating");
      try {
        await generateFeedPlan(
          pondId: pondId,
          startDoc: 1,
          endDoc: 120,
          stockingCount: pond.seedCount,
          pondArea: pond.area,
          stockingDate: pond.stockingDate,
        );
        data = await PondService().getTodayFeed(
          pondId: pondId,
          stockingDate: pond.stockingDate.toIso8601String(),
        );
        if (data.isEmpty) {
          AppLogger.error("Feed still missing after regeneration for pond $pondId");
          state = state.copyWith(isFeedLoading: false);
          return;
        }
        didAutoRecover = true;
        AppLogger.info("Feed auto-recovered for pond $pondId: ${data.length} rounds");
      } catch (e) {
        AppLogger.error("Feed regeneration failed for pond $pondId", e);
        state = state.copyWith(isFeedLoading: false);
        return;
      }
    }

    final Map<int, double> feedMap = {};
    final Map<int, String> idMap = {};
    final Map<int, String> statusMap = {};

    for (var item in data) {
      final round = item['round'] as int;
      feedMap[round] = (item['planned_amount'] as num?)?.toDouble() ?? 0.0;
      idMap[round] = item['id'] as String? ?? '';
      statusMap[round] = item['status'] as String? ?? 'pending';
    }

    // ── Redistribution guard ─────────────────────────────────────────────────
    // The feed schedule screen allows editing all 4 round inputs regardless of
    // DOC. For DOC 1-7 only R1+R2 are active (config splits R3=R4=0). If a
    // user saved non-zero amounts into R3/R4 for such a DOC, the dashboard
    // would silently drop those rounds and underfeed. Instead, detect when
    // inactive rounds carry feed and redistribute the full total across the
    // active rounds proportionally (using config splits).
    {
      final doc = ref.read(docProvider(pond.id));
      final config = getFeedConfig(doc);

      // Active = rounds whose config split > 0 (1-based round numbers)
      final activeRounds = <int>[];
      for (int i = 0; i < config.splits.length; i++) {
        if (config.splits[i] > 0) activeRounds.add(i + 1);
      }

      final totalFeed = feedMap.values.fold(0.0, (s, v) => s + v);
      final inactiveHasAmount = feedMap.entries
          .any((e) => !activeRounds.contains(e.key) && e.value > 0);

      if (inactiveHasAmount && totalFeed > 0 && activeRounds.isNotEmpty) {
        AppLogger.info(
            'Redistribution triggered for pond $pondId DOC $doc: '
            'total=${totalFeed.toStringAsFixed(2)}kg across ${activeRounds.length} active rounds');

        final activeSplitTotal =
            activeRounds.fold(0.0, (s, r) => s + config.splits[r - 1]);

        for (final r in feedMap.keys.toList()) {
          if (activeRounds.contains(r)) {
            final proportion = config.splits[r - 1] / activeSplitTotal;
            feedMap[r] = double.parse(
                (totalFeed * proportion).toStringAsFixed(2));
          } else {
            feedMap[r] = 0.0;
          }
        }

        // Write corrected amounts back to DB so redistribution doesn't re-trigger
        // on every load. Uses the idMap already built from this fetch.
        // Fire-and-forget — UI state is already correct regardless of outcome.
        FeedService().persistCorrectedRounds(pondId, doc, feedMap, idMap)
            .catchError((e) {
          AppLogger.error('Redistribution write-back failed for pond $pondId', e);
        });
      }
    }
    // ────────────────────────────────────────────────────────────────────────

    AppLogger.debug("Loaded feed from DB: ${feedMap.entries.map((e) => 'R${e.key}:${e.value.toStringAsFixed(2)}kg(${statusMap[e.key]})').join(' | ')}");

    state = state.copyWith(
      roundFeedAmounts: feedMap,
      roundToFeedId: idMap,
      roundFeedStatus: statusMap,
      isFeedLoading: false,
      feedAutoRecovered: didAutoRecover,
    );

    // Ensure the rolling 7-day feed window exists ahead of today (fire-and-forget)
    final currentDoc = ref.read(docProvider(pondId));
    ensureFutureFeedExists(pondId, currentDoc).catchError((e) {
      AppLogger.error('ensureFutureFeedExists failed on load', e);
    });
  }

  /// Called by the screen after it has shown the auto-recovery notification.
  void clearAutoRecoveredFlag() {
    state = state.copyWith(feedAutoRecovered: false);
  }

  Future<void> _updateStateForPond(String pondId) async {
    final doc = ref.read(docProvider(pondId));

    // Load today's feed data
    await loadTodayFeed(pondId);

    // Calculate currentFeed as sum of all loaded round amounts
    final totalFeed = state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);

    state = state.copyWith(
      doc: doc,
      currentFeed: totalFeed,
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
  // ✏️ FEED AMOUNT OVERRIDE (edit button on round card)
  // =========================================================

  Future<void> updateRoundAmount(int round, double newAmount) async {
    final feedId = state.roundToFeedId[round];

    if (feedId != null && feedId.isNotEmpty) {
      // Row exists → update it
      await FeedService().overrideFeedAmount(
          feedPlanId: feedId, newAmount: newAmount);
    } else {
      // No row yet (DOC > 30, no schedule set) → insert pending row
      await FeedService().insertFeedRound(
        pondId: state.selectedPond,
        doc: state.doc,
        round: round,
        plannedAmount: newAmount,
        status: 'pending',
      );
    }

    // Optimistic local update so UI responds immediately
    final updatedAmounts = Map<int, double>.from(state.roundFeedAmounts);
    updatedAmounts[round] = newAmount;
    state = state.copyWith(roundFeedAmounts: updatedAmounts);

    // Then sync from DB
    await loadTodayFeed(state.selectedPond);
  }

  // =========================================================
  // 🍽 FEED MARKING
  // =========================================================

  Future<void> markFeedDone(int round) async {
    // Auto-skip tray for previous rounds that had feed done but no tray logged.
    // Only applies DOC >= 15 (tray is not relevant before that).
    final doc = state.doc;
    bool didSkipAnyTray = false;
    if (doc >= 15 && round > 1) {
      for (int prev = 1; prev < round; prev++) {
        final prevFeedDone = state.roundFeedStatus[prev] == 'completed';
        if (prevFeedDone) {
          // markTraySkipped is idempotent — silently no-ops if already logged
          await TrayService().markTraySkipped(
            pondId: state.selectedPond,
            doc: doc,
            roundNumber: prev,
          ).catchError((e) {
            AppLogger.error('Auto-skip tray failed for pond ${state.selectedPond} R$prev', e);
          });
          didSkipAnyTray = true;
        }
      }
    }

    String? feedId = state.roundToFeedId[round];
    final qty = state.roundFeedAmounts[round] ?? 0.0;

    // For DOC > 30 with no pre-existing plan row, create one on-the-fly
    if (feedId == null || feedId.isEmpty) {
      try {
        final newId = await FeedService().insertFeedRound(
          pondId: state.selectedPond,
          doc: state.doc,
          round: round,
          plannedAmount: qty,
          status: 'completed',
        );
        feedId = newId;
      } catch (e) {
        AppLogger.error('Failed to create feed_round on-the-fly', e);
        return;
      }
    } else {
      await FeedService().markFeedPlanCompleted(feedPlanId: feedId);
    }

    // Optimistic local update so UI reflects change immediately
    final updatedStatus = Map<int, String>.from(state.roundFeedStatus);
    updatedStatus[round] = 'completed';
    state = state.copyWith(roundFeedStatus: updatedStatus);

    if (qty > 0) {
      ref.read(feedHistoryProvider.notifier).logFeeding(
          pondId: state.selectedPond, doc: state.doc, round: round, qty: qty);
    }

    // 🔄 Refresh from DB → provider state → Riverpod rebuild
    await loadTodayFeed(state.selectedPond);

    // If any tray was auto-skipped, refresh tray provider so UI shows skipped state
    if (didSkipAnyTray) {
      ref.invalidate(trayProvider(state.selectedPond));
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

    // Update UI state immediately
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

    // Persist tray log to DB + trigger SmartFeedEngine (fire-and-forget)
    final pondId = state.selectedPond;
    final doc = state.doc;
    TrayService().saveTrayLog(
      pondId: pondId,
      date: latest.time,
      doc: doc,
      roundNumber: round,
      trayStatuses: trayStatuses.map((s) => s.name).toList(),
      observations: latest.observations?.map(
            (k, v) => MapEntry(k.toString(), v),
          ) ??
          {},
      aggregatedStatus: finalStatus,
    ).catchError((e) {
      AppLogger.error('Failed to persist tray log for pond $pondId', e);
    });
  }

  // =========================================================
  // 🦐 MORTALITY — UPDATE STOCK COUNT
  // =========================================================

  /// Updates the current stocking density after mortality is recorded.
  ///
  /// [newCount] is the updated number of live shrimp.
  /// Persists to `ponds.seed_count` so the next feed calculation
  /// uses the corrected density immediately.
  Future<void> updateStockCount(int newCount) async {
    final pondId = state.selectedPond;
    if (pondId.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('ponds')
          .update({'seed_count': newCount})
          .eq('id', pondId);

      AppLogger.info('Stock count updated: pond=$pondId newCount=$newCount');

      // Reload today's feed so amounts reflect the new density
      await loadTodayFeed(pondId);
    } catch (e) {
      AppLogger.error('updateStockCount failed for pond $pondId', e);
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
