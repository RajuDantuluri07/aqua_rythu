import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
import 'package:aqua_rythu/core/services/tray_service.dart';
import '../../features/tray/enums/tray_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';
import 'package:aqua_rythu/core/services/feed_service.dart';
import '../../systems/planning/feed_plan_generator.dart';
import '../../systems/feed/feed_recommendation_engine.dart';
import '../../systems/feed/feed_decision_engine.dart';
import 'controllers/pond_dashboard_controller.dart';

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

  /// True when DOC >= 31 and anchor feed has not been set yet.
  /// Screen listens and shows the anchor feed input dialog once.
  final bool needsAnchorFeedInput;

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
    this.needsAnchorFeedInput = false,
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
    bool? needsAnchorFeedInput,
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
      lastFeedTime:
          clearLastFeedTime ? null : (lastFeedTime ?? this.lastFeedTime),
      trayPersistFailed: trayPersistFailed ?? this.trayPersistFailed,
      roundFinalFeedAmounts:
          roundFinalFeedAmounts ?? this.roundFinalFeedAmounts,
      roundIsManuallyEdited:
          roundIsManuallyEdited ?? this.roundIsManuallyEdited,
      recommendation: recommendation ?? this.recommendation,
      decision: decision ?? this.decision,
      needsAnchorFeedInput: needsAnchorFeedInput ?? this.needsAnchorFeedInput,
    );
  }
}

/// =======================
/// NOTIFIER
/// =======================

class PondDashboardNotifier extends StateNotifier<PondDashboardState> {
  final Ref ref;
  final PondDashboardController _controller;

