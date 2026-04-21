import '../../../systems/feed/master_feed_engine.dart';
import '../../../features/feed/models/orchestrator_result.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/services/pond_service.dart';
import '../../../systems/planning/feed_plan_generator.dart';
import '../../../systems/planning/feed_plan_constants.dart';

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
  double get finalFeed => feedResult?.finalFeed ?? 0.0;
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

  /// Tracks which pondIds are currently loading to prevent double calls
  final Set<String> _loadingPonds = {};

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

    // DOUBLE CALL PROTECTION: Prevent concurrent loads for same pond
    if (_loadingPonds.contains(pondId)) {
      AppLogger.info(
          'Controller: Load already in progress for pond=$pondId, skipping');
      // Return cached state if available, otherwise loading state
      final existing = _viewStateCache[_cacheKey(pondId, knownDoc ?? 0)];
      if (existing != null) return existing;
      return PondViewState(
        pondId: pondId,
        doc: knownDoc ?? 0,
        isLoading: true,
      );
    }

    _loadingPonds.add(pondId);

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
      final doc = knownDoc ?? _calculateDoc(pond.stockingDate);
      final cacheKey = _cacheKey(pondId, doc);

      // Check cache first (but not if we're force reloading)
      final cached = _viewStateCache[cacheKey];
      if (cached != null && !cached.isLoading) {
        AppLogger.info(
            'Controller: Using cached state for pond=$pondId doc=$doc');
        _loadingPonds.remove(pondId);
        return cached;
      }

      // Load today's feed rounds from DB
      final feedData = await _loadFeedRounds(pondId, doc, null);

      // Run feed engine (smart mode only for DOC >= 31)
      OrchestratorResult? feedResult;
      if (doc >= 31) {
        feedResult = await _computeFeed(pondId, doc);
        // Inject smart recommendation for pending rounds
        _injectSmartFeed(feedData, feedResult, doc);
      }

      // Check for auto-recovery (blind mode schedule regeneration)
      bool didAutoRecover = false;
      if (feedData.amounts.isEmpty && doc < 31) {
        didAutoRecover = await _regenerateBlindSchedule(
            pondId, doc, pond.seedCount, pond.area, pond.stockingDate);
        if (didAutoRecover) {
          final recovered = await _loadFeedRounds(pondId, doc, null);
          feedData.amounts.addAll(recovered.amounts);
          feedData.statuses.addAll(recovered.statuses);
          feedData.ids.addAll(recovered.ids);
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
      _loadingPonds.remove(pondId);
    }
  }

  /// ===========================================
  /// FEED COMPUTATION (single call per pond)
  /// ===========================================
  Future<OrchestratorResult> _computeFeed(String pondId, int doc) async {
    final cached = _orchestratorCache[_cacheKey(pondId, doc)];
    if (cached != null) {
      AppLogger.info(
          'Controller: Using cached orchestrator result for pond=$pondId doc=$doc');
      return cached;
    }

    try {
      final result = await MasterFeedEngine.orchestrateForPond(pondId);
      _orchestratorCache[_cacheKey(pondId, doc)] = result;
      AppLogger.info(
          'Controller: Computed feed for pond=$pondId doc=$doc final=${result.finalFeed.toStringAsFixed(3)}kg');
      return result;
    } catch (e) {
      AppLogger.error(
          'Controller: Feed computation failed for pond=$pondId', e);
      rethrow;
    }
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
        final round = row['round'] as int;
        final amount = (row['planned_amount'] as num?)?.toDouble() ?? 0.0;
        final status = row['status'] as String? ?? 'pending';
        final id = row['id'] as String? ?? '';

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
    for (int r = 1; r <= 4; r++) {
      final alreadyDone = feedData.statuses[r] == 'completed';
      final isActive = r - 1 < config.splits.length && config.splits[r - 1] > 0;

      if (!alreadyDone && isActive) {
        if ((feedData.amounts[r] ?? 0.0) == 0.0) {
          feedData.amounts[r] = double.parse(
            (safeFinalFeed * config.splits[r - 1]).toStringAsFixed(3),
          );
        }
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
    _loadingPonds.clear();
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
}

/// ===========================================
/// CONTROLLER PROVIDER
/// ===========================================
///
/// Singleton controller instance for the app.
final pondDashboardController = PondDashboardController();
