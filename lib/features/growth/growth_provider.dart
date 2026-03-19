import 'package:flutter_riverpod/flutter_riverpod.dart';

class SamplingLog {
  final DateTime date;
  final int doc;
  final double avgWeight;
  final int count;

  SamplingLog({
    required this.date,
    required this.doc,
    required this.avgWeight,
    required this.count,
  });
}

class GrowthState {
  final double avgWeight; // grams
  final int totalCount;   // estimated total survival
  final double biomass;   // kg
  final List<SamplingLog> logs;

  GrowthState({
    this.avgWeight = 15.0, // Default matching temp data
    this.totalCount = 100000,
    this.logs = const [],
  }) : biomass = (avgWeight * totalCount) / 1000;

  GrowthState copyWith({
    double? avgWeight,
    int? totalCount,
    List<SamplingLog>? logs,
  }) {
    return GrowthState(
      avgWeight: avgWeight ?? this.avgWeight,
      totalCount: totalCount ?? this.totalCount,
      logs: logs ?? this.logs,
    );
  }
}

class GrowthNotifier extends StateNotifier<GrowthState> {
  GrowthNotifier() : super(GrowthState());

  /// Update stats from Sampling or Mortality checks
  void updateStats({double? avgWeight, int? totalCount, required int doc}) {
    final newLog = SamplingLog(
      date: DateTime.now(),
      doc: doc,
      avgWeight: avgWeight ?? state.avgWeight,
      count: totalCount ?? state.totalCount,
    );

    state = state.copyWith(
      avgWeight: avgWeight,
      totalCount: totalCount,
      logs: [newLog, ...state.logs],
    );
  }
}

/// 🌿 GLOBAL GROWTH PROVIDER
final growthProvider =
    StateNotifierProvider.family<GrowthNotifier, GrowthState, String>((ref, pondId) {
  return GrowthNotifier();
});