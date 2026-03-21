import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tray_model.dart';

class TrayNotifier extends StateNotifier<List<TrayLog>> {
  TrayNotifier() : super([]);

  void addTrayLog(TrayLog log) {
    state = [...state, log];
  }

  bool get hasTrayLoggedToday {
    final today = DateTime.now();
    return state.any((log) =>
        log.time.year == today.year &&
        log.time.month == today.month &&
        log.time.day == today.day);
  }
}

final trayProvider =
    StateNotifierProvider.family<TrayNotifier, List<TrayLog>, String>(
  (ref, pondId) => TrayNotifier(),
);