import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tray_model.dart';
import 'package:aqua_rythu/core/services/tray_service.dart';
import '../../core/utils/logger.dart';

class TrayNotifier extends StateNotifier<List<TrayLog>> {
  final String pondId;

  TrayNotifier(this.pondId) : super([]) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    // ✅ Guard: Skip if pondId is empty (prevents invalid UUID errors)
    if (pondId.isEmpty) {
      state = [];
      return;
    }

    try {
      final rows = await TrayService().fetchTrayLogs(pondId);
      state = rows.map((row) => TrayLog.fromSupabase(row)).toList();
    } catch (e) {
      AppLogger.error(
          'TrayNotifier: failed to load tray logs for pond $pondId', e);
    }
  }

  void addTrayLog(TrayLog log) {
    // TASK 2: TEMPORARY LOG - Verify tray logging triggers feed pipeline
    print(
        " TRAY LOGGED: Pond=$pondId, Round=${log.round}, Status=${log.trays.join(',')}, Leftover=${log.leftoverPercent}%");

    state = [...state, log];
  }

  bool get hasTrayLoggedToday {
    final today = DateTime.now();
    return state.any((log) =>
        log.time.year == today.year &&
        log.time.month == today.month &&
        log.time.day == today.day);
  }

  void clearLogs() {
    state = [];
  }
}

final trayProvider =
    StateNotifierProvider.family<TrayNotifier, List<TrayLog>, String>(
  (ref, pondId) => TrayNotifier(pondId),
);
