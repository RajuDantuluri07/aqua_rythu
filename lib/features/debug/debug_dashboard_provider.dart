import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/engines/master_feed_engine.dart';
import '../../core/engines/feed_intelligence_engine.dart';
import '../../core/engines/feed_orchestrator.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/doc_utils.dart';

class DebugDashboardState {
  final bool isLoading;
  final String? error;

  // Pond context
  final String pondName;
  final int doc;
  final String stockingType;
  final int density;

  // Latest tray leftover from DB (null = none)
  final double? latestLeftover;

  // Simulated leftover (set by user via slider — overrides latestLeftover)
  final double? simulatedLeftover;

  // Stage 1: Base feed debug data
  final FeedDebugData? debugData;

  // Stage 2: Intelligence result
  final IntelligenceResult? intelligence;

  // Stage 3: Full orchestrator result (factors + final feed)
  final OrchestratorResult? orchestratorResult;

  const DebugDashboardState({
    this.isLoading = false,
    this.error,
    this.pondName = '',
    this.doc = 1,
    this.stockingType = 'nursery',
    this.density = 100000,
    this.latestLeftover,
    this.simulatedLeftover,
    this.debugData,
    this.intelligence,
    this.orchestratorResult,
  });

  /// The leftover used for the current calculation.
  double? get activeLeftover => simulatedLeftover ?? latestLeftover;

  DebugDashboardState copyWith({
    bool? isLoading,
    String? error,
    String? pondName,
    int? doc,
    String? stockingType,
    int? density,
    double? latestLeftover,
    double? simulatedLeftover,
    bool clearSimulated = false,
    FeedDebugData? debugData,
    IntelligenceResult? intelligence,
    OrchestratorResult? orchestratorResult,
  }) {
    return DebugDashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      pondName: pondName ?? this.pondName,
      doc: doc ?? this.doc,
      stockingType: stockingType ?? this.stockingType,
      density: density ?? this.density,
      latestLeftover: latestLeftover ?? this.latestLeftover,
      simulatedLeftover:
          clearSimulated ? null : (simulatedLeftover ?? this.simulatedLeftover),
      debugData: debugData ?? this.debugData,
      intelligence: intelligence ?? this.intelligence,
      orchestratorResult: orchestratorResult ?? this.orchestratorResult,
    );
  }
}

class DebugDashboardNotifier extends StateNotifier<DebugDashboardState> {
  final _supabase = Supabase.instance.client;
  final String pondId;

  DebugDashboardNotifier(this.pondId) : super(const DebugDashboardState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _fetchPond(),
        _fetchLatestLeftover(),
      ]);

      final pond = results[0] as Map<String, dynamic>?;
      final leftover = results[1] as double?;

      if (pond == null) {
        state = state.copyWith(isLoading: false, error: 'Pond not found');
        return;
      }

      final stockingDate = DateTime.parse(pond['stocking_date'] as String);
      final doc = calculateDocFromStockingDate(stockingDate);
      final stockingType = (pond['stocking_type'] as String?) ?? 'nursery';
      final density = (pond['seed_count'] as int?) ?? 100000;
      final pondName = (pond['name'] as String?) ?? pondId;

      final debugData = MasterFeedEngine.computeWithDebug(
        doc: doc,
        stockingType: stockingType,
        density: density,
        leftoverPercent: leftover,
      );

      // Full pipeline via orchestrator
      final orchestratorResult = await FeedOrchestrator.computeForPond(pondId);
      final intelligence = orchestratorResult.intelligence;

      state = state.copyWith(
        isLoading: false,
        pondName: pondName,
        doc: doc,
        stockingType: stockingType,
        density: density,
        latestLeftover: leftover,
        debugData: debugData,
        intelligence: intelligence,
        orchestratorResult: orchestratorResult,
        clearSimulated: true,
      );
    } catch (e) {
      AppLogger.error('DebugDashboardNotifier.load failed', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Re-runs base engine with the current pond context + active leftover.
  void recalculate() {
    final debugData = MasterFeedEngine.computeWithDebug(
      doc: state.doc,
      stockingType: state.stockingType,
      density: state.density,
      leftoverPercent: state.activeLeftover,
    );

    // Recompute intelligence from the new base feed
    final intelligence = FeedIntelligenceEngine.compute(
      expectedFeed: debugData.finalFeed,
      actualFeedYesterday: state.orchestratorResult?.intelligence.actualFeed,
    );

    state = state.copyWith(
      debugData: debugData,
      intelligence: intelligence,
    );
  }

  /// Simulate what feed would be at a given leftover %.
  void simulateTray(double leftoverPercent) {
    final debugData = MasterFeedEngine.computeWithDebug(
      doc: state.doc,
      stockingType: state.stockingType,
      density: state.density,
      leftoverPercent: leftoverPercent,
    );

    final intelligence = FeedIntelligenceEngine.compute(
      expectedFeed: debugData.finalFeed,
      actualFeedYesterday: state.orchestratorResult?.intelligence.actualFeed,
    );

    state = state.copyWith(
      simulatedLeftover: leftoverPercent,
      debugData: debugData,
      intelligence: intelligence,
    );
  }

  /// Clears simulation and reverts to real tray data.
  void clearSimulation() {
    final debugData = MasterFeedEngine.computeWithDebug(
      doc: state.doc,
      stockingType: state.stockingType,
      density: state.density,
      leftoverPercent: state.latestLeftover,
    );

    final intelligence = FeedIntelligenceEngine.compute(
      expectedFeed: debugData.finalFeed,
      actualFeedYesterday: state.orchestratorResult?.intelligence.actualFeed,
    );

    state = state.copyWith(
      clearSimulated: true,
      debugData: debugData,
      intelligence: intelligence,
    );
  }

  Future<Map<String, dynamic>?> _fetchPond() async {
    return await _supabase
        .from('ponds')
        .select('name, seed_count, stocking_date, stocking_type')
        .eq('id', pondId)
        .maybeSingle();
  }

  Future<double?> _fetchLatestLeftover() async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String()
          .split('T')[0];
      final rows = await _supabase
          .from('tray_logs')
          .select('tray_statuses')
          .eq('pond_id', pondId)
          .gte('date', since)
          .order('date', ascending: false)
          .limit(3);

      if (rows.isEmpty) return null;

      double total = 0;
      for (final row in rows) {
        final statuses =
            List<String>.from(row['tray_statuses'] as List? ?? []);
        total += _statusesToPct(statuses);
      }
      return total / rows.length;
    } catch (_) {
      return null;
    }
  }

  double _statusesToPct(List<String> statuses) {
    if (statuses.isEmpty) return 0.0;
    int full = 0, empty = 0;
    for (final s in statuses) {
      if (s == 'full') full++;
      if (s == 'empty') empty++;
    }
    final majority = statuses.length / 2;
    if (full > majority) return 70.0;
    if (empty > majority) return 0.0;
    return 30.0;
  }
}

final debugDashboardProvider = StateNotifierProvider.family<
    DebugDashboardNotifier, DebugDashboardState, String>(
  (ref, pondId) => DebugDashboardNotifier(pondId),
);
