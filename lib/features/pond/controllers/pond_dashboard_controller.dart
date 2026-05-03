import 'dart:async';
import '../../../core/utils/logger.dart';
import '../../../core/services/pond_service.dart';
import '../../../core/services/feed/feed_service.dart';
import '../../../systems/planning/feed_plan_generator.dart';
import '../../../systems/planning/feed_plan_constants.dart';
import '../../../systems/feed/feed_models.dart';
import '../../../systems/feed/master_feed_engine.dart';
import '../../../features/feed/enums/feed_stage.dart';

/// ===========================================
/// POND VIEW STATE - Immutable state snapshot
/// ===========================================
class PondViewState {
  final String pondId;
  final int doc;
  final OrchestratorResult? feedResult;
  final Map<int, double> roundFeedAmounts;
  final Map<int, String> roundFeedStatus;
  final Map<int, String> roundToFeedId;
  final bool isLoading;
  final String? error;
  final bool feedAutoRecovered;

  const PondViewState({
    required this.pondId,
    required this.doc,
    this.feedResult,
    this.roundFeedAmounts = const {},
    this.roundFeedStatus = const {},
    this.roundToFeedId = const {},
    this.isLoading = false,
    this.error,
    this.feedAutoRecovered = false,
  });

  double get totalFeed =>
      roundFeedAmounts.values.fold(0.0, (sum, v) => sum + v);
  double get finalFeed {
    if (feedResult == null) {
      throw StateError('Feed result not available - call loadPondData() first');
    }
    return feedResult!.finalFeed;
  }

  bool get isStopFeeding => feedResult?.decision.action == 'Stop Feeding';
}

/// ===========================================
/// POND DASHBOARD CONTROLLER
/// Single source of truth for pond dashboard
/// ===========================================
///
/// FLOW:
///   UI → Controller.load(pondId) → Engine → State
///                 ↓
///           Service (DB only)
///
/// RULES:
/// - UI NEVER calls service directly
/// - UI NEVER calls engine directly
/// - ONLY controller orchestrates
class PondDashboardController {
  final FeedService _feedService;
  final PondService _pondService;

  PondDashboardController({
    FeedService? feedService,
    PondService? pondService,
  })  : _feedService = feedService ?? FeedService(),
        _pondService = pondService ?? PondService();

  /// Cached view states keyed by 'pondId:doc' to prevent duplicate data loading
  /// within the same dashboard refresh cycle.
  final Map<String, PondViewState> _viewStateCache = {};

  /// Cached orchestrator results keyed by 'pondId:doc' for feed computation caching
  final Map<String, OrchestratorResult> _orchestratorCache = {};

  /// Tracks which pondId:doc combinations are currently loading to prevent double calls
  final Set<String> _loadingKeys = {};

  String _cacheKey(String pondId, int doc) => '$pondId:$doc';

