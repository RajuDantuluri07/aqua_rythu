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
import '../../core/engines/feed_orchestrator.dart';
import '../../core/engines/feed_recommendation_engine.dart';
import '../../core/engines/feed_decision_engine.dart';

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
  /// Timestamp of the last completed feed round (used by FeedStatusEngine gap check).
  /// Set in-memory when markFeedDone is called; null on first feed of the day.
  final DateTime? lastFeedTime;
  /// Set to true when a tray log fails to persist to DB.
  /// Screen listens and shows a non-blocking retry banner.
  final bool trayPersistFailed;
  /// Final feed amounts per round (after manual edits)
  final Map<int, double> roundFinalFeedAmounts;
  /// Whether each round was manually edited
  final Map<int, bool> roundIsManuallyEdited;
  /// Current feed recommendation from the engine
  final FeedRecommendation? recommendation;

  /// Current feed decision from the engine
  final FeedDecision? decision;

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
    this.lastFeedTime,
    this.trayPersistFailed = false,
    this.roundFinalFeedAmounts = const {},
    this.roundIsManuallyEdited = const {},
    this.recommendation,
    this.decision,
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
    DateTime? lastFeedTime,
    bool clearLastFeedTime = false,
    bool? trayPersistFailed,
    Map<int, double>? roundFinalFeedAmounts,
    Map<int, bool>? roundIsManuallyEdited,
    FeedRecommendation? recommendation,
    FeedDecision? decision,
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
      lastFeedTime: clearLastFeedTime ? null : (lastFeedTime ?? this.lastFeedTime),
      trayPersistFailed: trayPersistFailed ?? this.trayPersistFailed,
      roundFinalFeedAmounts: roundFinalFeedAmounts ?? this.roundFinalFeedAmounts,
      roundIsManuallyEdited: roundIsManuallyEdited ?? this.roundIsManuallyEdited,
      recommendation: recommendation ?? this.recommendation,
      decision: decision ?? this.decision,
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

    // Fix #4: smart mode starts at DOC 31 (DOC 30 is still blind/tray-habit phase).
    // The DB flag must be kept in sync so engine reads of pond.isSmartFeedEnabled
    // reflect the correct boundary.
    final currentDoc = ref.read(docProvider(pondId));
    if (currentDoc >= 31 && !pond.isSmartFeedEnabled) {
      PondService().updateSmartFeedStatus(pondId: pondId, isEnabled: true)
          .then((_) {
        // Sync in-memory Pond model so all providers see the correct flag.
        ref.read(farmProvider.notifier).updateSmartFeedStatus(pondId, true);
      }).catchError((e) {
        AppLogger.error('Failed to activate smart feed for pond $pondId', e);
      });
    }

    var data = await PondService().getTodayFeed(
      pondId: pondId,
      stockingDate: pond.stockingDate.toIso8601String(),
    );

    // Auto-recover: regenerate blind schedule if today's rows are missing.
    // DOC ≥ 30 → smart mode: no pre-generated schedule is expected; skip recovery.
    bool didAutoRecover = false;
    if (data.isEmpty) {
      if (currentDoc >= 31) {
        // Fix #4: smart mode starts at DOC 31. No pre-generated schedule is expected;
        // feed amounts are computed live by the orchestrator.
        AppLogger.info(
            "Smart mode (DOC $currentDoc): no pre-generated schedule — will compute dynamically");
      } else {
        AppLogger.info("Feed missing for pond $pondId (DOC $currentDoc) → regenerating blind schedule");
        try {
          await generateFeedPlan(
            pondId: pondId,
            startDoc: 1,
            // Fix #3: clamp to currentDoc so DOC 26–29 ponds get their schedule too.
            // Previous hardcoded 25 left ponds at DOC 26–29 with no rows after recovery.
            endDoc: currentDoc.clamp(1, 29),
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
    // All 4 rounds are always active (standardFeedConfig, equal splits).
    // This guard is a safety net: if the DB somehow has amounts in rounds that
    // the current config marks inactive, redistribute the total across active
    // rounds proportionally so no feed is silently dropped.
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

    // ── Smart mode (DOC ≥ 31): inject dynamic recommendation for next round ───
    // No pre-generated rows exist for smart phase. Compute the next feed amount
    // from the full orchestrator pipeline and inject it for the pending round so
    // the timeline card displays a concrete recommended quantity.
    // Fix #4: smart mode begins at DOC 31 (DOC 30 is still blind/tray-habit phase).
    FeedRecommendation? smartRecommendation;
    FeedDecision? smartDecision;
    if (currentDoc >= 31) {
      try {
        final result = await FeedOrchestrator.computeForPond(pondId);
        smartRecommendation = result.recommendation;
        smartDecision = result.decision;
        final config = getFeedConfig(currentDoc);

        // Inject amount for the NEXT pending round only.
        // Completed rounds already have their amounts from DB rows.
        for (int r = 1; r <= 4; r++) {
          final alreadyDone = statusMap[r] == 'completed';
          final isActive = r - 1 < config.splits.length && config.splits[r - 1] > 0;
          if (!alreadyDone && isActive) {
            if ((feedMap[r] ?? 0.0) == 0.0) {
              feedMap[r] = double.parse(
                (result.finalFeed * config.splits[r - 1]).toStringAsFixed(3),
              );
            }
            statusMap[r] ??= 'pending';
            break; // only the immediate next round
          }
        }
        AppLogger.info(
            'Smart feed injected for pond $pondId DOC $currentDoc: '
            '${result.finalFeed.toStringAsFixed(3)} kg total');
      } catch (e) {
        AppLogger.error('Smart feed computation failed for $pondId (DOC $currentDoc)', e);
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    final persistedLastFeedTime = await FeedService().fetchLatestFeedTimeForDoc(
      pondId: pondId,
      doc: currentDoc,
    );
    final lastFeedTime = state.lastFeedTime != null &&
            (persistedLastFeedTime == null ||
                state.lastFeedTime!.isAfter(persistedLastFeedTime))
        ? state.lastFeedTime
        : persistedLastFeedTime;

    state = state.copyWith(
      roundFeedAmounts: feedMap,
      roundToFeedId: idMap,
      roundFeedStatus: statusMap,
      isFeedLoading: false,
      feedAutoRecovered: didAutoRecover,
      lastFeedTime: lastFeedTime,
      clearLastFeedTime: lastFeedTime == null,
      recommendation: smartRecommendation,
      decision: smartDecision,
    );

    // Ensure the rolling 7-day feed window exists ahead of today (fire-and-forget)
    // currentDoc was computed earlier in this method — reuse it here.
    ensureFutureFeedExists(pondId, currentDoc).catchError((e) {
      AppLogger.error('ensureFutureFeedExists failed on load', e);
    });
  }

  /// Called by the screen after it has shown the auto-recovery notification.
  void clearAutoRecoveredFlag() {
    state = state.copyWith(feedAutoRecovered: false);
  }

  /// Called by the screen after it has shown the tray-persist-failed notification.
  void clearTrayPersistFailedFlag() {
    state = state.copyWith(trayPersistFailed: false);
  }

  Future<void> _updateStateForPond(String pondId) async {
    final doc = ref.read(docProvider(pondId));

    // Load today's feed data
    await loadTodayFeed(pondId);

    // Calculate currentFeed as sum of all loaded round amounts
    final totalFeed = state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);

    // Compute recommendation using the full orchestrator pipeline
    FeedRecommendation? recommendation;
    FeedDecision? decision;
    try {
      final orchestratorResult = await FeedOrchestrator.computeForPond(pondId);
      recommendation = orchestratorResult.recommendation;
      decision = orchestratorResult.decision;
    } catch (e) {
      AppLogger.error('Failed to compute feed recommendation for pond $pondId', e);
    }

    state = state.copyWith(
      doc: doc,
      currentFeed: totalFeed,
      recommendation: recommendation,
      decision: decision,
    );
  }

  void selectPond(String pondId) {
    state = state.copyWith(selectedPond: pondId, clearLastFeedTime: true);
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

  Future<void> editRoundAmount(
    int round,
    double newAmount, {
    required bool persistToPlan,
  }) async {
    final updatedFinalAmounts = Map<int, double>.from(state.roundFinalFeedAmounts);
    final updatedIsEdited = Map<int, bool>.from(state.roundIsManuallyEdited);
    updatedFinalAmounts[round] = newAmount;
    updatedIsEdited[round] = true;
    state = state.copyWith(
      roundFinalFeedAmounts: updatedFinalAmounts,
      roundIsManuallyEdited: updatedIsEdited,
    );

    if (persistToPlan) {
      await updateRoundAmount(round, newAmount);
    }
  }

  // =========================================================
  // 🍽 FEED MARKING
  // =========================================================

  Future<void> markFeedDone(int round, {double? actualQty}) async {
    // Auto-skip tray for previous rounds that had feed done but no tray logged.
    // Only applies DOC >= 15 (tray is not relevant before that).
    final doc = state.doc;
    bool didSkipAnyTray = false;
    if (doc >= 15 && round > 1) {
      for (int prev = 1; prev < round; prev++) {
        final prevFeedDone = state.roundFeedStatus[prev] == 'completed';
        if (prevFeedDone) {
          final didSkip = await TrayService()
              .markTraySkipped(
                pondId: state.selectedPond,
                doc: doc,
                roundNumber: prev,
              )
              .then((_) => true)
              .catchError((e) {
            AppLogger.error('Auto-skip tray failed for pond ${state.selectedPond} R$prev', e);
            return false;
          });
          if (didSkip == true) {
            didSkipAnyTray = true;
          }
        }
      }
    }

    String? feedId = state.roundToFeedId[round];
    final plannedQty = state.roundFeedAmounts[round] ?? 0.0;
    final qty = actualQty ?? state.roundFinalFeedAmounts[round] ?? plannedQty;

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
    state = state.copyWith(
      roundFeedStatus: updatedStatus,
      lastFeedTime: DateTime.now(), // for FeedStatusEngine gap check
    );

    if (qty > 0) {
      // Fix #5: supply today's total planned feed so FeedHistoryLog.expected is
      // correct for every pond, not just the currently-selected one.
      final expectedFeedToday =
          state.roundFeedAmounts.values.fold(0.0, (s, v) => s + v);
      await ref.read(feedHistoryProvider.notifier).logFeeding(
            pondId: state.selectedPond,
            doc: state.doc,
            round: round,
            qty: qty,
            expectedFeed: expectedFeedToday,
          );
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

    // Persist tray log to DB + trigger FeedService.applyTrayAdjustment.
    // On success: reload trayProvider from DB so it's backed by persisted state.
    // On failure: set trayPersistFailed so the screen can show a retry banner.
    // The round is already unlocked in the current session because TrayLogScreen
    // called trayProvider.notifier.addTrayLog() before popping.
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
    ).then((_) async {
      // CRITICAL: After tray is logged, FeedService.applyTrayAdjustment updates feed_rounds
      // with new factor adjustments. Reload feed amounts to display new suggestion.
      // Without this, feed_rounds table is updated but UI shows stale data.
      ref.invalidate(trayProvider(pondId));
      
      // 🔥 FIX: Reload feed data so next feed suggestion shows SmartFeedEngineV2's adjustment
      await loadTodayFeed(pondId);
      
      // Update currentFeed in state after reload
      final totalFeed = state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);
      state = state.copyWith(currentFeed: totalFeed);
    }).catchError((e) {
      AppLogger.error('Failed to persist tray log for pond $pondId', e);
      // Surface error to farmer so they know to re-log if they restart the app.
      state = state.copyWith(trayPersistFailed: true);
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
