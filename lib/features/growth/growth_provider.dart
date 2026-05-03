import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sampling_log.dart';
import '../../core/services/subscription/subscription_gate.dart';
import '../../core/utils/logger.dart';

class GrowthNotifier extends StateNotifier<List<SamplingLog>> {
  final String pondId;
  final _supabase = Supabase.instance.client; // used by _loadLogs

  GrowthNotifier(this.pondId) : super([]) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    // ✅ Guard: Skip if pondId is empty (prevents invalid UUID errors)
    if (pondId.isEmpty) {
      state = [];
      return;
    }

    try {
      final data = await _supabase
          .from('sampling_logs')
          .select()
          .eq('pond_id', pondId)
          .order('created_at', ascending: false)
          .limit(50);

      final logs = (data as List).map((row) => SamplingLog(
        doc: row['doc'] ?? 1,
        abw: (row['avg_weight'] as num?)?.toDouble() ?? 0,
        date: DateTime.parse(row['created_at']),
        totalPieces: row['count'] ?? 0,
      )).toList();

      // PRO gate: growth intelligence (full ABW history, trend analysis) is a
      // paid feature (FeatureIds.growthIntelligence). FREE users only see the
      // most recent sample — enough to know "you weighed shrimp", not enough
      // to derive growth curves, FCR signals, or rate-of-gain insights.
      state = SubscriptionGate.isPro ? logs : logs.take(1).toList();
    } catch (e) {
      AppLogger.error('Failed to load sampling logs', e);
    }
  }

  void addLog(SamplingLog log) {
    // In-memory only — DB persistence is owned by SamplingService.addSampling()
    // which also updates ponds.current_abw and ponds.latest_sample_date.
    state = [log, ...state];
  }

  void clearLogs() {
    state = [];
  }
}

final growthProvider =
    StateNotifierProvider.family<GrowthNotifier, List<SamplingLog>, String>(
        (ref, pondId) {
  return GrowthNotifier(pondId);
});
