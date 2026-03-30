import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single mortality log entry
class MortalityLog {
  final String pondId;
  final int doc;
  final int count;  // Pieces died today
  final double percentage;  // As % of current population
  final String? notes;
  final DateTime timestamp;

  MortalityLog({
    required this.pondId,
    required this.doc,
    required this.count,
    required this.percentage,
    this.notes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Notifier for managing mortality logs
class MortalityNotifier extends StateNotifier<Map<String, List<MortalityLog>>> {
  MortalityNotifier() : super({});

  /// Log mortality for a pond
  /// Updates pond's seedCount based on deaths
  void logMortality({
    required String pondId,
    required int doc,
    required int count,
    required int currentSeedCount,
    String? notes,
  }) {
    if (count < 0 || count > currentSeedCount) {
      throw Exception("Invalid mortality count: $count for population $currentSeedCount");
    }

    final percentage = (count / currentSeedCount * 100);
    final log = MortalityLog(
      pondId: pondId,
      doc: doc,
      count: count,
      percentage: percentage,
      notes: notes,
    );

    final existing = state[pondId] ?? [];
    state = {
      ...state,
      pondId: [...existing, log],
    };
  }

  /// Get total mortality for a pond
  int getTotalMortality(String pondId) {
    return (state[pondId] ?? []).fold<int>(0, (sum, log) => sum + log.count);
  }

  /// Get today's mortality (current DOC)
  int getTodayMortality(String pondId, int doc) {
    final logs = state[pondId] ?? [];
    final todayLogs = logs.where((log) => log.doc == doc).toList();
    return todayLogs.fold<int>(0, (sum, log) => sum + log.count);
  }

  /// Get mortality percentage trend (last 7 days)
  double getMortalityTrend(String pondId, int currentDoc) {
    final logs = state[pondId] ?? [];
    final recentLogs = logs.where((log) => log.doc > (currentDoc - 7) && log.doc <= currentDoc).toList();
    if (recentLogs.isEmpty) return 0;
    return recentLogs.fold<double>(0, (sum, log) => sum + log.percentage) / recentLogs.length;
  }

  /// Calculate current live population after mortality
  int getCurrentPopulation({
    required int originalSeedCount,
    required String pondId,
  }) {
    final totalDead = getTotalMortality(pondId);
    final current = originalSeedCount - totalDead;
    return current > 0 ? current : 0;
  }
}

/// Riverpod provider for mortality tracking
final mortalityProvider = StateNotifierProvider<MortalityNotifier, Map<String, List<MortalityLog>>>(
  (ref) => MortalityNotifier(),
);

/// Helper provider: Get current live population for a pond
/// Usage: ref.watch(currentPopulationProvider(pondId))
final currentPopulationProvider = Provider.family<int, (String pondId, int originalSeedCount)>((ref, params) {
  final (pondId, originalSeedCount) = params;
  final mortalities = ref.watch(mortalityProvider);
  final totalDead = mortalities[pondId]?.fold<int>(0, (sum, log) => sum + log.count) ?? 0;
  final current = originalSeedCount - totalDead;
  return current > 0 ? current : 0;
});