  PondDashboardNotifier(this.ref)
      : _controller = PondDashboardController(),
        super(PondDashboardState(
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
  // 🔁 POND SWITCH - SINGLE SOURCE OF TRUTH VIA CONTROLLER
  // =========================================================

  /// Loads today's feed using the controller as single orchestrator.
  ///
  /// ✅ ARCHITECTURE: UI → Controller → Engine → State
  /// ✅ Guarantees: Feed engine runs exactly ONCE per pond+doc load
  /// ✅ Prevents: Duplicate calculations, UI flickering, inconsistent values
  Future<void> loadTodayFeed(String pondId) async {
    state = state.copyWith(isFeedLoading: true);

    final farmState = ref.read(farmProvider);

    // Find pond in farm state
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

    final currentDoc = ref.read(docProvider(pondId));

    // Activate smart feed if needed
    final needsAnchor = currentDoc >= 31 && !pond.isAnchorInitialized;
    if (currentDoc >= 31 && !pond.isSmartFeedEnabled) {
      PondService()
          .updateSmartFeedStatus(pondId: pondId, isEnabled: true)
          .then((_) {
        ref.read(farmProvider.notifier).updateSmartFeedStatus(pondId, true);
      }).catchError((e) {
        AppLogger.error('Failed to activate smart feed for pond $pondId', e);
      });
    }

    // ✅ SINGLE SOURCE OF TRUTH: Controller orchestrates all data loading
    final viewState = await _controller.load(pondId, knownDoc: currentDoc);

    if (viewState.error != null) {
      AppLogger.error('Controller error for pond $pondId: ${viewState.error}');
      state = state.copyWith(isFeedLoading: false);
      return;
    }

    // Fetch last feed time for gap check
    final persistedLastFeedTime = await FeedService().fetchLatestFeedTimeForDoc(
      pondId: pondId,
      doc: currentDoc,
    );
    final lastFeedTime = state.lastFeedTime != null &&
            (persistedLastFeedTime == null ||
                state.lastFeedTime!.isAfter(persistedLastFeedTime))
        ? state.lastFeedTime
        : persistedLastFeedTime;

    // Equality guards: only replace when values actually changed
    final newRecommendation =
        (viewState.feedResult?.recommendation == state.recommendation)
            ? null
            : viewState.feedResult?.recommendation;
    final newDecision = (viewState.feedResult?.decision == state.decision)
        ? null
        : viewState.feedResult?.decision;

    // TASK 10: only update feed amounts when they actually changed
    final prevAmounts = state.roundFeedAmounts;
    final feedChanged =
        viewState.roundFeedAmounts.length != prevAmounts.length ||
            viewState.roundFeedAmounts.entries
                .any((e) => prevAmounts[e.key] != e.value);

    AppLogger.info('⚡ Feed state updated via controller | pondId: $pondId | '
        'total: ${viewState.totalFeed.toStringAsFixed(2)}kg | '
        'fromCache: ${_controller.cachedResult(pondId, currentDoc) != null}');

    state = state.copyWith(
      roundFeedAmounts: feedChanged ? viewState.roundFeedAmounts : null,
      roundToFeedId: viewState.roundToFeedId,
      roundFeedStatus: viewState.roundFeedStatus,
      isFeedLoading: false,
      feedAutoRecovered: viewState.feedAutoRecovered,
      lastFeedTime: lastFeedTime,
      clearLastFeedTime: lastFeedTime == null,
      recommendation: newRecommendation,
      decision: newDecision,
      needsAnchorFeedInput: needsAnchor,
    );

    // Ensure the rolling 7-day feed window exists ahead of today (fire-and-forget)
    // currentDoc was computed earlier in this method — reuse it here.
    ensureFutureFeedExists(pondId, currentDoc).catchError((e) {
      AppLogger.error('ensureFutureFeedExists failed on load', e);
    });
  }

  /// Called by the screen after the anchor feed dialog is shown/dismissed.
  void clearNeedsAnchorFeedInput() {
    state = state.copyWith(needsAnchorFeedInput: false);
  }

  /// Save farmer-entered anchor feed to DB + update in-memory Pond state.
  Future<void> updateAnchorFeed(double anchorFeed) async {
    final pondId = state.selectedPond;
    if (pondId.isEmpty) return;

    try {
      await PondService()
          .updateAnchorFeed(pondId: pondId, anchorFeed: anchorFeed);
      ref.read(farmProvider.notifier).updateAnchorFeed(pondId, anchorFeed);
      state = state.copyWith(needsAnchorFeedInput: false);
      await loadTodayFeed(pondId);
    } catch (e) {
      AppLogger.error('Failed to save anchor feed for pond $pondId', e);
    }
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

    // loadTodayFeed already runs the orchestrator for DOC >= 31 and sets
    // recommendation + decision in state. No second orchestrator call needed.
    await loadTodayFeed(pondId);

    final totalFeed =
        state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);
    state = state.copyWith(
      doc: doc,
      currentFeed: totalFeed,
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
    final pondId = state.selectedPond;

    if (feedId != null && feedId.isNotEmpty) {
      // Row exists → update it
      await FeedService()
          .overrideFeedAmount(feedPlanId: feedId, newAmount: newAmount);
    } else {
      // No row yet (DOC > 30, no schedule set) → insert pending row
      await FeedService().insertFeedRound(
        pondId: pondId,
        doc: state.doc,
        round: round,
        plannedAmount: newAmount,
        status: 'pending',
      );
    }

    // 🔄 CACHE INVALIDATION: Manual feed edit affects future calculations
    _controller.invalidateDoc(pondId, state.doc);

    // Optimistic local update so UI responds immediately
    final updatedAmounts = Map<int, double>.from(state.roundFeedAmounts);
    updatedAmounts[round] = newAmount;
    state = state.copyWith(roundFeedAmounts: updatedAmounts);

    // Then sync from DB
    await loadTodayFeed(pondId);
  }

  Future<void> editRoundAmount(
    int round,
    double newAmount, {
    required bool persistToPlan,
  }) async {
    final updatedFinalAmounts =
        Map<int, double>.from(state.roundFinalFeedAmounts);
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
            AppLogger.error(
                'Auto-skip tray failed for pond ${state.selectedPond} R$prev',
                e);
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

    // 🔄 CACHE INVALIDATION: Feed completion affects intelligence calculations
    _controller.invalidateDoc(state.selectedPond, state.doc);

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

    // Persist tray log to DB + trigger SmartFeedEngine.
    // On success: reload trayProvider from DB so it's backed by persisted state.
    // On failure: set trayPersistFailed so the screen can show a retry banner.
    // The round is already unlocked in the current session because TrayLogScreen
    // called trayProvider.notifier.addTrayLog() before popping.
    final pondId = state.selectedPond;
    final doc = state.doc;
    TrayService()
        .saveTrayLog(
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
    )
        .then((_) async {
      // 🔄 CACHE INVALIDATION: Tray update affects smart feed calculations
      // This ensures the controller fetches fresh tray data next load
      _controller.invalidate(pondId);

      // CRITICAL: After tray is logged, SmartFeedEngine updates feed_rounds
      // with new factor adjustments. Reload feed amounts to display new suggestion.
      // Without this, feed_rounds table is updated but UI shows stale data.
      ref.invalidate(trayProvider(pondId));

      // 🔥 FIX: Reload feed data so next feed suggestion shows SmartFeedEngine's adjustment
      await loadTodayFeed(pondId);

      // Update currentFeed in state after reload
      final totalFeed =
          state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);
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
          .update({'seed_count': newCount}).eq('id', pondId);

      AppLogger.info('Stock count updated: pond=$pondId newCount=$newCount');

      // 🔄 CACHE INVALIDATION: Density change affects ALL future feed calculations
      _controller.invalidate(pondId);

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
