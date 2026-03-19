import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tray_model.dart';

class TrayNotifier extends StateNotifier<List<TrayLog>> {
  TrayNotifier() : super([]);

  void addTrayLog(TrayLog log) {
    state = [...state, log];
  }

  /// ✅ GET TODAY LOGS
  List<TrayLog> getTodayLogs(String pondId) {
    final today = DateTime.now();

    return state.where((log) =>
        log.pondId == pondId &&
        log.time.year == today.year &&
        log.time.month == today.month &&
        log.time.day == today.day).toList();
  }

  /// ✅ CHECK IF TRAY LOGGED TODAY
  bool get hasTrayLoggedToday {
    final today = DateTime.now();
    return state.any((t) =>
        t.time.year == today.year &&
        t.time.month == today.month &&
        t.time.day == today.day);
  }
}

final trayProvider =
    StateNotifierProvider.family<TrayNotifier, List<TrayLog>, String>(
  (ref, pondId) => TrayNotifier(),
);