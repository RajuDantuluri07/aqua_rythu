// Validates whether a feed action is safe before the farmer marks a round done.
import 'engine_constants.dart';
import '../utils/time_provider.dart';
//
// Philosophy: Guide, don't restrict.
//   ALLOW   → go ahead, all good
//   WARNING → risky but farmer can proceed (show banner, don't disable button)
//   BLOCK   → must not feed (daily max reached — rare, hard rule)
//
// Fixed schedule: 06:00 / 11:00 / 16:00 / 21:00
// Gap logic runs invisibly behind the fixed schedule UI.
//
// Warning priority (P3-07): BLOCK > GAP > TRAY — one warning at a time.

import '../utils/logger.dart';

enum FeedStatusCode { allow, warning, block }

// Single model returned from evaluate() — UI calls one method, gets everything.
class FeedDecision {
  final FeedStatusCode status;

  /// Farmer-friendly message explaining the reason (WARNING/BLOCK only).
  final String? message;

  /// Unified "minutes until optimal to feed" —
  /// max(lastFeedTime + gap, nextScheduledTime). Null when all rounds done.
  final int? minutesUntilNext;

  const FeedDecision({
    required this.status,
    this.message,
    this.minutesUntilNext,
  });

  bool get isAllow => status == FeedStatusCode.allow;
  bool get isWarning => status == FeedStatusCode.warning;
  bool get isBlock => status == FeedStatusCode.block;
}

class FeedStatusEngine {
  /// Blind mode (DOC ≤ 30) minimum gap between feeds.
  static const int blindMinGapMinutes = 150;

  /// Smart mode (DOC > 30) minimum gap between feeds.
  static const int smartMinGapMinutes = 180;

  /// Tray warning only appears after 90 min post-last-feed (P3-02).
  /// Gives the farmer a realistic window to physically check the tray.
  static const int trayCheckDelayMinutes = 90;

  /// Evaluate whether the next feed is safe.
  ///
  /// [lastFeedTime]        — when the farmer last completed a round (null = first feed today)
  /// [feedsCompletedToday] — rounds already marked done today
  /// [doc]                 — day of culture (1-based)
  /// [hasTrayForLastRound] — whether the most recent completed round has a tray logged
  static FeedDecision evaluate({
    required DateTime? lastFeedTime,
    required int feedsCompletedToday,
    required int doc,
    required bool hasTrayForLastRound,
  }) {
    final int maxRounds = doc <= 7 ? 2 : 4;
    final now = TimeProvider.now();

    // Compute unified minutesUntilNext up-front so every return can carry it.
    final int? minsUntilNext = minutesUntilNextFeed(
      now: now,
      lastFeedTime: lastFeedTime,
      doc: doc,
      feedsDoneToday: feedsCompletedToday,
    );

    // ── 1. BLOCK — daily max reached (highest priority) ──────────────────────
    if (feedsCompletedToday >= maxRounds) {
      const result = FeedDecision(
        status: FeedStatusCode.block,
        message: 'All rounds completed today. Come back tomorrow.',
      );
      _log(result, doc: doc, feedsToday: feedsCompletedToday);
      return result;
    }

    // ── P3.5-04: First feed of the day — always ALLOW, no gap/tray checks ────
    if (lastFeedTime == null) {
      final result = FeedDecision(
        status: FeedStatusCode.allow,
        minutesUntilNext: minsUntilNext,
      );
      _log(result, doc: doc, feedsToday: feedsCompletedToday);
      return result;
    }

    final int minGap = doc >= 30 ? smartMinGapMinutes : blindMinGapMinutes;
    final int gapElapsed = now.difference(lastFeedTime).inMinutes;

    // ── 2. GAP warning (higher priority than tray, P3-07) ────────────────────
    if (gapElapsed < minGap) {
      final int left = minGap - gapElapsed;
      final result = FeedDecision(
        status: FeedStatusCode.warning,
        // P3.5-05: leading icon in message for fast scanning
        // P3-01: explain WHY, not just what
        message: '⏳ Better results if you wait $left min (previous feed still active)',
        minutesUntilNext: left,
      );
      _log(result, doc: doc, feedsToday: feedsCompletedToday);
      return result;
    }

    // ── 3. TRAY warning — only after 90 min, only DOC ≥ 30 (P3-02) ──────────
    if (doc >= 30 && feedsCompletedToday > 0 && !hasTrayForLastRound &&
        gapElapsed >= trayCheckDelayMinutes) {
      final result = FeedDecision(
        status: FeedStatusCode.warning,
        // P3.5-05: distinct icon from gap warning
        // P3-01: farmer-friendly reason
        message: '🟠 Check tray from last feed to adjust next feeding',
        minutesUntilNext: minsUntilNext,
      );
      _log(result, doc: doc, feedsToday: feedsCompletedToday);
      return result;
    }

    final result = FeedDecision(
      status: FeedStatusCode.allow,
      minutesUntilNext: minsUntilNext,
    );
    _log(result, doc: doc, feedsToday: feedsCompletedToday);
    return result;
  }

  // ── P3.5-07: Debug logging — visible in debug builds, stripped in release ──
  static void _log(FeedDecision d, {required int doc, required int feedsToday}) {
    final msg = d.message?.replaceAll('"', "'") ?? '-';
    AppLogger.debug(
      '[FeedStatusEngine] doc=$doc feeds=$feedsToday '
      'status=${d.status.name} minsUntilNext=${d.minutesUntilNext} '
      'msg="$msg"',
    );
  }

