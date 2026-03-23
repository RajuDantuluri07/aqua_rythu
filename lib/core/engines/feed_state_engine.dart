import '../enums/tray_status.dart';

enum FeedMode {
  beginner,
  habit,
  precision,
}

class FeedRoundState {
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showMarkFeed;
  final bool showTrayCTA;
  final bool isTrayLogged;

  const FeedRoundState({
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.showMarkFeed,
    required this.showTrayCTA,
    required this.isTrayLogged,
  });
}

class FeedStateEngine {
  /// MODE DECIDER
  static FeedMode getMode(int doc) {
    if (doc <= 15) return FeedMode.beginner;
    if (doc <= 30) return FeedMode.habit;
    return FeedMode.precision;
  }

  /// CORE STATE ENGINE
  static FeedRoundState getRoundState({
    required int doc,
    required int round,
    required int totalRounds,
    required Map<int, bool> feedDone,
    required Map<int, bool> trayDone,
  }) {
    final mode = getMode(doc);

    final isDone = feedDone[round] ?? false;
    final currentRound = _getCurrentRound(feedDone, totalRounds);
    final isCurrent = round == currentRound;

    final isLocked = _isLocked(
      mode: mode,
      round: round,
      feedDone: feedDone,
      trayDone: trayDone,
    );
    
    final isTrayLogged = trayDone[round] ?? false;

    final showMarkFeed = isCurrent && !isDone && !isLocked;

    // Show Tray CTA if fed, not blind mode, and tray not yet logged
    final showTrayCTA = isDone &&
        mode != FeedMode.beginner &&
        !isTrayLogged;

    return FeedRoundState(
      isDone: isDone,
      isCurrent: isCurrent,
      isLocked: isLocked,
      showMarkFeed: showMarkFeed,
      showTrayCTA: showTrayCTA,
      isTrayLogged: isTrayLogged,
    );
  }

  /// LOCK RULE
  static bool _isLocked({
    required FeedMode mode,
    required int round,
    required Map<int, bool> feedDone,
    required Map<int, bool> trayDone,
  }) {
    // Only lock in Precision Mode
    if (mode != FeedMode.precision) return false;
    
    // Round 1 is never locked by previous round
    if (round <= 1) return false;

    final prevRound = round - 1;

    final prevFeedDone = feedDone[prevRound] ?? false;
    final prevTrayDone = trayDone[prevRound] ?? false;

    // Lock if previous round is fed BUT tray is not logged
    // (i.e., user must complete the loop of R(n-1) before starting R(n))
    if (prevFeedDone && !prevTrayDone) {
      return true;
    }

    // Also lock if previous round isn't even done yet (standard sequential locking)
    if (!prevFeedDone) {
      return true;
    }

    return false;
  }

  /// FIND CURRENT ROUND
  static int _getCurrentRound(
    Map<int, bool> feedDone,
    int totalRounds,
  ) {
    for (int i = 1; i <= totalRounds; i++) {
      if (!(feedDone[i] ?? false)) {
        return i;
      }
    }
    return totalRounds;
  }

  // =========================================================
  // 🧠 TRAY-BASED FEED ADJUSTMENT (PRD 5.4)
  // =========================================================

  /// Returns the raw multiplier for a single tray status.
  static double _getTrayMultiplier(TrayStatus status) {
    switch (status) {
      case TrayStatus.empty:
        return 1.08; // +8%
      case TrayStatus.smallLeft:
        return 1.03; // +3%
      case TrayStatus.halfLeft:
        return 1.00; // 0%
      case TrayStatus.fullLeft:
        return 0.92; // -8%
    }
  }

  /// Calculates the average multiplier from a list of tray check results.
  static double calculateAvgMultiplier(List<TrayStatus> trayResults) {
    if (trayResults.isEmpty) {
      return 1.0;
    }

    double totalMultiplier = trayResults
        .map(_getTrayMultiplier)
        .reduce((value, element) => value + element);

    return totalMultiplier / trayResults.length;
  }

  /// Applies the calculated tray adjustment to a planned feed quantity.
  /// The result is capped between 60% and 125% of the original planned quantity.
  static double applyTrayAdjustment(
      {required double plannedQty, required List<TrayStatus> trayResults}) {
    final avgMultiplier = calculateAvgMultiplier(trayResults);
    final adjustedQty = plannedQty * avgMultiplier;

    // Per PRD 5.4, cap the adjustment.
    return adjustedQty.clamp(plannedQty * 0.60, plannedQty * 1.25);
  }
}