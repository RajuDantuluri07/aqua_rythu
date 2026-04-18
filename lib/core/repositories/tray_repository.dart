import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for tray log data — Supabase queries only, no business logic.
class TrayRepository {
  final _supabase = Supabase.instance.client;

  /// Returns the latest tray score for today, or null if no tray log exists.
  /// Score: 0 = all empty, 1 = partial, 2 = all full (leftover).
  Future<int?> getLastTray(String pondId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    final rows = await _supabase
        .from('tray_logs')
        .select('tray_statuses')
        .eq('pond_id', pondId)
        .eq('date', today)
        .order('round_number', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;

    final statuses = List<String>.from(rows.first['tray_statuses'] as List);
    if (statuses.isEmpty) return null;

    int full = 0, empty = 0;
    for (final s in statuses) {
      if (s == 'full') full++;
      if (s == 'empty') empty++;
    }

    final majority = statuses.length / 2;
    if (full > majority) return 2;   // Leftover — overfed
    if (empty > majority) return 0;  // All eaten — underfed
    return 1;                         // Partial
  }

  Future<void> logTray({
    required String pondId,
    required int roundNumber,
    required List<String> trayStatuses,
  }) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _supabase.from('tray_logs').insert({
      'pond_id': pondId,
      'round_number': roundNumber,
      'tray_statuses': trayStatuses,
      'date': today,
    });
  }
}
