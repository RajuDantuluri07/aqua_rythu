import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/tray/enums/tray_status.dart';
import '../utils/logger.dart';
import 'tray_service.dart';

/// Service for the unified tray_checks table.
///
/// Every tray observation is stored under a feed_round_id — no orphan rows.
/// Dual-writes are handled by the caller: PondDashboardProvider also calls
/// TrayService.saveTrayLog() for backward-compat with the smart feed engine
/// until that engine is migrated to read from tray_checks.
class TrayCheckService {
  final _supabase = Supabase.instance.client;

  /// Maps each TrayStatus to a numeric score in [0, 1].
  ///
  /// These weights match the save_tray_check SQL RPC:
  ///   empty=0.00  light=0.15  medium=0.40  heavy=0.70
  static double calculateTrayFactor(List<TrayStatus> trays) {
    if (trays.isEmpty) return 0.0;
    final total = trays.fold(0.0, (sum, t) => sum + _trayScore(t));
    return total / trays.length;
  }

  static double _trayScore(TrayStatus t) {
    return switch (t) {
      TrayStatus.empty  => 0.00,
      TrayStatus.light  => 0.15,
      TrayStatus.medium => 0.40,
      TrayStatus.heavy  => 0.70,
    };
  }

  /// Saves a tray check under [feedRoundId] via the save_tray_check RPC.
  ///
  /// Also advances feed_rounds.feed_status to 'tray_checked' atomically.
  /// Throws on network error or invalid feed_round_id.
  Future<void> saveTrayCheck({
    required String feedRoundId,
    required String pondId,
    required List<TrayStatus> trays,
    Map<int, List<String>>? observations,
    DateTime? checkedAt,
  }) async {
    final trayFactor = calculateTrayFactor(trays);
    final obsJson = TrayService.sanitizeObservations(observations);

    try {
      final result = await _supabase.rpc('save_tray_check', params: {
        'p_feed_round_id': feedRoundId,
        'p_pond_id': pondId,
        'p_tray_statuses': trays.map((t) => t.name).toList(),
        'p_observations': obsJson,
        'p_tray_factor': trayFactor,
        'p_checked_at': (checkedAt ?? DateTime.now()).toIso8601String(),
      });

      final Map<String, dynamic> res = _parseRpcResult(result);
      if (res['success'] != true) {
        throw Exception('save_tray_check RPC failed: ${res['error']}');
      }

      AppLogger.info(
        'TrayCheck saved: '
        'feedRound=$feedRoundId pond=$pondId factor=${trayFactor.toStringAsFixed(3)} '
        'checkId=${res['tray_check_id']}',
      );
    } catch (e, st) {
      AppLogger.error(
        'TrayCheckService.saveTrayCheck failed | '
        'feedRoundId=$feedRoundId pond=$pondId trays=${trays.map((t) => t.name).toList()}',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Looks up the feed_round id for a given (pondId, doc, round) triplet.
  ///
  /// Returns null if no matching row exists (e.g. manual round not yet in DB).
  Future<String?> getFeedRoundId({
    required String pondId,
    required int doc,
    required int round,
  }) async {
    try {
      final row = await _supabase
          .from('feed_rounds')
          .select('id')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .eq('round', round)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (e, st) {
      AppLogger.error(
        'TrayCheckService.getFeedRoundId failed | pond=$pondId doc=$doc round=$round',
        e,
        st,
      );
      return null;
    }
  }

  /// Fetches all tray checks for a specific feed round, ordered by checked_at.
  Future<List<Map<String, dynamic>>> getTrayChecksForRound(
      String feedRoundId) async {
    try {
      return await _supabase
          .from('tray_checks')
          .select()
          .eq('feed_round_id', feedRoundId)
          .order('checked_at', ascending: false);
    } catch (e, st) {
      AppLogger.error(
        'TrayCheckService.getTrayChecksForRound failed | feedRoundId=$feedRoundId',
        e,
        st,
      );
      return [];
    }
  }

  Map<String, dynamic> _parseRpcResult(dynamic result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return {'success': false, 'error': 'Unexpected RPC response: $result'};
  }
}
