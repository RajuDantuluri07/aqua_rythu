import 'package:flutter_riverpod/flutter_riverpod.dart';

class GrowthSample {
  final String id;
  final String pondId;
  final DateTime date;
  final int doc;
  
  final double sampleWeightKg;
  final int sampleCount;
  
  final double countSize; // Count per kg
  final double abw;       // Average Body Weight in grams

  GrowthSample({
    required this.id,
    required this.pondId,
    required this.date,
    required this.doc,
    required this.sampleWeightKg,
    required this.sampleCount,
    required this.countSize,
    required this.abw,
  });

  /// Factory to calculate from inputs
  factory GrowthSample.fromInput({
    required String pondId,
    required int doc,
    required double weightKg,
    required int count,
  }) {
    final countSize = count / weightKg;
    final abw = (weightKg * 1000) / count;
    
    return GrowthSample(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pondId: pondId,
      date: DateTime.now(),
      doc: doc,
      sampleWeightKg: weightKg,
      sampleCount: count,
      countSize: countSize,
      abw: abw,
    );
  }
}

class GrowthState {
  final List<GrowthSample> logs;

  GrowthState({
    this.logs = const [],
  });

  GrowthSample? get lastSample => logs.isNotEmpty ? logs.first : null;

  GrowthState copyWith({
    List<GrowthSample>? logs,
  }) {
    return GrowthState(
      logs: logs ?? this.logs,
    );
  }
}

class GrowthNotifier extends StateNotifier<GrowthState> {
  final String pondId;
  GrowthNotifier(this.pondId) : super(GrowthState());

  /// 💾 Add New Sample
  void addSample({required double weightKg, required int count, required int doc}) {
    final newSample = GrowthSample.fromInput(
      pondId: pondId,
      doc: doc,
      weightKg: weightKg,
      count: count,
    );

    state = state.copyWith(
      logs: [newSample, ...state.logs],
    );
  }
}

/// 🌿 GLOBAL GROWTH PROVIDER
final growthProvider =
    StateNotifierProvider.family<GrowthNotifier, GrowthState, String>((ref, pondId) {
  return GrowthNotifier(pondId);
});