  /// ===========================================
  /// SINGLE ENTRY POINT: Load pond state
  /// ===========================================
  ///
  /// This is the ONLY method UI should call to load pond data.
  /// Guarantees:
  /// - Feed engine runs exactly ONCE per unique pond+doc load
  /// - No flickering from multiple competing calculations
  /// - No double calls via _loadingPonds guard
  /// - Stable feed values across refresh
  Future<PondViewState> load(String pondId, {int? knownDoc}) async {
    if (pondId.isEmpty) {
      return const PondViewState(
        pondId: '',
        doc: 0,
        error: 'Invalid pond ID',
      );
    }

    int doc;
    late String loadKey;

    try {
      // Fetch pond data
      final pond = await _pondService.getPondById(pondId);
      if (pond == null) {
        return PondViewState(
          pondId: pondId,
          doc: knownDoc ?? 0,
          error: 'Pond not found',
        );
      }

      // Calculate DOC
      doc = knownDoc ?? _calculateDoc(pond.stockingDate);
      loadKey = _cacheKey(pondId, doc);

      // DOUBLE CALL PROTECTION: Prevent concurrent loads for same pond+doc
      if (_loadingKeys.contains(loadKey)) {
        AppLogger.info(
            'Controller: Load already in progress for pond=$pondId doc=$doc, skipping');
        // Return cached state if available, otherwise loading state
        final existing = _viewStateCache[loadKey];
        if (existing != null) return existing;
        return PondViewState(
          pondId: pondId,
          doc: doc,
          isLoading: true,
        );
      }

      _loadingKeys.add(loadKey);

      final cacheKey = loadKey;

      // Check cache first (but not if we're force reloading)
      final cached = _viewStateCache[cacheKey];
      if (cached != null && !cached.isLoading) {
        AppLogger.info(
            'Controller: Using cached state for pond=$pondId doc=$doc');
        _loadingKeys.remove(loadKey);
        return cached;
      }

      // Load today's feed rounds from DB
      final feedData = await _loadFeedRounds(pondId, doc, null);

      // Run feed engine using MasterFeedEngine (single source of truth)
      OrchestratorResult? feedResult;
      feedResult = await _computeFeedViaEngine(pondId, doc, pond);
      // Inject smart recommendation for pending rounds (only if smart mode)
      if (doc >= 31) {
        _injectSmartFeed(pondId, feedData, feedResult, doc);
      }

      // Check for auto-recovery (blind mode schedule regeneration)
      // Only run if DB truly empty (not just amounts map empty)
      bool didAutoRecover = false;
      if (feedData.amounts.isEmpty && doc < 31) {
        // Verify DB is truly empty by checking feed rounds directly
        final dbRounds = await _feedService.getFeedRounds(pondId, doc);
        if (dbRounds.isEmpty) {
          didAutoRecover = await _regenerateBlindSchedule(
              pondId, doc, pond.seedCount, pond.area, pond.stockingDate);
          if (didAutoRecover) {
            final recovered = await _loadFeedRounds(pondId, doc, null);
            feedData.amounts.addAll(recovered.amounts);
            feedData.statuses.addAll(recovered.statuses);
            feedData.ids.addAll(recovered.ids);
          }
        }
      }

      // Create and cache the full view state
      final viewState = PondViewState(
        pondId: pondId,
        doc: doc,
        feedResult: feedResult,
        roundFeedAmounts: feedData.amounts,
        roundFeedStatus: feedData.statuses,
        roundToFeedId: feedData.ids,
        isLoading: false,
        feedAutoRecovered: didAutoRecover,
      );

      _viewStateCache[cacheKey] = viewState;
      AppLogger.info('Controller: Cached view state for pond=$pondId doc=$doc');

      return viewState;
    } catch (e) {
      AppLogger.error('Controller.load failed for pond=$pondId', e);
      return PondViewState(
        pondId: pondId,
        doc: knownDoc ?? 0,
        error: 'Failed to load pond data: $e',
      );
    } finally {
      // Always remove from loading set to allow future loads
      _loadingKeys.remove(loadKey);
    }
  }

  /// ===========================================
  /// FEED COMPUTATION via MasterFeedEngine (single source of truth)
  /// ===========================================
  Future<OrchestratorResult> _computeFeedViaEngine(
    String pondId,
    int doc,
    dynamic _,
  ) async {
    final cached = _orchestratorCache[_cacheKey(pondId, doc)];
    if (cached != null) {
      AppLogger.info(
          'Controller: Using cached orchestrator result for pond=$pondId doc=$doc');
      return cached;
    }

    try {
      final orchestratorResult = await MasterFeedEngine.orchestrateForPond(
        pondId,
      );

      // Apply fallback: if feed <= 0, use previousFeed or safe default
      if (orchestratorResult.finalFeed <= 0 &&
          !orchestratorResult.correction.isCriticalStop) {
        AppLogger.warn(
            'Controller: Feed engine returned zero/negative feed for pond=$pondId doc=$doc, applying fallback');
        final previousFeed = await _getPreviousFeedAmount(pondId, doc);
        final safeFeed = previousFeed > 0 ? previousFeed : 1.0; // Safe default

        return _createFallbackWithFeed(pondId, doc, safeFeed,
            'Used previous/safe feed due to zero result');
      }

      _orchestratorCache[_cacheKey(pondId, doc)] = orchestratorResult;
      AppLogger.info(
          'Controller: Computed feed via MasterFeedEngine for pond=$pondId doc=$doc final=${orchestratorResult.finalFeed.toStringAsFixed(3)}kg');
      return orchestratorResult;
    } catch (e) {
      AppLogger.error(
          'Controller: MasterFeedEngine error for pond=$pondId doc=$doc', e);
      return _createSafeFallbackResult(pondId, doc, 'Feed engine error: $e');
    }
  }

