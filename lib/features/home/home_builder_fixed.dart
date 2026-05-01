import '../../features/tray/enums/tray_status.dart';
import '../../features/tray/tray_model.dart';

class HomeBuilderFixed {
  static double _rollingWaste(List<TrayLog> logs) {
    final usable = logs.where((l) => !l.isSkipped && l.trays.isNotEmpty).take(5);
    double sum = 0; int cnt = 0;
    for (final log in usable) {
      for (final t in log.trays) {
        sum += t == TrayStatus.empty ? 0 : t == TrayStatus.light ? 30 : 70;
        cnt++;
      }
    }
    return cnt > 0 ? sum / cnt : 0;
  }

  static String _trayMajority(TrayLog log) {
    if (log.trays.isEmpty) return 'Logged';
    final full  = log.trays.where((t) => t == TrayStatus.heavy).length;
    final empty = log.trays.where((t) => t == TrayStatus.empty).length;
    if (full  > log.trays.length / 2) return 'Full (leftover)';
    if (empty > log.trays.length / 2) return 'Empty (hungry)';
    return 'Partial';
  }

  static String? _trayTag(TrayLog log) {
    if (log.trays.isEmpty) return null;
    final full  = log.trays.where((t) => t == TrayStatus.heavy).length;
    final empty = log.trays.where((t) => t == TrayStatus.empty).length;
    if (full  > log.trays.length / 2) return '⚠️ leftover high';
    if (empty > log.trays.length / 2) return '🔺 shrimp hungry';
    return null;
  }
}
