import '../enums/tray_status.dart';
import 'feed_state_engine.dart';

/// ARCHIVED: April 15, 2026 — Not called anywhere in codebase.
/// This was a thin wrapper around FeedStateEngine.
/// Use FeedStateEngine directly (or SmartFeedEngine for active feed logic).
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
