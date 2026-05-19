import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../core/services/analytics_service.dart';
import '../../core/utils/feed_debug_logger.dart';
import '../../core/utils/uuid_generator.dart';
import '../../core/models/feed_pending_operation.dart';
import '../../core/services/feed_sync_queue.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
import 'package:aqua_rythu/core/services/tray_service.dart';
import 'package:aqua_rythu/core/services/tray_check_service.dart';
import '../../features/tray/enums/tray_status.dart';
import '../../features/tray/tray_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/tray_provider.dart';
import 'package:aqua_rythu/core/services/feed_service.dart';
import '../../systems/planning/feed_plan_generator.dart';
import '../../systems/feed/feed_models.dart';
import '../feed/models/feed_debug_info.dart';
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

  /// True while a tray save is in flight — prevents double-submit.
  final bool isTraySaving;

  /// Final feed amounts per round (after manual edits)
  final Map<int, double> roundFinalFeedAmounts;

  /// Whether each round was manually edited
  final Map<int, bool> roundIsManuallyEdited;

  /// Current feed recommendation from the engine
  final FeedRecommendation? recommendation;

  /// Current feed decision from the engine
  final FeedDecision? decision;

  /// Current feed debug data from the engine
  final FeedDebugInfo? feedDebugInfo;

  /// True when DOC >= 31 and anchor feed has not been set yet.
  /// Screen listens and shows the anchor feed input dialog once.
  final bool needsAnchorFeedInput;

  /// Non-null when the pond cannot be loaded due to missing/corrupt setup data
  /// (e.g. null stocking_date). The screen renders an error card instead of
  /// crashing. Other ponds are unaffected.
  final String? pondSetupError;

  /// Non-null after a feed save that succeeded but depleted stock below zero.
  /// Screen should show a non-blocking warning banner, then clear it.
  final String? stockWarning;

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
    this.isTraySaving = false,
    this.roundFinalFeedAmounts = const {},
    this.roundIsManuallyEdited = const {},
    this.recommendation,
    this.decision,
    this.feedDebugInfo,
    this.needsAnchorFeedInput = false,
    this.pondSetupError,
    this.stockWarning,
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
    bool? isTraySaving,
    Map<int, double>? roundFinalFeedAmounts,
    Map<int, bool>? roundIsManuallyEdited,
    FeedRecommendation? recommendation,
    FeedDecision? decision,
    FeedDebugInfo? feedDebugInfo,
    bool? needsAnchorFeedInput,
    String? pondSetupError,
    bool clearPondSetupError = false,
    String? stockWarning,
    bool clearStockWarning = false,
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
      isTraySaving: isTraySaving ?? this.isTraySaving,
      roundFinalFeedAmounts:
          roundFinalFeedAmounts ?? this.roundFinalFeedAmounts,
      roundIsManuallyEdited:
          roundIsManuallyEdited ?? this.roundIsManuallyEdited,
      recommendation: recommendation ?? this.recommendation,
      decision: decision ?? this.decision,
      feedDebugInfo: feedDebugInfo ?? this.feedDebugInfo,
      needsAnchorFeedInput: needsAnchorFeedInput ?? this.needsAnchorFeedInput,
      pondSetupError:
          clearPondSetupError ? null : (pondSetupError ?? this.pondSetupError),
      stockWarning:
          clearStockWarning ? null : (stockWarning ?? this.stockWarning),
    );
  }
}

/// =======================
/// NOTIFIER
/// =======================

class PondDashboardNotifier extends StateNotifier<PondDashboardState> {
  final Ref ref;
  final PondDashboardController _controller;

  // Lock mechanism to prevent concurrent feed updates
  final Set<String> _updateLocks = <String>{};

