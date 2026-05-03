import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/tray/enums/tray_status.dart';
import '../../features/tray/tray_model.dart';
import '../utils/logger.dart';

class TrayService {
  final _supabase = Supabase.instance.client;

  /// Persists a tray log to Supabase and triggers smart feed adjustment.
  ///
  /// [log] is the tray log to be persisted.
  Future<void> saveTrayLog(TrayLog log) async {
    // Validate required fields
    if (log.pondId.isEmpty) {
      throw ArgumentError('Pond ID is required');
    }
    if (log.trays.isEmpty) {
      throw ArgumentError('Tray statuses are required');
    }

    // Validate all tray statuses are valid enum values
    for (final tray in log.trays) {
      if (!TrayStatus.values.contains(tray)) {
        throw ArgumentError('Invalid tray status: $tray');
      }
    }

    try {
      await _supabase.from('tray_logs').insert({
        'pond_id': log.pondId,
        'date': log.time.toIso8601String().split('T')[0],
        'doc': log.doc,
        'round_number': log.round,
        'tray_statuses': log.trays.map((e) => e.name).toList(),
        'observations': log.observations,
      });

      // Trigger feed adjustment via service after tray is persisted
      // Note: This is a placeholder - actual implementation may vary
      AppLogger.info('Tray log saved for pond ${log.pondId} at DOC ${log.doc}');
    } catch (e, stack) {
      AppLogger.error(
          'TrayService.saveTrayLog failed for pond ${log.pondId}', e, stack);
      rethrow;
    }
  }

  /// Records a tray check as skipped — used when the farmer moves to the next
  /// feed round without logging the tray. Stores tray_statuses = ['skipped']
  /// so the smart engine uses a neutral factor (no adjustment).
  Future<void> markTraySkipped({
    required String pondId,
    required int doc,
    required int roundNumber,
  }) async {
    try {
      // Only insert if no tray log already exists for this round today
      final today = DateTime.now().toIso8601String().split('T')[0];
      final existing = await _supabase
          .from('tray_logs')
          .select('id')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .eq('round_number', roundNumber)
          .eq('date', today)
          .limit(1);
      if (existing.isNotEmpty) return; // already logged (real or skipped)

      await _supabase.from('tray_logs').insert({
        'pond_id': pondId,
        'date': today,
        'doc': doc,
        'round_number': roundNumber,
        'tray_statuses': ['skipped'],
        'observations': {},
      });
      AppLogger.info('Tray skipped: pond $pondId DOC $doc R$roundNumber');
    } catch (e, stack) {
      AppLogger.error(
          'TrayService.markTraySkipped failed for pond $pondId', e, stack);
      rethrow;
    }
  }

  /// Retrieves all tray logs for a specific pond, ordered by date and round.
  Future<List<Map<String, dynamic>>> fetchTrayLogs(String pondId) async {
    // ✅ Guard: Return empty list if pondId is empty (prevents invalid UUID errors)
    if (pondId.isEmpty) {
      return [];
    }

    return await _supabase
        .from('tray_logs')
        .select()
        .eq('pond_id', pondId)
        .order('date', ascending: false)
        .order('round_number', ascending: false);
  }
}