  /// Get previous feed amount from database for fallback
  Future<double> _getPreviousFeedAmount(String pondId, int doc) async {
    try {
      final feedRounds = await _feedService.getFeedRounds(pondId, doc - 1);
      if (feedRounds.isNotEmpty) {
        final total = feedRounds.fold<double>(
          0.0,
          (sum, round) =>
              sum + ((round['planned_amount'] as num?)?.toDouble() ?? 0.0),
        );
        return total;
      }
    } catch (e) {
      AppLogger.warn(
          'Controller: Failed to get previous feed for fallback: $e');
    }
    return 0.0;
  }

  /// Create fallback result with specific feed amount
  OrchestratorResult _createFallbackWithFeed(
    String pondId,
    int doc,
    double feedAmount,
    String reason,
  ) {
    final correction = CorrectionResult(
      baseFeed: feedAmount,
      trayFactor: 1.0,
      finalFeed: feedAmount,
      safetyStatus: 'fallback',
      reasons: [reason],
      alerts: ['⚠️ Using fallback feed amount'],
      isCriticalStop: false,
      isSmartApplied: false,
    );

    final decision = FeedDecision(
      action: 'Maintain Feeding',
      deltaKg: 0.0,
      reason: reason,
      recommendations: ['Feed $feedAmount kg'],
      decisionTrace: ['Fallback applied'],
    );

    final recommendation = FeedRecommendation(
      nextFeedKg: feedAmount,
      nextFeedTime: DateTime.now(),
      instruction: 'Feed $feedAmount kg',
    );

    final intelligence = IntelligenceResult(
      expectedFeed: feedAmount,
      status: FeedStatus.onTrack,
    );

    final debugInfo = FeedDebugInfo(
      doc: doc,
      baseFeedPer100k: feedAmount,
      adjustedFeed: feedAmount,
      minFeed: feedAmount,
      maxFeed: feedAmount,
      isBaseFeedClamped: false,
      wasInputClamped: false,
      baseFeed: feedAmount,
      trayFactor: 1.0,
      smartFactor: 1.0,
      combinedFactor: 1.0,
      rawCombinedFactor: 1.0,
      fcr: 1.5,
      finalFeed: feedAmount,
      isSmartApplied: false,
      wasClamped: false,
      hasSampling: false,
      feedStage: 'fallback',
    );

    return OrchestratorResult(
      baseFeed: feedAmount,
      feedStage: FeedStage.blind,
      intelligence: intelligence,
      correction: correction,
      decision: decision,
      recommendation: recommendation,
      engineVersion: 'MasterFeedEngine-fallback',
      debugInfo: debugInfo,
    );
  }

  /// ===========================================
  /// FEED ROUNDS LOADING
  /// ===========================================
  Future<
      ({
        Map<int, double> amounts,
        Map<int, String> statuses,
        Map<int, String> ids
      })> _loadFeedRounds(
    String pondId,
    int doc,
    OrchestratorResult? feedResult,
  ) async {
    final amounts = <int, double>{};
    final statuses = <int, String>{};
    final ids = <int, String>{};

    try {
      final rows = await _feedService.getFeedRounds(pondId, doc);

      for (final row in rows) {
        final round = row['round'] as int?;
        if (round == null) {
          AppLogger.error('Missing round in feed row for pond $pondId');
          continue;
        }

        // Validate required fields
        if (row['planned_amount'] == null) {
          AppLogger.error(
              'Missing planned_amount for round $round in pond $pondId');
          continue; // Skip invalid row
        }
        if (row['status'] == null) {
          AppLogger.error('Missing status for round $round in pond $pondId');
          continue; // Skip invalid row
        }

        final amount = (row['planned_amount'] as num?)?.toDouble() ?? 0.0;
        final status = row['status'] as String? ?? 'pending';
        final id = row['id'] as String? ?? '';

        // Validate amount
        if (amount < 0) {
          AppLogger.error(
              'Invalid negative amount $amount for round $round in pond $pondId');
          continue; // Skip invalid row
        }

        amounts[round] = amount;
        statuses[round] = status;
        ids[round] = id;
      }
    } catch (e) {
      AppLogger.warn(
          'Failed to load feed rounds for pond=$pondId doc=$doc: $e');
    }

    return (amounts: amounts, statuses: statuses, ids: ids);
  }

