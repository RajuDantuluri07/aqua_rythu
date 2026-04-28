import '../../../features/tray/enums/tray_status.dart';
import '../../../features/tray/tray_model.dart';
import '../../core/services/subscription_gate.dart';

/// Result returned by [TrayDecisionEngine.evaluate].
class TrayDecisionResult {
  /// 'INCREASE' | 'REDUCE' | 'MAINTAIN'
  final String action;

  /// Signed integer percentage change: +5, -10, or 0.
  final int percentage;

  /// Average tray score across the rounds considered (-1.0 → +1.0).
  final double avgScore;

  /// Number of tray rounds actually used in the calculation (1–3).
  final int roundsUsed;

  /// Human-readable reason shown inside the Today Decision card.
  final String reason;

  const TrayDecisionResult({
    required this.action,
    required this.percentage,
    required this.avgScore,
    required this.roundsUsed,
    required this.reason,
  });

  /// Formatted percentage string for display, e.g. ' +5%' or ' -10%'.
  String get percentageLabel {
    if (percentage == 0) return '';
    return percentage > 0 ? ' +$percentage%' : ' $percentage%';
  }
}

/// Tray-based scoring decision engine (V1).
///
/// Replaces the single-round naive logic with a multi-round weighted score,
/// stability rules, and safety caps.
///
/// **Scoring**
///   EMPTY  → +1   (shrimp eating well → increase)
///   HALF   →  0   (neutral)
///   FULL   → -1   (feed leftover → reduce)
///
/// **Decision thresholds** (raised to ±0.6 to absorb single-tray noise)
///   avgScore >=  0.6  → INCREASE +5%
///   avgScore <= -0.6  → REDUCE   -10%
///   otherwise         → MAINTAIN
///
/// **Minimum confidence gate**
///   totalTrays < 4 across the window → always MAINTAIN ("Not enough data")
///
/// **Safety rules (always enforced)**
///   1. DOC ≤ 30: blind feed phase → always MAINTAIN, ignore scoring.
///   2. Max change cap: increase ≤ +10%, decrease ≥ -15%.
///   3. No consecutive reduce: if the previous window also resolved to REDUCE,
///      downgrade current REDUCE → MAINTAIN.
///   4. Feed floor: finalFeed ≥ 70% of baseFeed.
class TrayDecisionEngine {
  static const int _maxRounds = 3;

  // ── Tray score mapping ────────────────────────────────────────────────────

  static double _score(TrayStatus s) {
    switch (s) {
      case TrayStatus.empty:
        return 1.0;
      case TrayStatus.full:
        return -1.0;
      case TrayStatus.partial:
        return 0.0;
    }
  }

  // ── Average score across a list of logs ──────────────────────────────────

  static double _avgScore(List<TrayLog> logs) {
    double total = 0;
    int count = 0;
    for (final log in logs) {
      for (final tray in log.trays) {
        total += _score(tray);
        count++;
      }
    }
    return count == 0 ? 0.0 : total / count;
  }

  // ── Raw action from score ─────────────────────────────────────────────────

  // Raised from ±0.5 to ±0.6 — absorbs single-tray noise, prevents flip-flop
  // on borderline scores (e.g. 0.49 vs 0.51 no longer triggers a decision jump).
  static String _actionFromScore(double avg) {
    if (avg >= 0.6) return 'INCREASE';
    if (avg <= -0.6) return 'REDUCE';
    return 'MAINTAIN';
  }

  // ── Main evaluation ───────────────────────────────────────────────────────

