import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ALERT
// ══════════════════════════════════════════════════════════════════════════════

/// Strict priority (lowest index = highest priority):
///   allDone → feedOverdue → gapWait → trayPending → growthSlow → readyToFeed → firstOpen
enum AlertType {
  allDone,      // All rounds complete today
  feedOverdue,  // Gap cleared + 30 min grace elapsed without feeding
  gapWait,      // Inside the required gap between rounds
  trayPending,  // DOC > 30: last fed round has no tray logged
  growthSlow,   // ABW < 85% of expected
  readyToFeed,  // Gap cleared, window open — feed now
  firstOpen,    // No feed data yet (brand new pond/day)
}

class AlertData {
  final AlertType type;
  final String icon;
  final String message;
  final Color bg;
  final Color border;
  final Color textColor;

  const AlertData({
    required this.type,
    required this.icon,
    required this.message,
    required this.bg,
    required this.border,
    required this.textColor,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// KPIs
// ══════════════════════════════════════════════════════════════════════════════

class KPIData {
  final double feedToday;
  final double plannedToday;
  final double currentAbw;

  /// True when ABW comes from DOC-based estimation, not a real sample.
  final bool abwIsEstimated;

  final double fcr;

  /// True when FCR is computed from estimated ABW (not a real sample).
  final bool fcrIsEstimated;

  final int doc;

  const KPIData({
    required this.feedToday,
    required this.plannedToday,
    required this.currentAbw,
    required this.abwIsEstimated,
    required this.fcr,
    required this.fcrIsEstimated,
    required this.doc,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// GROWTH
// ══════════════════════════════════════════════════════════════════════════════

class GrowthData {
  final double currentAbw;
  final double expectedAbw;
  final int doc;
  final bool hasData;

  const GrowthData({
    required this.currentAbw,
    required this.expectedAbw,
    required this.doc,
    required this.hasData,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// WASTE
// ══════════════════════════════════════════════════════════════════════════════

class WasteData {
  final double wastePercent;
  final String message;

  /// Feed multiplier to apply next round.
  /// 1.00 = no change, 0.93 = reduce 7%, etc.
  final double suggestedFeedFactor;

  final bool hasData;

  const WasteData({
    required this.wastePercent,
    required this.message,
    required this.suggestedFeedFactor,
    required this.hasData,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// FEED TREND
// ══════════════════════════════════════════════════════════════════════════════

class FeedTrendData {
  /// Actual feed per day, oldest → newest.
  final List<double> actual;

  /// Ideal/planned feed per day, oldest → newest (same length as actual).
  final List<double> ideal;

  final String insight;
  final bool hasData;

  const FeedTrendData({
    required this.actual,
    required this.ideal,
    required this.insight,
    required this.hasData,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVITY
// ══════════════════════════════════════════════════════════════════════════════

class ActivityItem {
  final String icon;
  final String label;

  /// One-line context: e.g. "↑ above ideal", "⚠️ leftover high".
  /// Null = no additional context.
  final String? contextTag;

  final String sub;
  final DateTime time;
  final Color color;

  const ActivityItem({
    required this.icon,
    required this.label,
    this.contextTag,
    required this.sub,
    required this.time,
    required this.color,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// INSIGHT
// ══════════════════════════════════════════════════════════════════════════════

class InsightData {
  final String message;

  const InsightData(this.message);
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME VIEW MODEL
// ══════════════════════════════════════════════════════════════════════════════

/// Single struct passed to every home section widget.
/// All fields are pre-computed by HomeBuilder — widgets contain zero logic.
class HomeViewModel {
  final AlertData alert;
  final KPIData kpis;
  final GrowthData growth;
  final WasteData waste;
  final FeedTrendData trend;
  final List<ActivityItem> activities;
  final InsightData? insight;

  /// True when the pond has no feed/tray/growth data at all.
  final bool isEmpty;

  const HomeViewModel({
    required this.alert,
    required this.kpis,
    required this.growth,
    required this.waste,
    required this.trend,
    required this.activities,
    required this.isEmpty,
    this.insight,
  });
}
