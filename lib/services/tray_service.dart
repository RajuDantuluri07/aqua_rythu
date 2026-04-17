import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/enums/tray_status.dart';
import '../core/utils/logger.dart';
import 'feed_service.dart';

class TrayService {
  final _supabase = Supabase.instance.client;

  /// Persists a tray log to Supabase and triggers smart feed adjustment.
  ///
  /// [trayStatuses] is the raw list of per-tray status strings.
  /// [aggregatedStatus] is the pre-computed majority status used for feed adjustment.
  /// [doc] is used to enforce the DOC > 30 guard in the engine.
  Future<void> saveTrayLog({
    required String pondId,
    required DateTime date,
    required int doc,
    required int roundNumber,
    required List<String> trayStatuses,
    required Map<String, dynamic> observations,
    required TrayStatus aggregatedStatus,
  }) async {
    try {
      await _supabase.from('tray_logs').insert({
        'pond_id': pondId,
        'date': date.toIso8601String().split('T')[0],
        'doc': doc,
        'round_number': roundNumber,
        'tray_statuses': trayStatuses,
        'observations': observations,
      });

      // Trigger feed adjustment via service after tray is persisted
      await FeedService().applyTrayAdjustment(
        pondId: pondId,
        doc: doc,
        trayStatus: aggregatedStatus,
      );
    } catch (e, stack) {
      AppLogger.error('TrayService.saveTrayLog failed for pond $pondId', e, stack);
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
      AppLogger.error('TrayService.markTraySkipped failed for pond $pondId', e, stack);
      rethrow;
    }
  }

  /// Retrieves all tray logs for a specific pond, ordered by date and round.
  Future<List<Map<String, dynamic>>> fetchTrayLogs(String pondId) async {
    return await _supabase
        .from('tray_logs')
        .select()
        .eq('pond_id', pondId)
        .order('date', ascending: false)
        .order('round_number', ascending: false);
  }
}