  PondDashboardNotifier(this.ref, String pondId)
      : _controller = PondDashboardController(),
        super(PondDashboardState(
          selectedPond: pondId,
          doc: 1,
          currentFeed: 0.0,
          trayResults: <int, TrayStatus>{},
          roundToFeedId: {},
          roundFeedAmounts: {},
          roundFeedStatus: {},
          isFeedLoading: false,
        )) {
    if (pondId.isNotEmpty) {
      Future.microtask(() => _updateStateForPond(pondId));
    }
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
    state = state.copyWith(isFeedLoading: true, clearPondSetupError: true);

    try {
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
        try {
          await PondService()
              .updateSmartFeedStatus(pondId: pondId, isEnabled: true);
          ref.read(farmProvider.notifier).updateSmartFeedStatus(pondId, true);
        } catch (e) {
          AppLogger.error('Failed to activate smart feed for pond $pondId', e);
        }
      }

      // ✅ SINGLE SOURCE OF TRUTH: Controller orchestrates all data loading
      final viewState = await _controller.load(pondId, knownDoc: currentDoc);

      if (viewState.error != null) {
        AppLogger.error(
          'Controller error for pond $pondId: ${viewState.error}',
          Exception(viewState.error),
        );
        state = state.copyWith(
          isFeedLoading: false,
          pondSetupError: viewState.error,
        );
        return;
      }

      // Fetch last feed time for gap check
      final persistedLastFeedTime =
          await FeedService().fetchLatestFeedTimeForDoc(
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
        feedDebugInfo: viewState.feedResult?.debugInfo,
        needsAnchorFeedInput: needsAnchor,
      );

      // Ensure the rolling 7-day feed window exists ahead of today (fire-and-forget)
      // currentDoc was computed earlier in this method — reuse it here.
      ensureFutureFeedExists(pondId, currentDoc).catchError((e) {
        AppLogger.error('ensureFutureFeedExists failed on load', e);
      });
    } catch (e, stackTrace) {
      // Top-level guard: any unexpected exception (e.g. null stocking_date in
      // docProvider, corrupt DB row) transitions to an error state rather than
      // crashing the screen or escaping as an unhandled future.
      AppLogger.error(
        'loadTodayFeed unexpected error for pond $pondId — showing setup error card',
        e,
        stackTrace,
      );
      state = state.copyWith(
        isFeedLoading: false,
        pondSetupError: 'Failed to load pond data: $e',
      );
    }
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

