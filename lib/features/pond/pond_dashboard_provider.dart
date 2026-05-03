import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/feed_debug_logger.dart';
import 'package:aqua_rythu/core/services/pond_service.dart';
import 'package:aqua_rythu/core/services/tray_service.dart';
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
    this.feedDebugInfo,
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
    FeedDebugInfo? feedDebugInfo,
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
      feedDebugInfo: feedDebugInfo ?? this.feedDebugInfo,
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

  // Lock mechanism to prevent concurrent feed updates
  final Set<String> _updateLocks = <String>{};

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
      feedDebugInfo: viewState.feedResult?.debugInfo,
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
    final pondId = state.selectedPond;
    final lockKey = '${pondId}_mark_feed_$round';

    // 🔴 DEBUG: Log feed action start
    FeedDebugLogger.logFeedAction(
      pondId: pondId,
      doc: state.doc,
      round: round,
      status: 'started',
      source: 'user_action',
      feedEntered: actualQty,
    );

    // Prevent concurrent feed marking for the same round
    if (!_tryAcquireLock(lockKey)) {
      AppLogger.warn(
          'Feed marking already in progress for round $round in pond $pondId');

      // 🔴 DEBUG: Log duplicate prevention
      FeedDebugLogger.logDuplicatePrevention(
        pondId: pondId,
        doc: state.doc,
        round: round,
        reason: 'concurrent_operation_locked',
      );
      return;
    }

    try {
      // Auto-skip tray for previous rounds that had feed done but no tray logged.
      // Only applies DOC >= 15 (tray is not relevant before that).
      final doc = state.doc;
      bool didSkipAnyTray = false;
      if (doc >= 15 && round > 1) {
        for (int prev = 1; prev < round; prev++) {
          final prevFeedDone = state.roundFeedStatus[prev] == 'completed';
          if (prevFeedDone) {
            bool didSkip = false;
            try {
              await TrayService().markTraySkipped(
                pondId: pondId,
                doc: doc,
                roundNumber: prev,
              );
              didSkip = true;
            } catch (e) {
              AppLogger.error(
                  'Auto-skip tray failed for pond $pondId R$prev', e);
              didSkip = false;
            }
            if (didSkip == true) {
              didSkipAnyTray = true;
            }
          }
        }
      }

      // Validate feed amounts - fail loudly if data is missing
      if (!state.roundFeedAmounts.containsKey(round)) {
        throw ArgumentError(
            'Missing feed amount for round $round in pond ${state.selectedPond}');
      }
      final plannedQty = state.roundFeedAmounts[round]!;

      // Use actual quantity if provided, otherwise use planned
      final qty = actualQty ?? state.roundFinalFeedAmounts[round] ?? plannedQty;

      // Validate final quantity
      if (qty <= 0) {
        throw ArgumentError(
            'Invalid feed quantity $qty for round $round in pond ${state.selectedPond}');
      }

      // 🔴 CRITICAL: Prevent duplicate round completion
      if (state.roundFeedStatus[round] == 'completed') {
        AppLogger.warn(
            'Round $round already completed for pond $pondId - skipping');

        // 🔴 DEBUG: Log duplicate prevention
        FeedDebugLogger.logDuplicatePrevention(
          pondId: pondId,
          doc: state.doc,
          round: round,
          reason: 'round_already_completed',
        );
        return;
      }

      // Calculate expected feed for today (needed for both transaction and fallback)
      final expectedFeedToday =
          state.roundFeedAmounts.values.fold(0.0, (s, v) => s + v);

      // 🔒 CRITICAL: Sequential execution - Transaction → DB Read → State Update
      double actualDbFeedSaved = 0.0;
      bool transactionSuccess = false;

      try {
        // Step 1: Await DB transaction (MUST BE FULLY COMMITTED FIRST)
        final supabase = Supabase.instance.client;
        transactionSuccess =
            await supabase.rpc('complete_feed_round_with_log', params: {
          'p_pond_id': state.selectedPond,
          'p_doc': state.doc,
          'p_round': round,
          'p_feed_amount': qty,
          'p_base_feed': qty, // Use actual feed as base feed for consistency
          'p_created_at': DateTime.now().toIso8601String(),
        });

        if (!transactionSuccess) {
          // 🔴 DEBUG: Log transaction failure
          FeedDebugLogger.logTransaction(
            pondId: pondId,
            doc: state.doc,
            round: round,
            transactionType: 'complete_feed_round_with_log',
            success: false,
            details: 'likely_duplicate_entry',
          );
          throw Exception('Feed transaction failed - likely duplicate entry');
        }

        // Step 2: IMMEDIATELY fetch fresh DB value (NO PARALLEL OPERATIONS)
        // This ensures we get the ACTUAL committed value, not stale data
        try {
          final dbResult = await supabase
              .from('feed_logs')
              .select('feed_given')
              .eq('pond_id', state.selectedPond)
              .eq('doc', state.doc)
              .eq('round', round)
              .order('created_at', ascending: false)
              .limit(1)
              .single();

          actualDbFeedSaved = (dbResult['feed_given'] as num).toDouble();
          AppLogger.info(
              '✅ DB read successful: actual stored feed = ${actualDbFeedSaved.toStringAsFixed(2)}kg');
        } catch (dbReadError) {
          AppLogger.error(
              'Failed to read actual DB feed value after transaction',
              dbReadError);
          throw Exception(
              'DB transaction succeeded but failed to read committed value: $dbReadError');
        }

        // 🔴 DEBUG: Log transaction success with actual DB value
        FeedDebugLogger.logTransaction(
          pondId: pondId,
          doc: state.doc,
          round: round,
          transactionType: 'complete_feed_round_with_log',
          success: true,
          details:
              'feed_round_and_log_saved_successfully, actual_db_feed=${actualDbFeedSaved.toStringAsFixed(2)}kg',
        );

        AppLogger.info(
            'Feed transaction + DB read completed successfully for pond $pondId round $round, actual feed: ${actualDbFeedSaved.toStringAsFixed(2)}kg');
      } catch (e) {
        // 🔴 DEBUG: Log transaction error
        FeedDebugLogger.logTransaction(
          pondId: pondId,
          doc: state.doc,
          round: round,
          transactionType: 'complete_feed_round_with_log',
          success: false,
          details: e.toString(),
        );
        AppLogger.error(
            'Feed transaction failed for pond $pondId round $round', e);
        rethrow;
      }

      // 🔒 CRITICAL: Sequential execution - Transaction → DB Read → State Update → UI
      try {
        // Step 1: DB transaction (already completed above with immediate DB read)
        // Step 2: Cache invalidation (after successful DB read)
        _controller.invalidateDoc(state.selectedPond, state.doc);

        // Step 3: Refresh from DB → provider state → Riverpod rebuild
        await loadTodayFeed(state.selectedPond);

        // Step 4: UI update (only after all DB operations complete)
        final updatedStatus = Map<int, String>.from(state.roundFeedStatus);
        updatedStatus[round] = 'completed';
        state = state.copyWith(
          roundFeedStatus: updatedStatus,
          lastFeedTime: DateTime.now(), // for FeedStatusEngine gap check
        );

        // Step 5: Log feeding (only after successful transaction AND DB read AND state update)
        if (qty > 0 && transactionSuccess) {
          await ref.read(feedHistoryProvider.notifier).logFeeding(
                pondId: state.selectedPond,
                doc: state.doc,
                round: round,
                qty: actualDbFeedSaved, // Use ACTUAL DB value, not input qty
                expectedFeed: expectedFeedToday,
              );

          // 🔴 DEBUG: Log successful feed completion with ACTUAL DB value
          // Calculate percentage difference between planned and ACTUAL DB feed
          final difference = plannedQty > 0
              ? ((actualDbFeedSaved - plannedQty) / plannedQty * 100)
              : 0.0;

          FeedDebugLogger.logFeedAction(
            pondId: pondId,
            doc: state.doc,
            round: round,
            status: 'success',
            source: 'user_action',
            feedEntered: actualQty,
            feedSaved: actualDbFeedSaved, // ACTUAL committed DB value ONLY
            calculatedFeed: plannedQty,
            difference: difference,
          );

          AppLogger.info(
              '✅ Feed action logged with actual DB value: ${actualDbFeedSaved.toStringAsFixed(2)}kg');
        }

        // Step 6: Handle tray auto-skip refresh
        if (didSkipAnyTray) {
          ref.invalidate(trayProvider(state.selectedPond));
        }
      } catch (e) {
        // 🔴 DEBUG: Log feed operation failure
        FeedDebugLogger.logFeedError(
          pondId: pondId,
          doc: state.doc,
          round: round,
          operation: 'markFeedDone',
          error: e.toString(),
          context: {
            'actualQty': actualQty,
            'plannedQty': plannedQty,
            'transactionSuccess': transactionSuccess,
          },
        );
        AppLogger.error('Failed to complete feed operation', e);
        rethrow;
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

    // Prevent concurrent tray logging for the same round
    if (!_tryAcquireLock(lockKey)) {
      AppLogger.warn(
          'Tray logging already in progress for round $round in pond $pondId');
      return;
    }

    try {
      final trayLogs = ref.read(trayProvider(state.selectedPond));
      if (trayLogs.isEmpty) return;

      final latest = trayLogs.last;

      // The tray log now directly provides a list of TrayStatus enums.
      final List<TrayStatus> trayStatuses = latest.trays;
      if (trayStatuses.isEmpty) return;

      // Simple tray status aggregation (replaces FeedStateEngine)
      TrayStatus finalStatus;
      if (trayStatuses.isEmpty) {
        finalStatus = TrayStatus.light;
      } else {
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

        // 🔄 CACHE INVALIDATION: Tray update affects smart feed calculations
        // This ensures the controller fetches fresh tray data next load
        _controller.invalidate(pondId);

        // CRITICAL: After tray is logged, SmartFeedEngine updates feed_rounds
        // with new factor adjustments. Reload feed amounts to display new suggestion.
        // Without this, feed_rounds table is updated but UI shows stale data.
        ref.invalidate(trayProvider(pondId));

        // 🔥 FIX: Reload feed data so next feed suggestion shows SmartFeedEngine's adjustment
        // 🔒 FIX #6: Ensure engine runs AFTER DB update with proper await
        await loadTodayFeed(pondId);

        // Update currentFeed in state after reload
        final totalFeed =
            state.roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);
        state = state.copyWith(currentFeed: totalFeed);
      } catch (e) {
        AppLogger.error(
            'Failed to persist tray log for pond $pondId, reverting UI state',
            e);

        // 🔴 CRITICAL: Revert UI state on failure
        state = state.copyWith(
          trayResults: originalTrayResults,
          trayPersistFailed: true,
        );

        // Note: Feed history provider revert would require more complex logic
        // The main UI state revert above is sufficient for most cases
      }
    } catch (e) {
      AppLogger.error('Tray logging failed for pond $pondId round $round', e);
    } finally {
      _releaseLock(lockKey);
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
    StateNotifierProvider<PondDashboardNotifier, PondDashboardState>((ref) {
  return PondDashboardNotifier(ref);
});