  /// ===========================================
  /// SMART FEED INJECTION
  /// ===========================================
  void _injectSmartFeed(
    String pondId,
    ({
      Map<int, double> amounts,
      Map<int, String> statuses,
      Map<int, String> ids
    }) feedData,
    OrchestratorResult result,
    int doc,
  ) {
    final config = getFeedConfig(doc);
    final safeFinalFeed =
        (result.finalFeed <= 0 && !result.correction.isCriticalStop)
            ? result.baseFeed
            : result.finalFeed;

    // Inject amount for the NEXT pending round only
    final totalRounds = config.splits.length;
    for (int r = 1; r <= totalRounds; r++) {
      final alreadyDone = feedData.statuses[r] == 'completed';
      final isActive = r - 1 < config.splits.length && config.splits[r - 1] > 0;

      if (!alreadyDone && isActive) {
        feedData.amounts[r] = double.parse(
          (safeFinalFeed * config.splits[r - 1]).toStringAsFixed(3),
        );
        feedData.statuses[r] ??= 'pending';
        break; // Only the immediate next round
      }
    }
  }

  /// ===========================================
  /// BLIND SCHEDULE REGENERATION
  /// ===========================================
  Future<bool> _regenerateBlindSchedule(
    String pondId,
    int doc,
    int seedCount,
    double pondArea,
    DateTime stockingDate,
  ) async {
    try {
      AppLogger.info(
          'Controller: Regenerating blind schedule for pond=$pondId DOC=$doc');

      await generateFeedPlan(
        pondId: pondId,
        startDoc: 1,
        endDoc: doc.clamp(1, 29),
        stockingCount: seedCount,
        pondArea: pondArea,
        stockingDate: stockingDate,
      );

      AppLogger.info(
          'Controller: Auto-recovered feed schedule for pond=$pondId');
      return true;
    } catch (e) {
      AppLogger.error(
          'Controller: Schedule regeneration failed for pond=$pondId', e);
      return false;
    }
  }

  /// ===========================================
  /// CACHE MANAGEMENT
  /// ===========================================

  /// Returns a cached orchestrator result without re-running the engine.
  /// Null if no cached entry exists for this pond+doc.
  OrchestratorResult? cachedResult(String pondId, int doc) {
    return _orchestratorCache[_cacheKey(pondId, doc)];
  }

  /// Invalidates all cached data for a pond.
  /// Call this after ANY mutation: tray update, sampling, manual feed edit, etc.
  void invalidate(String pondId) {
    _viewStateCache.removeWhere((key, _) => key.startsWith('$pondId:'));
    _orchestratorCache.removeWhere((key, _) => key.startsWith('$pondId:'));
    AppLogger.info('Controller: Invalidated cache for pond=$pondId');
  }

  /// Invalidates a specific DOC for a pond (more targeted).
  void invalidateDoc(String pondId, int doc) {
    final key = _cacheKey(pondId, doc);
    _viewStateCache.remove(key);
    _orchestratorCache.remove(key);
    AppLogger.info('Controller: Invalidated cache for pond=$pondId doc=$doc');
  }

  void clearCache() {
    _viewStateCache.clear();
    _orchestratorCache.clear();
    _loadingKeys.clear();
    AppLogger.info('Controller: All caches cleared');
  }

  /// ===========================================
  /// UTILITY
  /// ===========================================
  int _calculateDoc(DateTime stockingDate) {
    final now = DateTime.now();
    final start =
        DateTime(stockingDate.year, stockingDate.month, stockingDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(start).inDays + 1;
  }

  /// Create a safe fallback result when feed computation fails
  OrchestratorResult _createSafeFallbackResult(
      String pondId, int doc, String reason) {
    // Use the stopFeed constructor with minimal parameters
    return OrchestratorResult.stopFeed(
      reason: reason,
      engineVersion: 'v1_fallback',
      doc: doc,
    );
  }
}

/// ===========================================
/// CONTROLLER PROVIDER
/// ===========================================
///
/// Singleton controller instance for the app.
final pondDashboardController = PondDashboardController();