  /// Evaluate tray logs and return a [TrayDecisionResult].
  ///
  /// [allTrayLogs] must be sorted newest-first (as returned by the tray
  /// provider which orders by date DESC, round_number DESC).
  ///
  /// Returns display-only signals (action/percentage/reason).
  /// Feed quantity is computed exclusively by MasterFeedEngine.orchestrate().
  static TrayDecisionResult evaluate({
    required List<TrayLog> allTrayLogs,
    required int doc,
  }) {
    // PRO gate: tray-based correction is a paid feature
    // (FeatureIds.trayBasedCorrection). FREE users keep logging trays for
    // history, but no correction signal is surfaced — always MAINTAIN.
    if (!SubscriptionGate.isPro) {
      return const TrayDecisionResult(
        action: 'MAINTAIN',
        percentage: 0,
        avgScore: 0,
        roundsUsed: 0,
        reason: 'Tray-based correction is a PRO feature — upgrade to unlock',
      );
    }

    // Tray data is STORED for DOC 15–29 but corrections activate at DOC ≥ 30.
    if (doc <= 29) {
      return TrayDecisionResult(
        action: 'MAINTAIN',
        percentage: 0,
        avgScore: 0,
        roundsUsed: 0,
        reason: doc < 15
            ? 'Following base feed schedule'
            : 'Following blind schedule until DOC 29 (tray data recorded)',
      );
    }

    final validLogs =
        allTrayLogs.where((l) => !l.isSkipped && l.trays.isNotEmpty).toList();

    if (validLogs.isEmpty) {
      return const TrayDecisionResult(
        action: 'MAINTAIN',
        percentage: 0,
        avgScore: 0,
        roundsUsed: 0,
        reason: 'No tray data yet — follow schedule',
      );
    }

    final currentWindow = validLogs.take(_maxRounds).toList();
    final roundsUsed = currentWindow.length;

    final int totalTrays =
        currentWindow.fold(0, (sum, l) => sum + l.trays.length);
    if (totalTrays < 4) {
      return TrayDecisionResult(
        action: 'MAINTAIN',
        percentage: 0,
        avgScore: 0,
        roundsUsed: roundsUsed,
        reason:
            'Not enough tray data yet ($totalTrays tray reads) — follow schedule',
      );
    }

    final avg = _avgScore(currentWindow);
    String action = _actionFromScore(avg);

    // No consecutive reduce: if previous window also REDUCE, downgrade to MAINTAIN.
    if (action == 'REDUCE' && validLogs.length > _maxRounds) {
      final prevWindow = validLogs.skip(_maxRounds).take(_maxRounds).toList();
      if (_actionFromScore(_avgScore(prevWindow)) == 'REDUCE') {
        action = 'MAINTAIN';
      }
    }

    // Dampen consecutive increase: +5% → +3% (BUG-09 fix).
    if (action == 'INCREASE' && validLogs.length > _maxRounds) {
      final prevWindow = validLogs.skip(_maxRounds).take(_maxRounds).toList();
      if (_avgScore(prevWindow) >= 0.6) {
        action = 'INCREASE_DAMPENED';
      }
    }

    int percentage;
    if (action == 'INCREASE') {
      percentage = 5;
    } else if (action == 'INCREASE_DAMPENED') {
      percentage = 3;
      action = 'INCREASE';
    } else if (action == 'REDUCE') {
      percentage = -10;
    } else {
      percentage = 0;
    }

    final allTrays = currentWindow.expand((l) => l.trays).toList();
    final emptyCount = allTrays.where((t) => t == TrayStatus.empty).length;
    final fullCount = allTrays.where((t) => t == TrayStatus.full).length;
    final totalCount = allTrays.length;
    final roundWord = roundsUsed == 1 ? 'round' : 'rounds';

    String reason;
    if (action == 'INCREASE') {
      reason = percentage == 3
          ? '$roundsUsed $roundWord mostly empty '
              '($emptyCount/$totalCount trays) — small increase (consecutive)'
          : '$roundsUsed $roundWord mostly empty '
              '($emptyCount/$totalCount trays) — increasing feed';
    } else if (action == 'REDUCE') {
      reason = '$roundsUsed $roundWord with feed left '
          '($fullCount/$totalCount trays full) — reducing feed';
    } else {
      reason =
          'Mixed tray response across $roundsUsed $roundWord — stable feed';
    }

    return TrayDecisionResult(
      action: action,
      percentage: percentage,
      avgScore: avg,
      roundsUsed: roundsUsed,
      reason: reason,
    );
  }
}
