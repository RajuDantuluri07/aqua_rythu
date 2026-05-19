import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/tray/enums/tray_status.dart';
import '../../features/tray/tray_model.dart';
import '../utils/logger.dart';

class TrayService {
  final _supabase = Supabase.instance.client;

  /// Converts `Map<int, List<String>>?` to a JSON-safe `Map<String, dynamic>`.
  ///
  /// - Null/empty → `{}`
  /// - Integer keys → stringified
  /// - Falls back to `{}` if the result still can't encode (corrupt types, circular refs)
  static Map<String, dynamic> sanitizeObservations(
      Map<int, List<String>>? obs) {
    try {
      if (obs == null || obs.isEmpty) return {};
      final result = <String, dynamic>{};
      for (final entry in obs.entries) {
        result[entry.key.toString()] = List<String>.from(entry.value);
      }
      jsonEncode(result); // validate — throws if not encodable
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Returns true when the device has at least one active network interface.
  static Future<bool> _hasConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.isNotEmpty &&
          result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // assume online if check fails
    }
  }

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

    final today = log.time.toIso8601String().split('T')[0];
    final obsJson = sanitizeObservations(log.observations);
    final payload = {
      'pond_id': log.pondId,
      'date': today,
      'doc': log.doc,
      'round_number': log.round,
      'tray_statuses': log.trays.map((e) => e.name).toList(),
      'observations': obsJson,
    };

    try {
      // Offline check — fail fast with a clear message before hitting Supabase.
      final online = await _hasConnectivity();
      if (!online) {
        throw Exception('No internet connection. Tray log could not be saved.');
      }

      // Deduplicate: skip if a tray log already exists for this round today.
      final existing = await _supabase
          .from('tray_logs')
          .select('id')
          .eq('pond_id', log.pondId)
          .eq('doc', log.doc)
          .eq('round_number', log.round)
          .eq('date', today)
          .limit(1);
      if (existing.isNotEmpty) {
        AppLogger.warn(
            'Duplicate tray log skipped: pond ${log.pondId} DOC ${log.doc} R${log.round}');
        return;
      }

      await _supabase.from('tray_logs').insert(payload);
      AppLogger.info('Tray log saved for pond ${log.pondId} at DOC ${log.doc}');
    } catch (e, stack) {
      AppLogger.error(
        'TrayService.saveTrayLog failed | '
        'pond=${log.pondId} doc=${log.doc} round=${log.round} '
        'date=$today trays=${payload['tray_statuses']} obs=$obsJson',
        e,
        stack,
      );
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
        .order('round_number', ascending: false)
        .limit(200);
  }
}
