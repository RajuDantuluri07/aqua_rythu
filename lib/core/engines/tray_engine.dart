import '../enums/tray_status.dart';
import 'feed_state_engine.dart';

class TrayEngine {
  static double apply(
    List<TrayStatus> trayStatuses,
    double plannedFeed,
    dynamic mode,
  ) {
    return FeedStateEngine.applyTrayAdjustment(
      trayStatuses,
      plannedFeed,
      mode,
    );
  }
}