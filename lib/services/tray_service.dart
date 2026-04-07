import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/enums/tray_status.dart';
import '../core/engines/smart_feed_engine.dart';
import '../core/utils/logger.dart';

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

      // Trigger smart feed adjustment after tray is persisted
      await SmartFeedEngine.applyTrayAdjustment(
        pondId: pondId,
        doc: doc,
        trayStatus: aggregatedStatus,
      );
    } catch (e) {
      AppLogger.error('TrayService.saveTrayLog failed for pond $pondId', e);
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