  void clearStockWarning() {
    state = state.copyWith(clearStockWarning: true);
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
  // 🔒 LOCKING HELPERS
  // =========================================================

  bool _tryAcquireLock(String lockKey) {
    if (_updateLocks.contains(lockKey)) {
      return false; // Already locked
    }
    _updateLocks.add(lockKey);
    return true;
  }

  void _releaseLock(String lockKey) {
    _updateLocks.remove(lockKey);
  }

  // =========================================================
  // ✏️ FEED AMOUNT OVERRIDE (edit button on round card)
  // =========================================================

  Future<void> updateRoundAmount(int round, double newAmount) async {
    final pondId = state.selectedPond;
    final lockKey = '${pondId}_round_$round';

    // Prevent concurrent updates to the same round
    if (!_tryAcquireLock(lockKey)) {
      AppLogger.warn(
          'Feed update already in progress for round $round in pond $pondId');
      return;
    }

    try {
      final feedId = state.roundToFeedId[round];

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
    } finally {
      _releaseLock(lockKey);
    }
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
    // Capture pond/doc once — state may change during awaits below.
    final pondId = state.selectedPond;
    final doc = state.doc;
    final lockKey = '${pondId}_mark_feed_$round';

    FeedDebugLogger.logFeedAction(
      pondId: pondId,
      doc: doc,
      round: round,
      status: 'started',
      source: 'user_action',
      feedEntered: actualQty,
    );

    AppLogger.info('FEED SAVE: pond=$pondId round=$round doc=$doc qty=$actualQty');

    // Phase 4: Prevent concurrent feed marking for the SAME round (double-tap guard).
    if (!_tryAcquireLock(lockKey)) {
      AppLogger.warn(
          'Feed marking already in progress for round $round in pond $pondId');
      FeedDebugLogger.logDuplicatePrevention(
        pondId: pondId,
        doc: doc,
        round: round,
        reason: 'concurrent_operation_locked',
      );
      return;
    }

    try {
      // Auto-skip tray for previous rounds that had feed done but no tray logged.
      // Only applies DOC >= 15 (tray is not relevant before that).
      bool didSkipAnyTray = false;
      if (doc >= 15 && round > 1) {
        for (int prev = 1; prev < round; prev++) {
          final prevFeedDone = state.roundFeedStatus[prev] == 'completed';
          if (prevFeedDone) {
            try {
              await TrayService().markTraySkipped(
                pondId: pondId,
                doc: doc,
                roundNumber: prev,
              );
              didSkipAnyTray = true;
            } catch (e) {
              AppLogger.error(
                  'Auto-skip tray failed for pond $pondId R$prev', e);
            }
          }
        }
      }

      // Validate feed amounts — fail loudly if data is missing.
      if (!state.roundFeedAmounts.containsKey(round)) {
        throw ArgumentError(
            'Missing feed amount for round $round in pond $pondId');
      }
      final plannedQty = state.roundFeedAmounts[round]!;

      // Use actual quantity if provided, otherwise use the final (possibly edited) amount.
      final qty = actualQty ?? state.roundFinalFeedAmounts[round] ?? plannedQty;

      // Phase 5: Guard against corrupted engine output before any DB call.
      if (qty.isNaN || qty.isInfinite) {
        throw ArgumentError(
            'Feed quantity is ${qty.isNaN ? "NaN" : "Infinite"} for '
            'round $round in pond $pondId — engine produced invalid output.');
      }
      if (qty < 0) {
        throw ArgumentError(
            'Negative feed quantity ${qty.toStringAsFixed(3)}kg '
            'for round $round in pond $pondId.');
      }
      // Note: the 50 kg upper bound is also enforced inside FeedService._validateFeedAmount.
      // The check here gives a clearer error message in the UI context.
      if (qty > 50.0) {
        throw ArgumentError(
            'Feed quantity ${qty.toStringAsFixed(1)}kg exceeds 50 kg per round '
            'for pond=$pondId doc=$doc round=$round. '
            'Possible engine calculation error.');
      }

      // Phase 1: Generate a deterministic operation_id BEFORE the first DB attempt.
      // This UUID travels with the operation through retries and the offline queue.
      // The DB RPC checks it on entry — if already present, no writes occur.
      final operationId = generateUuidV4();

      AppLogger.info(
          'FEED SAVE: pond=$pondId doc=$doc round=$round '
          'qty=${qty.toStringAsFixed(3)}kg operationId=$operationId');

      // Calculate expected feed for today (needed for history logging).
      final expectedFeedToday =
          state.roundFeedAmounts.values.fold(0.0, (s, v) => s + v);

      // Phase 3+6: Attempt DB write; enqueue for offline retry on failure.
      // InsufficientStockException is thrown AFTER a successful save — handle
      // it separately so the feed is marked done AND the warning is surfaced.
      try {
        await FeedService().saveFeedEntry(
          pondId: pondId,
          doc: doc,
          feedKg: qty,
          selectedRound: round,
          isPro: state.recommendation != null,
          operationId: operationId,
        );
      } on InsufficientStockException catch (e) {
        // Feed was saved successfully; show a non-blocking warning to the farmer.
        state = state.copyWith(stockWarning: e.message);
      } catch (e) {
        // Network/server failure — preserve the operation locally so it can
        // be replayed when connectivity is restored. The same operationId
        // guarantees the DB deduplicates any successful replay.
        AppLogger.warn(
            'FEED SAVE: DB write failed, enqueueing for offline retry '
            '(pond=$pondId doc=$doc r=$round opId=$operationId): $e');
        await FeedSyncQueue().enqueue(FeedPendingOperation(
          operationId: operationId,
          pondId: pondId,
          doc: doc,
          round: round,
          feedKg: qty,
          baseFeed: qty,
          createdAt: DateTime.now(),
          queuedAt: DateTime.now(),
        ));
        // Still update local UI state so the farmer sees "completed" immediately.
        // The sync queue will reconcile with the server in the background.
      }

      final actualDbFeedSaved = qty;
      _controller.invalidateDoc(pondId, doc);

      // ─── Step 3: Post-save — state refresh + history ───────────────────────
      // Mark round completed immediately — feed IS in DB regardless of what
      // happens during the refresh steps below.
      {
        final updatedStatus = Map<int, String>.from(state.roundFeedStatus);
        updatedStatus[round] = 'completed';
        state = state.copyWith(
          roundFeedStatus: updatedStatus,
          lastFeedTime: DateTime.now(),
        );
      }

      try {
        // Reload from DB so amounts and other rounds reflect latest DB state.
        await loadTodayFeed(pondId);

        // Re-apply completed status after reload (loadTodayFeed may overwrite state).
        final reloadedStatus = Map<int, String>.from(state.roundFeedStatus);
        reloadedStatus[round] = 'completed';
        state = state.copyWith(roundFeedStatus: reloadedStatus);

        AppLogger.info(
            'logFeeding: pond=$pondId doc=$doc round=$round qty=${actualDbFeedSaved.toStringAsFixed(3)}kg');
        unawaited(AnalyticsService.instance.logFeedRoundCompleted(
          pondId: pondId, doc: doc, round: round, qty: actualDbFeedSaved,
        ));
        await ref.read(feedHistoryProvider.notifier).logFeeding(
              pondId: pondId,
              doc: doc,
              round: round,
              qty: actualDbFeedSaved,
              expectedFeed: expectedFeedToday,
            );

        await ref
            .read(feedHistoryProvider.notifier)
            .loadHistoryForPonds([pondId]);

        final difference = plannedQty > 0
            ? ((actualDbFeedSaved - plannedQty) / plannedQty * 100)
            : 0.0;

        FeedDebugLogger.logFeedAction(
          pondId: pondId,
          doc: doc,
          round: round,
          status: 'success',
          source: 'user_action',
          feedEntered: actualQty,
          feedSaved: actualDbFeedSaved,
          calculatedFeed: plannedQty,
          difference: difference,
        );

        if (didSkipAnyTray) {
          ref.invalidate(trayProvider(pondId));
        }
      } catch (e) {
        // Post-save refresh failed but feed IS already saved to DB.
        // Do NOT rethrow — farmer's feed is recorded; only the local reload failed.
        FeedDebugLogger.logFeedError(
          pondId: pondId,
          doc: doc,
          round: round,
          operation: 'markFeedDone_postSave',
          error: e.toString(),
          context: {
            'actualQty': actualQty,
            'plannedQty': plannedQty,
            'savePath': 'direct_feed_logs_insert',
          },
        );
        AppLogger.error(
            'Post-save refresh failed (feed IS saved in DB) pond=$pondId round=$round',
            e);
      }
    } finally {
      _releaseLock(lockKey);
    }
  }

  // =========================================================
  // 🧠 TRAY LOGIC (FIXED)
  // =========================================================

  Future<void> logTray(int round) async {
    final pondId = state.selectedPond;
    final lockKey = '${pondId}_log_tray_$round';

    // Prevent double-submit: both the in-process lock and the isTraySaving flag
    if (state.isTraySaving) {
      AppLogger.warn('Tray save already in flight, ignoring duplicate call');
      return;
    }

    // Prevent concurrent tray logging for the same round
    if (!_tryAcquireLock(lockKey)) {
      AppLogger.warn(
          'Tray logging already in progress for round $round in pond $pondId');
      return;
    }

    state = state.copyWith(isTraySaving: true);
    try {
      final trayLogs = ref.read(trayProvider(state.selectedPond));
      if (trayLogs.isEmpty) return;

      final latest = trayLogs.last;

      // The tray log now directly provides a list of TrayStatus enums.
      final List<TrayStatus> trayStatuses = latest.trays;
      if (trayStatuses.isEmpty) return;

      // Simple tray status aggregation (replaces FeedStateEngine)
      TrayStatus finalStatus;
      {
        int totalScore = 0;
        for (final status in trayStatuses) {
          if (status == TrayStatus.heavy) {
            totalScore += 3;
          } else if (status == TrayStatus.medium) {
            totalScore += 2;
          } else if (status == TrayStatus.light) {
            totalScore += 1;
          }
          // Empty contributes 0
        }
        final double avg = totalScore / trayStatuses.length;
        if (avg >= 2.5) {
          finalStatus = TrayStatus.heavy;
        } else if (avg >= 1.5) {
          finalStatus = TrayStatus.medium;
        } else if (avg >= 0.5) {
          finalStatus = TrayStatus.light;
        } else {
          finalStatus = TrayStatus.empty;
        }
      }

      // 🔒 FIX #8: Store original state for potential revert
      final originalTrayResults = Map<int, TrayStatus>.from(state.trayResults);

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

      // 🔒 FIX #6: Persist tray log to DB with proper async/await to ensure engine timing
      // On success: reload trayProvider from DB so it's backed by persisted state.
      // On failure: set trayPersistFailed so the screen can show a retry banner.
      // The round is already unlocked in the current session because TrayLogScreen
      // called trayProvider.notifier.addTrayLog() before popping.
      final pondId = state.selectedPond;
      final doc = state.doc;

      AnalyticsService.instance.logTraySaveStarted(
        pondId: pondId,
        doc: doc,
        round: round,
        hasObservations: latest.observations?.isNotEmpty ?? false,
      );

      try {
        final trayLog = TrayLog(
          pondId: pondId,
          time: latest.time,
          doc: doc,
          round: round,
          trays: trayStatuses,
          observations: latest.observations,
          isSkipped: latest.isSkipped,
        );
        await TrayService().saveTrayLog(trayLog);

        // Unified architecture: also write to tray_checks (linked to feed_round).
        // This is a best-effort dual-write — failure does NOT revert the primary
        // tray_logs save so the farmer's data is never lost.
        unawaited(_saveTrayCheckLinked(
          pondId: pondId,
          doc: doc,
          round: round,
          trays: trayStatuses,
          observations: trayLog.observations,
          checkedAt: trayLog.time,
        ));

        AnalyticsService.instance.logTraySaveSuccess(
          pondId: pondId,
          doc: doc,
          round: round,
        );

        // Tray update affects smart feed calculations — reload from DB.
        _controller.invalidate(pondId);
        ref.invalidate(trayProvider(pondId));
        AnalyticsService.instance.logTrayProviderInvalidated(
          pondId: pondId,
          trigger: 'save_success',
        );

        await loadTodayFeed(pondId);

        final totalFeed =
            state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);
        state = state.copyWith(currentFeed: totalFeed);
      } catch (e) {
        final reason = e.toString();
        AppLogger.error(
            'Failed to persist tray log for pond $pondId, reverting UI state',
            e);

        AnalyticsService.instance.logTraySaveFailed(
          pondId: pondId,
          doc: doc,
          round: round,
          reason: reason,
        );

        // Revert UI state and flush the in-memory addTrayLog entry so
        // isPendingTray=true immediately — farmer can retry without restart.
        state = state.copyWith(
          trayResults: originalTrayResults,
          trayPersistFailed: true,
        );
        ref.invalidate(trayProvider(pondId));
        AnalyticsService.instance.logTrayProviderInvalidated(
          pondId: pondId,
          trigger: 'save_failed_revert',
        );
      }
    } catch (e) {
      AppLogger.error('Tray logging failed for pond $pondId round $round', e);
    } finally {
      state = state.copyWith(isTraySaving: false);
      _releaseLock(lockKey);
    }
  }

