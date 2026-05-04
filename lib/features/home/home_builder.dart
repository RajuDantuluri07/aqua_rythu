import 'package:flutter/material.dart';
import 'package:aqua_rythu/core/constants/expected_abw_table.dart';
import 'package:aqua_rythu/features/tray/enums/tray_status.dart';
import 'package:aqua_rythu/features/feed/feed_history_provider.dart';
import 'package:aqua_rythu/features/growth/sampling_log.dart';
import 'package:aqua_rythu/features/tray/tray_model.dart';
import 'home_view_model.dart';

/// Single computation point for all home screen data.
///
/// Rules:
///  - No Flutter widgets, no BuildContext.
///  - All inputs are plain Dart values from providers.
///  - Outputs HomeViewModel — widgets contain ZERO business logic.
///  - Contradictions are impossible: every widget reads from the same struct.
class HomeBuilder {
  HomeBuilder._();

  static const int _overdueGraceMinutes = 30;
  static const int _smartGapMinutes     = 180;
  static const int _blindGapMinutes     = 150;

  static HomeViewModel build({
    required int doc,
    required int feedsDone,
    required int maxFeeds,
    required DateTime? lastFeedTime,
    required Map<int, String> roundFeedStatus,
    required Map<int, bool> trayDone,
    required double consumedFeed,
    required double plannedFeed,
    required List<FeedHistoryLog> feedHistory,
    required List<TrayLog> trayLogs,
    required List<SamplingLog> growthLogs,
    required double currentAbw,  // 0 when no sample
    required double pondFcr,     // 0 when no data
    required int streak,
    required int seedCount,
  }) {
    final bool noData = feedHistory.isEmpty &&
        trayLogs.isEmpty &&
        growthLogs.isEmpty &&
        consumedFeed == 0;

    final double expectedAbw = getExpectedABW(doc);

    // ── Estimated ABW/FCR when no sampling exists ─────────────────────────────
    final bool abwIsEstimated = currentAbw <= 0;
    final double effectiveAbw = abwIsEstimated ? getExpectedABW(doc) : currentAbw;

    // Recalculate FCR using effectiveAbw so KPI is never blank
    final bool fcrIsEstimated = pondFcr <= 0 && abwIsEstimated;
    final double effectiveFcr = pondFcr > 0 ? pondFcr : _estimateFcr(doc);

    return HomeViewModel(
      isEmpty:    noData,
      alert:      _buildAlert(doc, feedsDone, maxFeeds, lastFeedTime, trayDone, roundFeedStatus, effectiveAbw, expectedAbw),
      kpis:       _buildKpis(doc, consumedFeed, plannedFeed, effectiveAbw, abwIsEstimated, effectiveFcr, fcrIsEstimated),
      growth:     _buildGrowth(doc, currentAbw, expectedAbw),
      waste:      _buildWaste(trayLogs),
      trend:      _buildTrend(feedHistory),
      activities: _buildActivities(feedHistory, trayLogs, growthLogs, expectedAbw),
      insight:    _buildInsight(doc, effectiveFcr, currentAbw, expectedAbw, _rollingWaste(trayLogs), streak, consumedFeed, plannedFeed),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ALERT  (strict priority — single source of truth)
  // ──────────────────────────────────────────────────────────────────────────

  static AlertData _buildAlert(
    int doc,
    int feedsDone,
    int maxFeeds,
    DateTime? lastFeedTime,
    Map<int, bool> trayDone,
    Map<int, String> roundFeedStatus,
    double currentAbw,
    double expectedAbw,
  ) {
    final now = DateTime.now();
    final int gap = doc >= 30 ? _smartGapMinutes : _blindGapMinutes;

    // 1. ALL DONE
    if (feedsDone >= maxFeeds) {
      return const AlertData(
        type: AlertType.allDone,
        icon: '✅',
        message: 'All feeds done today. Aeration running overnight.',
        bg: Color(0xFFF0FDF4), border: Color(0xFF86EFAC), textColor: Color(0xFF166534),
      );
    }

    // 2. FEED OVERDUE — gap cleared + 30 min past without a new feed
    if (lastFeedTime != null) {
      final elapsed = now.difference(lastFeedTime).inMinutes;
      if (elapsed >= gap + _overdueGraceMinutes) {
        return AlertData(
          type: AlertType.feedOverdue,
          icon: '🔴',
          message: 'Feed is overdue — ${elapsed - gap}m past the ideal window',
          bg: const Color(0xFFFFF1F2), border: const Color(0xFFFCA5A5), textColor: const Color(0xFF991B1B),
        );
      }

      // 3. GAP WAIT — inside required gap
      if (elapsed < gap) {
        final left = gap - elapsed;
        return AlertData(
          type: AlertType.gapWait,
          icon: '⏳',
          message: 'Next feed in ${left}m — shrimp still digesting',
          bg: const Color(0xFFFFFBEB), border: const Color(0xFFFDE68A), textColor: const Color(0xFF92400E),
        );
      }
    }

    // 4. TRAY PENDING — DOC ≥ 30 and last completed round has no tray
    final bool hasPendingTray = doc >= 30 &&
        roundFeedStatus.entries.any(
          (e) => e.value == 'completed' && !(trayDone[e.key] ?? false),
        );
    if (hasPendingTray) {
      return const AlertData(
        type: AlertType.trayPending,
        icon: '🔵',
        message: 'Check tray from last feed before next round',
        bg: Color(0xFFEFF6FF), border: Color(0xFFBFDBFE), textColor: Color(0xFF1E40AF),
      );
    }

    // 5. GROWTH SLOW — only when real sample exists
    if (currentAbw > 0 && expectedAbw > 0) {
      final ratio = currentAbw / expectedAbw;
      if (ratio < 0.85) {
        return AlertData(
          type: AlertType.growthSlow,
          icon: '⚠️',
          message: 'Growth slow — ${currentAbw.toStringAsFixed(1)}g vs ${expectedAbw.toStringAsFixed(1)}g ideal. Check water quality.',
          bg: const Color(0xFFFFF7ED), border: const Color(0xFFFED7AA), textColor: const Color(0xFF9A3412),
        );
      }
    }

    // 6. READY TO FEED (first feed of day or gap just cleared)
    if (lastFeedTime == null) {
      return AlertData(
        type: AlertType.readyToFeed,
        icon: '🟢',
        message: 'Start first feed of the day — Round 1 of $maxFeeds',
        bg: const Color(0xFFF0FDF4), border: const Color(0xFF86EFAC), textColor: const Color(0xFF166534),
      );
    }
    return AlertData(
      type: AlertType.readyToFeed,
      icon: '🟢',
      message: 'Ready — Round ${feedsDone + 1} of $maxFeeds',
      bg: const Color(0xFFF0FDF4), border: const Color(0xFF86EFAC), textColor: const Color(0xFF166534),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KPIs
  // ──────────────────────────────────────────────────────────────────────────

  static KPIData _buildKpis(
    int doc,
    double consumedFeed,
    double plannedFeed,
    double effectiveAbw,
    bool abwIsEstimated,
    double effectiveFcr,
    bool fcrIsEstimated,
  ) {
    return KPIData(
      feedToday:     consumedFeed,
      plannedToday:  plannedFeed,
      currentAbw:    effectiveAbw,
      abwIsEstimated: abwIsEstimated,
      fcr:           effectiveFcr,
      fcrIsEstimated: fcrIsEstimated,
      doc:           doc,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GROWTH
  // ──────────────────────────────────────────────────────────────────────────

  static GrowthData _buildGrowth(int doc, double currentAbw, double expectedAbw) {
    return GrowthData(
      currentAbw:  currentAbw,
      expectedAbw: expectedAbw,
      doc:         doc,
      hasData:     currentAbw > 0,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WASTE
  // ──────────────────────────────────────────────────────────────────────────

  static WasteData _buildWaste(List<TrayLog> trayLogs) {
    final pct = _rollingWaste(trayLogs);
    final hasData = trayLogs.any((l) => !l.isSkipped && l.trays.isNotEmpty);
    if (!hasData) {
      return const WasteData(wastePercent: 0, message: '', suggestedFeedFactor: 1.0, hasData: false);
    }
    return WasteData(
      wastePercent:        pct,
      message:             _wasteMessage(pct),
      suggestedFeedFactor: _wasteFactor(pct),
      hasData:             true,
    );
  }

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

  static String _wasteMessage(double pct) {
    if (pct < 5)  return 'Feed waste is perfect — shrimp eating everything';
    if (pct < 10) return 'Slight overfeeding — tray shows small leftover';
    if (pct < 20) return 'Moderate waste (${pct.round()}%) — reduce next feed by 5–10%';
    return 'High waste (${pct.round()}%) — strong correction needed';
  }

  static double _wasteFactor(double pct) {
    if (pct < 5)  return 1.00;
    if (pct < 10) return 0.97;
    if (pct < 20) return 0.93;
    return 0.88;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FEED TREND
  // ──────────────────────────────────────────────────────────────────────────

  static FeedTrendData _buildTrend(List<FeedHistoryLog> history) {
    final points = history.take(7).toList().reversed.toList();
    if (points.length < 2) {
      return const FeedTrendData(actual: [], ideal: [], insight: '', hasData: false);
    }
    final actual = points.map((l) => l.total).toList();
    final ideal  = points.map((l) => l.expected).toList();

    final avgA = actual.fold(0.0, (s, v) => s + v) / actual.length;
    final avgI = ideal.fold(0.0, (s, v) => s + v) / ideal.length;
    final String insight;
    if (avgI <= 0) {
      insight = '';
    } else {
      final diff = ((avgA - avgI) / avgI * 100).round();
      if (diff > 8) {
        insight = 'Feeding $diff% above ideal';
      } else if (diff < -8) {
        insight = 'Feeding ${diff.abs()}% below ideal';
      } else {
        insight = 'Feed aligned with growth ✅';
      }
    }
    return FeedTrendData(actual: actual, ideal: ideal, insight: insight, hasData: true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ACTIVITIES (with context tags)
  // ──────────────────────────────────────────────────────────────────────────

  static List<ActivityItem> _buildActivities(
    List<FeedHistoryLog> feedHistory,
    List<TrayLog> trayLogs,
    List<SamplingLog> growthLogs,
    double expectedAbw,
  ) {
    final list = <ActivityItem>[];

    for (final log in feedHistory.take(7)) {
      if (log.total <= 0) continue;
      final tag = _feedTag(log.total, log.expected);
      list.add(ActivityItem(
        icon: '🍽',
        label: 'Fed ${log.total.toStringAsFixed(1)} kg',
        contextTag: tag,
        sub: 'DOC ${log.doc}',
        time: log.date,
        color: const Color(0xFF16A34A),
      ));
    }

    for (final log in trayLogs.where((l) => !l.isSkipped).take(7)) {
      final majority = _trayMajority(log);
      final tag = _trayTag(log);
      list.add(ActivityItem(
        icon: '📊',
        label: 'Tray — $majority',
        contextTag: tag,
        sub: 'DOC ${log.doc}, R${log.round}',
        time: log.time,
        color: const Color(0xFF7C3AED),
      ));
    }

    for (final log in growthLogs.take(3)) {
      final ratio = expectedAbw > 0 ? log.abw / expectedAbw : 0.0;
      final tag = ratio > 0 ? _growthTag(ratio) : null;
      list.add(ActivityItem(
        icon: '📏',
        label: 'Sample: ${log.abw.toStringAsFixed(1)} g ABW',
        contextTag: tag,
        sub: 'DOC ${log.doc}',
        time: log.date,
        color: const Color(0xFF2563EB),
      ));
    }

    list.sort((a, b) => b.time.compareTo(a.time));
    return list.take(5).toList();
  }

  static String? _feedTag(double actual, double ideal) {
    if (ideal <= 0) return null;
    final diff = (actual - ideal) / ideal;
    if (diff > 0.08) return '↑ above ideal';
    if (diff < -0.08) return '↓ below ideal';
    return '✓ on track';
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

  static String? _growthTag(double ratio) {
    if (ratio < 0.85) return '⚠️ growth slow';
    if (ratio > 1.20) return '✅ ahead of curve';
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SMART INSIGHT (priority-ordered, one message)
  // ──────────────────────────────────────────────────────────────────────────

  static InsightData? _buildInsight(
    int doc,
    double fcr,
    double currentAbw,
    double expectedAbw,
    double wastePercent,
    int streak,
    double consumedFeed,
    double plannedFeed,
  ) {
    // 1. Feed correction opportunity (FCR too high) — show concrete overfeeding %
    if (fcr > 1.4) {
      final overpct = ((fcr - 1.4) / 1.4 * 100).round();
      final feedCtx = consumedFeed > 0 && plannedFeed > 0
          ? ' (${consumedFeed.toStringAsFixed(1)} kg consumed vs ${plannedFeed.toStringAsFixed(1)} kg planned)'
          : '';
      return InsightData(
        'Overfeeding by ~$overpct%$feedCtx — reduce feed 5–10% to improve FCR',
      );
    }

    // 2. Growth issue — show actual vs expected with numbers
    if (currentAbw > 0 && expectedAbw > 0 && currentAbw / expectedAbw < 0.85) {
      final gap = (expectedAbw - currentAbw).toStringAsFixed(1);
      return InsightData(
        'Growth slow: ${currentAbw.toStringAsFixed(1)} g vs ${expectedAbw.toStringAsFixed(1)} g ideal (−$gap g at DOC $doc) — check water & aeration',
      );
    }

    // 3. FCR warning — show exact number vs target
    if (fcr > 1.2 && fcr <= 1.4) {
      return InsightData(
        'FCR ${fcr.toStringAsFixed(2)} vs target 1.2 — tighten tray checks to bring it down',
      );
    }

    // 4. High waste — show % with consequence
    if (wastePercent > 20) {
      return InsightData(
        '${wastePercent.round()}% tray leftover on average — reduce next feed by 8% to cut FCR',
      );
    }

    // 5. Positive reinforcement — show exact FCR and what it means
    if (fcr > 0 && fcr <= 1.2) {
      return InsightData(
        'FCR ${fcr.toStringAsFixed(2)} ✅ — on target. Keep this schedule for a strong harvest.',
      );
    }

    // 6. Streak praise
    if (streak >= 5) {
      return InsightData(
        '$streak-day feeding streak — consistent timing is your best FCR tool',
      );
    }

    return null; // not enough data
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ESTIMATION FALLBACKS
  // ──────────────────────────────────────────────────────────────────────────

  /// Rough FCR estimate when no real data. Improves as culture matures.
  static double _estimateFcr(int doc) {
    if (doc < 30) return 0;   // too early to estimate meaningfully
    if (doc < 60) return 1.3;
    return 1.4;
  }
}
