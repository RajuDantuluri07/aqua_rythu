import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_plan_provider.dart';
import '../farm/farm_provider.dart';

class SamplingLog {
  final String id;
  final String pondId;
  final DateTime date;
  final int doc;
  final double weightKg;
  final int countGroups;
  final int piecesPerGroup;
  final int totalPieces;
  final double averageBodyWeight;

  SamplingLog({
    required this.id,
    required this.pondId,
    required this.date,
    required this.doc,
    required this.weightKg,
    required this.countGroups,
    required this.piecesPerGroup,
    required this.totalPieces,
    required this.averageBodyWeight,
  });

  // For backward compatibility with old data
  factory SamplingLog.fromOldData({
    required String id,
    required String pondId,
    required DateTime date,
    required int doc,
    required int sampleCount,
    required double totalWeightGrams,
  }) {
    final weightKg = totalWeightGrams / 1000;
    final averageBodyWeight = sampleCount > 0 ? totalWeightGrams / sampleCount : 0.0;
    
    return SamplingLog(
      id: id,
      pondId: pondId,
      date: date,
      doc: doc,
      weightKg: weightKg,
      countGroups: sampleCount,
      piecesPerGroup: 1,
      totalPieces: sampleCount,
      averageBodyWeight: averageBodyWeight.toDouble(),
    );
  }
}

class GrowthNotifier extends StateNotifier<List<SamplingLog>> {
  final Ref ref;
  final String pondId;

  GrowthNotifier(this.ref, this.pondId) : super([]);

  /// 📏 ADD SAMPLING LOG
  void addLog({
    required int doc,
    required double weightKg,
    required int countGroups,
    required int piecesPerGroup,
  }) {
    final totalPieces = countGroups * piecesPerGroup;
    final averageBodyWeight = totalPieces > 0 ? (weightKg * 1000) / totalPieces : 0.0;

    final newLog = SamplingLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pondId: pondId,
      date: DateTime.now(),
      doc: doc,
      weightKg: weightKg,
      countGroups: countGroups,
      piecesPerGroup: piecesPerGroup,
      totalPieces: totalPieces,
      averageBodyWeight: averageBodyWeight,
    );

    state = [newLog, ...state];

    // 🔄 Update Feed Plan based on new ABW
    _recalculateFeedPlan(newLog);
  }

  void _recalculateFeedPlan(SamplingLog log) {
    final farmState = ref.read(farmProvider);
    int seedCount = 100000;

    for (final farm in farmState.farms) {
      try {
        final pond = farm.ponds.firstWhere((p) => p.id == pondId);
        seedCount = pond.seedCount;
        break;
      } catch (_) {}
    }

    ref.read(feedPlanProvider.notifier).recalculatePlan(
          pondId: pondId,
          currentDoc: log.doc,
          sampledAbw: log.averageBodyWeight,
          seedCount: seedCount,
        );
  }
}

final growthProvider =
    StateNotifierProvider.family<GrowthNotifier, List<SamplingLog>, String>(
        (ref, pondId) {
  return GrowthNotifier(ref, pondId);
});