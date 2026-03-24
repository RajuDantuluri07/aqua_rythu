import '../enums/tray_status.dart';
import 'package:aqua_rythu/features/tray/tray_model.dart';
import 'engine_constants.dart';

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

    // ✅ TRAY CTA LOGIC: 
    // - Never show in Beginner Mode (DOC <= 15)
    // - Always show after feeding in other modes unless already logged
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
    return totalRounds + 1;
  }

  // =========================================================
  // 🧠 TRAY-BASED FEED ADJUSTMENT (PRD 5.4)
  // =========================================================

  /// Calculates the adjustment factor based on tray priorities.
  /// Priority: Full > Half > Small > Empty
  static double getAdjustmentFactor(TrayStatus status) {
    // 🔒 CORE LOGIC (LOCKED)
    if (status == TrayStatus.heavy) {
      return FeedEngineConstants.heavyLeftoverMultiplier; // -30%
    }
    if (status == TrayStatus.medium) {
      return FeedEngineConstants.mediumLeftoverMultiplier; // -15%
    }
    if (status == TrayStatus.slight) {
      return FeedEngineConstants.slightLeftoverMultiplier; // -5%
    }
    return FeedEngineConstants.emptyTrayMultiplier; // No change for Empty
  }

  /// Applies the calculated tray adjustment to a planned feed quantity.
  static double applyTrayAdjustment(
      {required double plannedQty, required TrayStatus trayResult}) {
    final factor = getAdjustmentFactor(trayResult);
    final adjustedQty = plannedQty * factor;
    
    return adjustedQty;
  }

  /// Aggregates a list of tray statuses into a single representative status.
  /// Logic: Weighted Average (Heavy=3, Medium=2, Slight=1, Empty=0)
  static TrayStatus aggregateTrayStatus(List<TrayStatus> statuses) {
    if (statuses.isEmpty) return TrayStatus.slight; // Default fallback

    int totalScore = 0;
    TrayStatus? emptyStatus;

    for (final status in statuses) {
      if (status == TrayStatus.heavy) {
        totalScore += 3;
      } else if (status == TrayStatus.medium) {
        totalScore += 2;
      } else if (status == TrayStatus.slight) {
        totalScore += 1;
      } else {
        emptyStatus = status; // Capture the 'empty' enum variant
      }
    }

    final double avg = totalScore / statuses.length;

    if (avg >= 2.5) return TrayStatus.heavy;
    if (avg >= 1.5) return TrayStatus.medium;
    if (avg >= 0.5) return TrayStatus.slight;

    return emptyStatus ?? TrayStatus.values.firstWhere(
        (e) => e != TrayStatus.heavy && e != TrayStatus.medium && e != TrayStatus.slight,
        orElse: () => TrayStatus.slight // Fallback safety
    );
  }
}