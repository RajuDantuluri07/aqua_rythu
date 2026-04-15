enum PondCycleState {
  waitForTray,
  trayCheck,
  readyForNextFeed,
}

/// Minimal state machine for pond cycle timing.
///
/// This belongs to operational flow only and is intentionally separate from
/// feed quantity / feed calculation engines.
class PondCycleEngine {
  /// Window after feed during which the farmer is expected to wait and log tray data.
  static const int trayCheckDelayMinutes = 120;

  /// Minimal buffer after tray logging before the pond is ready for the next feed.
  static const int postTrayBufferMinutes = 30;

  /// Determines the current pond cycle state.
  ///
  /// - [lastFeedTime] is required to compute the flow since the previous feed.
  /// - [lastTrayLoggedTime] remains null until the tray is actually checked.
  /// - [now] is injectable for testing; defaults to DateTime.now().
  static PondCycleState getCurrentState({
    required DateTime? lastFeedTime,
    DateTime? lastTrayLoggedTime,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (lastFeedTime == null) {
      return PondCycleState.readyForNextFeed;
    }

    final minutesSinceFeed = current.difference(lastFeedTime).inMinutes;

    if (lastTrayLoggedTime == null) {
      return minutesSinceFeed < trayCheckDelayMinutes
          ? PondCycleState.waitForTray
          : PondCycleState.trayCheck;
    }

    final minutesSinceTray = current.difference(lastTrayLoggedTime).inMinutes;
    return minutesSinceTray < postTrayBufferMinutes
        ? PondCycleState.waitForTray
        : PondCycleState.readyForNextFeed;
  }
}
