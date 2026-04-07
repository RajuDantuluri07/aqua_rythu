import '../enums/tray_status.dart';

enum FeedMode {
  blind,
  transitional,
  smart,
}

class FeedRoundState {
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showMarkFeed;
  final bool showTrayCTA;
  final bool showOptionalTray;
  final bool isTrayLogged;
  final List<TrayStatus>? trayResults;

  const FeedRoundState({
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.showMarkFeed,
    required this.showTrayCTA,
    required this.showOptionalTray,
    required this.isTrayLogged,
    this.trayResults,
  });

  FeedRoundState copyWith({
    bool? isDone,
    bool? isCurrent,
    bool? isLocked,
    bool? showMarkFeed,
    bool? showTrayCTA,
    bool? showOptionalTray,
    bool? isTrayLogged,
    List<TrayStatus>? trayResults,
  }) {
    return FeedRoundState(
      isDone: isDone ?? this.isDone,
      isCurrent: isCurrent ?? this.isCurrent,
      isLocked: isLocked ?? this.isLocked,
      showMarkFeed: showMarkFeed ?? this.showMarkFeed,
      showTrayCTA: showTrayCTA ?? this.showTrayCTA,
      showOptionalTray: showOptionalTray ?? this.showOptionalTray,
      isTrayLogged: isTrayLogged ?? this.isTrayLogged,
      trayResults: trayResults ?? this.trayResults,
    );
  }
}

class FeedStateEngine {
  /// MODE DECIDER (Smart Feed Activation + DOC-Based)
  /// 
  /// Business Rules:
  /// - Smart Feed activates ONLY when DOC > 30 AND isSmartFeedEnabled = true
  /// - Once activated → Smart Feed NEVER turns OFF
  /// - DOC ≤ 30: Blind Feed (Mark as Fed, Tray Optional)
  /// - DOC > 30 + Smart Feed Enabled: Smart Feed (Save Feed, Tray Mandatory)
  static FeedMode getMode(int doc, {bool isSmartFeedEnabled = false}) {
    // 🟡 DOC ≤ 30: Always Blind Feed (regardless of Smart Feed status)
    if (doc <= 30) {
      return FeedMode.blind;
    }
    
    // 🟣 DOC > 30: Check Smart Feed activation
    if (isSmartFeedEnabled) {
      return FeedMode.smart;
    }
    
    // Fallback: Transitional (shouldn't happen with proper activation)
    return FeedMode.transitional;
  }

  /// Legacy method for backward compatibility
  static FeedMode getModeByDoc(int doc) {
    if (doc < 15) return FeedMode.blind;
    if (doc <= 30) return FeedMode.transitional;
    return FeedMode.smart;
  }

  /// CORE STATE ENGINE
  static FeedRoundState getRoundState({
    required int doc,
    required int round,
    required int totalRounds,
    required Map<int, bool> feedDone,
    required Map<int, bool> trayDone,
    Map<int, List<TrayStatus>>? trayResultsMap,
    bool isSmartFeedEnabled = false,
  }) {
    final mode = getMode(doc, isSmartFeedEnabled: isSmartFeedEnabled);

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
    final trayResults = trayResultsMap?[round];

    final showMarkFeed = isCurrent && !isDone && !isLocked;

    // 🟠 TRANSITIONAL MODE TRAY (Optional - DOC 15-30)
    final showOptionalTray =
        isDone && mode == FeedMode.transitional && !isTrayLogged;

    // 🟢 SMART MODE TRAY (Mandatory - DOC >= 31)
    final showTrayCTA = isDone && mode == FeedMode.smart && !isTrayLogged;

    return FeedRoundState(
      isDone: isDone,
      isCurrent: isCurrent,
      isLocked: isLocked,
      showMarkFeed: showMarkFeed,
      showTrayCTA: showTrayCTA,
      showOptionalTray: showOptionalTray,
      isTrayLogged: isTrayLogged,
      trayResults: trayResults,
    );
  }


  /// LOCK RULE
  static bool _isLocked({
    required FeedMode mode,
    required int round,
    required Map<int, bool> feedDone,
    required Map<int, bool> trayDone,
  }) {
    // Round 1 is never locked by previous round
    if (round <= 1) return false;

    final prevRound = round - 1;
    final prevFeedDone = feedDone[prevRound] ?? false;

    // 1. STANDARD SEQUENTIAL LOCK (All Modes)
    // Cannot start R(n) if R(n-1) is not fed
    if (!prevFeedDone) {
      return true;
    }

    // 2. SMART MODE TRAY LOCK
    // If in Smart Mode, require Tray(n-1) to be logged before starting Round(n)
    if (mode == FeedMode.smart) {
      final prevTrayDone = trayDone[prevRound] ?? false;
      if (!prevTrayDone) {
        return true;
      }
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
    return totalRounds + 1;
  }

  // =========================================================
  // 🧠 TRAY-BASED FEED ADJUSTMENT (PRD 5.4)
  // =========================================================

  /// Calculates the adjustment factor based on tray priorities.
  /// PRD 5.4 Rules:
  /// Empty -> 1.08 (+8%)
  /// Partial -> 1.00 (0%) (Conservative mapping for Small/Half)
  /// Full -> 0.92 (-8%)
  static double getAdjustmentFactor(TrayStatus status) {
    if (status == TrayStatus.full) {
      return 0.92; // -8%
    }
    if (status == TrayStatus.partial) {
      return 1.00; // 0% (No change)
    }
    return 1.08; // +8% (Increase)
  }

  /// Applies the calculated tray adjustment to a planned feed quantity.
  static double applyTrayAdjustment(
      List<TrayStatus> trayResults,
      double plannedQty,
      FeedMode mode) {
    final aggregate = aggregateTrayStatus(trayResults);
    final factor = getAdjustmentFactor(aggregate);
    var adjustedQty = plannedQty * factor;
    
    // 🔒 PRD 5.4 SAFETY CAPS: [0.6x, 1.25x] of plan
    final minSafe = plannedQty * 0.60;
    final maxSafe = plannedQty * 1.25;
    
    if (adjustedQty < minSafe) {
      adjustedQty = minSafe;
    }
    if (adjustedQty > maxSafe) {
      adjustedQty = maxSafe;
    }

    return adjustedQty;
  }

  /// Aggregates a list of tray statuses into a single representative status.
  /// Logic: Weighted Average (Full=3, Partial=2, Empty=0)
  static TrayStatus aggregateTrayStatus(List<TrayStatus> statuses) {
    if (statuses.isEmpty) {
      return TrayStatus.partial;
    } // Default to partial (no change) for safety

    int totalScore = 0;

    for (final status in statuses) {
      if (status == TrayStatus.full) {
        totalScore += 3;
      } else if (status == TrayStatus.partial) {
        totalScore += 2;
      }
      // Empty contributes 0
    }

    final double avg = totalScore / statuses.length;

    if (avg >= 2.5) return TrayStatus.full;
    if (avg >= 1.5) return TrayStatus.partial;
    
    return TrayStatus.empty;
  }
}