  /// Best-effort dual-write to tray_checks (unified architecture).
  /// Looks up the feed_round_id then saves the tray check under it.
  /// Never throws — failures are logged but must not revert the primary save.
  Future<void> _saveTrayCheckLinked({
    required String pondId,
    required int doc,
    required int round,
    required List<TrayStatus> trays,
    required Map<int, List<String>>? observations,
    required DateTime checkedAt,
  }) async {
    try {
      final svc = TrayCheckService();
      final feedRoundId = await svc.getFeedRoundId(
        pondId: pondId,
        doc: doc,
        round: round,
      );
      if (feedRoundId == null) {
        AppLogger.warn(
          'logTray: no feed_round for pond=$pondId doc=$doc round=$round '
          '— tray_check not linked (orphan risk)',
        );
        return;
      }
      await svc.saveTrayCheck(
        feedRoundId: feedRoundId,
        pondId: pondId,
        trays: trays,
        observations: observations,
        checkedAt: checkedAt,
      );
    } catch (e) {
      AppLogger.warn(
        'logTray: tray_check dual-write failed (non-blocking) '
        'pond=$pondId doc=$doc round=$round: $e',
      );
    }
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
    StateNotifierProvider.family.autoDispose<PondDashboardNotifier, PondDashboardState, String>(
      (ref, pondId) => PondDashboardNotifier(ref, pondId),
    );
