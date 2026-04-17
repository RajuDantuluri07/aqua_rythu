/// IE-1 to IE-5: Insight Engine — rule-based farm intelligence.
library;

enum InsightSeverity { critical, warning, info, positive }

/// IE-5: Insight UI contract.
class Insight {
  final String title;
  final String action;
  final InsightSeverity severity;

  const Insight({
    required this.title,
    required this.action,
    required this.severity,
  });
}

class InsightEngine {
  InsightEngine._();

  // IE-3: Health Score — four sub-components, 0–100 output.
  static int computeHealthScore({
    required double fcr,
    required double currentAbw,
    required double expectedAbw,
    required double wastePercent,
    required int streak,
  }) {
    int score = 100;

    // Growth component (−30 max)
    if (currentAbw > 0 && expectedAbw > 0) {
      final ratio = currentAbw / expectedAbw;
      if (ratio < 0.75) {
        score -= 30;
      } else if (ratio < 0.85) {
        score -= 20;
      } else if (ratio < 0.92) {
        score -= 10;
      }
    }

    // Feed / FCR component (−30 max)
    if (fcr > 2.0) {
      score -= 30;
    } else if (fcr > 1.8) {
      score -= 20;
    } else if (fcr > 1.5) {
      score -= 10;
    } else if (fcr > 1.3) {
      score -= 5;
    }

    // Consistency component (−20 max)
    if (streak < 2) {
      score -= 20;
    } else if (streak < 5) {
      score -= 10;
    } else if (streak < 8) {
      score -= 5;
    }

    // Risk / Waste component (−20 max)
    if (wastePercent > 40) {
      score -= 20;
    } else if (wastePercent > 20) {
      score -= 10;
    } else if (wastePercent > 10) {
      score -= 5;
    }

    return score.clamp(0, 100);
  }

  // IE-2 & IE-4: Generate up to 3 insights, sorted by severity.
  static List<Insight> generate({
    required int doc,
    required double fcr,
    required double currentAbw,
    required double expectedAbw,
    required double wastePercent,
    required int streak,
    required int healthScore,
    required bool hasSamplingData,
    required DateTime? lastSampleDate,
    required double consumedFeed,
    required double plannedFeed,
  }) {
    final raw = <_Ranked>[];

    // ── Rule 5: High Risk (health score < 40) — highest priority ───────────
    if (healthScore < 40) {
      raw.add(_Ranked(100, Insight(
        title: 'High risk — act now',
        action: 'Farm health score is $healthScore/100. Check FCR, growth, and water quality immediately.',
        severity: InsightSeverity.critical,
      )));
    }

    // ── Rule 1: No Sampling after DOC 35 ───────────────────────────────────
    if (doc > 35 && !hasSamplingData) {
      raw.add(_Ranked(95, Insight(
        title: 'Sampling required (DOC $doc)',
        action: 'No ABW data recorded. Take a sample today to enable smart feed adjustments.',
        severity: InsightSeverity.critical,
      )));
    } else if (doc > 35 && lastSampleDate != null) {
      final daysSince = DateTime.now().difference(lastSampleDate).inDays;
      if (daysSince > 10) {
        raw.add(_Ranked(85, Insight(
          title: 'Sample overdue ($daysSince days)',
          action: 'Last sampling was $daysSince days ago. Sample now to keep smart feed accurate.',
          severity: InsightSeverity.warning,
        )));
      }
    }

    // ── Rule 2: Overfeeding — FCR > 1.8 OR tray waste > 30% ───────────────
    if (fcr > 1.8) {
      final cut = ((fcr - 1.4) / 1.4 * 100).round().clamp(5, 30);
      raw.add(_Ranked(90, Insight(
        title: 'Overfeeding detected (FCR ${fcr.toStringAsFixed(2)})',
        action: 'Reduce feed by ~$cut% to improve FCR. Monitor tray after next round.',
        severity: InsightSeverity.critical,
      )));
    } else if (wastePercent > 30) {
      raw.add(_Ranked(78, Insight(
        title: '${wastePercent.round()}% tray leftover — overfeeding',
        action: 'High waste detected. Reduce next feed by 8–10% to cut FCR loss.',
        severity: InsightSeverity.warning,
      )));
    } else if (fcr > 1.4) {
      final cut = ((fcr - 1.4) / 1.4 * 100).round().clamp(3, 15);
      raw.add(_Ranked(65, Insight(
        title: 'FCR rising (${fcr.toStringAsFixed(2)})',
        action: 'Reduce feed by ~$cut% and tighten tray monitoring to bring FCR down.',
        severity: InsightSeverity.warning,
      )));
    }

    // ── Rule 4: Slow Growth ─────────────────────────────────────────────────
    if (currentAbw > 0 && expectedAbw > 0) {
      final ratio = currentAbw / expectedAbw;
      if (ratio < 0.85) {
        final gap = (expectedAbw - currentAbw).toStringAsFixed(1);
        raw.add(_Ranked(80, Insight(
          title: 'Growth slow — ${currentAbw.toStringAsFixed(1)} g vs ${expectedAbw.toStringAsFixed(1)} g',
          action: 'ABW is $gap g behind target at DOC $doc. Check water quality and aeration.',
          severity: InsightSeverity.warning,
        )));
      } else if (ratio < 0.92) {
        final gap = (expectedAbw - currentAbw).toStringAsFixed(1);
        raw.add(_Ranked(50, Insight(
          title: 'Growth slightly below target',
          action: 'ABW is $gap g behind expected at DOC $doc. Monitor water quality.',
          severity: InsightSeverity.info,
        )));
      }

      // ── Rule 3: Feed Increase — good growth + clean trays ────────────────
      if (ratio > 1.10 && wastePercent < 10 && fcr > 0 && fcr <= 1.2) {
        final upPct = ((ratio - 1.0) * 100).round().clamp(3, 10);
        raw.add(_Ranked(55, Insight(
          title: 'Strong growth — consider +$upPct% feed',
          action: 'ABW is ${((ratio - 1) * 100).round()}% above target and trays are clean. Safely increase feed.',
          severity: InsightSeverity.positive,
        )));
      }
    }

    // ── Positive: on-target FCR + healthy growth ───────────────────────────
    if (fcr > 0 && fcr <= 1.2) {
      final growthOk = currentAbw <= 0 ||
          expectedAbw <= 0 ||
          (currentAbw / expectedAbw) >= 0.92;
      if (growthOk) {
        raw.add(_Ranked(30, Insight(
          title: 'On track — FCR ${fcr.toStringAsFixed(2)} ✅',
          action: 'Growth and feed efficiency are on target. Keep this schedule for a strong harvest.',
          severity: InsightSeverity.positive,
        )));
      }
    }

    // ── Streak praise (only when no issues found) ──────────────────────────
    if (raw.every((r) => r.insight.severity == InsightSeverity.positive || r.weight < 40)
        && streak >= 7) {
      raw.add(_Ranked(20, Insight(
        title: '$streak-day feeding streak',
        action: 'Consistent timing is your best FCR tool. Keep it up!',
        severity: InsightSeverity.positive,
      )));
    }

    // IE-4: Sort by weight desc, return max 3.
    raw.sort((a, b) => b.weight.compareTo(a.weight));
    return raw.take(3).map((r) => r.insight).toList();
  }
}

class _Ranked {
  final int weight;
  final Insight insight;
  const _Ranked(this.weight, this.insight);
}