  // ── Unified "minutes until optimal next feed" (P3-03) ─────────────────────
  // Derived from [nextFeedAt] — single logic source, no duplication.
  // Returns null when all rounds for today are done.
  // Clamped to 0 minimum (callers that need negative values use [nextFeedAt]).
  static int? minutesUntilNextFeed({
    required DateTime now,
    required DateTime? lastFeedTime,
    required int doc,
    required int feedsDoneToday,
  }) {
    final target = nextFeedAt(
      now: now,
      lastFeedTime: lastFeedTime,
      doc: doc,
      feedsDoneToday: feedsDoneToday,
    );
    if (target == null) return null;
    final mins = target.difference(now).inMinutes;
    return mins < 0 ? 0 : mins;
  }

  // ── SSOT: next feed DateTime ───────────────────────────────────────────────
  /// Returns the exact [DateTime] the farmer should next feed, or null when
  /// all rounds for the day are complete.
  ///
  /// This is the **single source of truth** for "when is next feed."
  /// It returns the LATER of (lastFeed + required gap) vs (scheduled slot time),
  /// giving an unclamped DateTime so callers can compute:
  ///   - timeRemaining  = nextFeedAt.difference(now)  → positive = too early
  ///   - overdue check  = timeRemaining < -30 min
  ///   - live countdown = formatted from timeRemaining.abs()
  ///
  /// [minutesUntilNextFeed] is now derived from this. Do NOT duplicate the
  /// schedule / gap logic anywhere else.
  static DateTime? nextFeedAt({
    required DateTime now,
    required DateTime? lastFeedTime,
    required int doc,
    required int feedsDoneToday,
  }) {
    final List<int> schedule = doc <= 7 ? [7, 18] : [6, 11, 16, 21];
    if (feedsDoneToday >= schedule.length) return null;

    final DateTime nextScheduled =
        DateTime(now.year, now.month, now.day, schedule[feedsDoneToday]);
    final int minGap = doc >= 30 ? smartMinGapMinutes : blindMinGapMinutes;
    final DateTime gapClears = lastFeedTime != null
        ? lastFeedTime.add(Duration(minutes: minGap))
        : now;

    return gapClears.isAfter(nextScheduled) ? gapClears : nextScheduled;
  }

  // ── Utility: suggested feeds already done based on current time ───────────
  // Used in AddPondScreen to pre-fill the "feeds done today" chip.
  static int suggestedFeedsDoneNow(int doc) {
    final int hour = TimeProvider.now().hour;
    if (doc <= 7) {
      if (hour < 8) return 0;
      if (hour < 19) return 1;
      return 2;
    } else {
      if (hour < 7) return 0;
      if (hour < 12) return 1;
      if (hour < 17) return 2;
      if (hour < 22) return 3;
      return 4;
    }
  }

  // ── Smart Mode transition pre-warning (DOC 27–29) ────────────────────────
  /// Returns a non-null warning string on DOC 27, 28, and 29 to prepare the
  /// farmer for Smart Mode activation at DOC 30 (smart_feeding = doc >= 30).
  ///
  /// Gives 3 days of progressive education so the transition is never a surprise.
  /// Returns null on all other DOCs (caller should skip showing any banner).
  static String? smartModeTransitionWarning(int doc) {
    switch (doc) {
      case 27:
        return '⏳ Smart Feed activates in 3 days (DOC 30). '
            'Start logging trays after each round now to avoid interruptions.';
      case 28:
        return '⚠️ Smart Feed activates in 2 days (DOC 30). '
            'Tray logging will be required for every round.';
      case 29:
        return '🚀 Smart Feed activates tomorrow (DOC 30). Each round will need a '
            'tray check before the next round unlocks. Log tonight\'s tray!';
      default:
        return null;
    }
  }

  // ── V2-05: Next Action string ──────────────────────────────────────────────
  /// Returns a one-line "what to do next" instruction for the farmer.
  /// Always returns a non-null, non-empty string — dashboard is never blank.
  ///
  /// Priority: all-done > pending tray > wait countdown > feed now
  static String getNextAction({
    required int doc,
    required int feedsDone,
    required int maxFeeds,
    required int? minutesUntilNext,
    required bool hasPendingTray,
  }) {
    if (feedsDone >= maxFeeds) {
      return '✅ All feeds done today';
    }
    if (hasPendingTray && doc >= 30) {
      return '👉 Log tray for last feed';
    }
    if (minutesUntilNext != null && minutesUntilNext > 0) {
      // Time removed — live countdown is shown in FeedTimelineCard (no duplication).
      return '⏳ Next round coming up — check timer';
    }
    return '👉 Feed now';
  }

  // ── V2-04: ₹-framed warning helpers ────────────────────────────────────────

  /// Estimated ₹ cost lost from feeding too early.
  /// BUG-13 fix: was hardcoded at ₹20/kg — 3-4x lower than actual feed cost.
  /// Now uses [FeedEngineConstants.feedCostPerKg] (₹70/kg default).
  static double estimateFeedLoss(double feedQtyKg) =>
      feedQtyKg * FeedEngineConstants.feedCostPerKg;

  /// Replaces the generic "wait X min" warning with a ₹-impact message.
  /// Shows farmers the financial cost of ignoring the gap, not just a rule.
  static String buildWarningMessage({
    required int minutesRemaining,
    required double estLoss,
  }) {
    final timeText = _formatMins(minutesRemaining);
    final lossText = estLoss >= 1000
        ? '₹${(estLoss / 1000).toStringAsFixed(1)}K'
        : '₹${estLoss.toInt()}';
    return '⚠️ Feeding now may waste $lossText • Better to wait $timeText';
  }

  // ── Shared minute formatter (avoids duplicating logic across callers) ───────
  static String _formatMins(int mins) {
    if (mins < 60) return 'in ${mins}m';
    final int h = mins ~/ 60;
    final int m = mins % 60;
    return m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
  }
}
