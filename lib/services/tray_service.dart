import 'package:supabase_flutter/supabase_flutter.dart';

class TrayService {
  final _supabase = Supabase.instance.client;

  /// Persists a tray observation log to Supabase.
  ///
  /// [trayStatuses] is expected to be a list of strings representing the status of each tray.
  /// [observations] is a map containing JSON-serializable observation data.
  Future<void> saveTrayLog({
    required String pondId,
    required DateTime date,
    required int doc,
    required int roundNumber,
    required List<String> trayStatuses,
    required Map<String, dynamic> observations,
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
    } catch (e) {
      // Rethrow to allow the provider or UI to handle the error state gracefully
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