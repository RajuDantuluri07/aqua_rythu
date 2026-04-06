import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sampling_log.dart';
import '../../core/utils/logger.dart';

class GrowthNotifier extends StateNotifier<List<SamplingLog>> {
  final String pondId;
  final _supabase = Supabase.instance.client;

  GrowthNotifier(this.pondId) : super([]) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
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

      state = logs;
    } catch (e) {
      AppLogger.error('Failed to load sampling logs', e);
    }
  }

  Future<void> addLog(SamplingLog log) async {
    // Update UI immediately
    state = [log, ...state];

    // Persist to Supabase
    try {
      await _supabase.from('sampling_logs').insert({
        'pond_id': pondId,
        'avg_weight': log.abw,
        'count': log.totalPieces,
        'doc': log.doc,
        'created_at': log.date.toIso8601String(),
      });
    } catch (e) {
      AppLogger.error('Failed to save sampling log', e);
    }
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
