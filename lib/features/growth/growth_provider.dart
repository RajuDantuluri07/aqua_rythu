import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_plan_provider.dart';
import '../farm/farm_provider.dart';

class SamplingLog {
  final String id;
  final String pondId;
  final DateTime date;
  final int doc;
  final int sampleCount;
  final double totalWeight; // Grams

  SamplingLog({
    required this.id,
    required this.pondId,
    required this.date,
    required this.doc,
    required this.sampleCount,
    required this.totalWeight,
  });

  // ABW = Total Weight / Sample Count
  double get averageBodyWeight => sampleCount > 0 ? totalWeight / sampleCount : 0;
}

class GrowthNotifier extends StateNotifier<List<SamplingLog>> {
  final Ref ref;
  final String pondId;

  GrowthNotifier(this.ref, this.pondId) : super([]);

  /// 📏 ADD SAMPLING LOG
  /// Also triggers feed plan recalculation (PRD 3.6)
  void addSampling({
    required int doc,
    required int sampleCount,
    required double totalWeight,
  }) {
    final newLog = SamplingLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pondId: pondId,
      date: DateTime.now(),
      doc: doc,
      sampleCount: sampleCount,
      totalWeight: totalWeight,
    );

    state = [newLog, ...state];

    // 🔄 Update Feed Plan based on new ABW
    _recalculateFeedPlan(newLog);
  }

  void _recalculateFeedPlan(SamplingLog log) {
    final farmState = ref.read(farmProvider);
    int seedCount = 100000; // Fallback

    // Find the seed count for this pond to ensure biomass calculation is accurate
    for (final farm in farmState.farms) {
      try {
        final pond = farm.ponds.firstWhere((p) => p.id == pondId);
        seedCount = pond.seedCount;
        break;
      } catch (_) {
        // Pond not found in this farm, continue
      }
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