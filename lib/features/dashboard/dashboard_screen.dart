import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aqua_rythu/features/farm/farm_provider.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:aqua_rythu/features/feed/feed_history_provider.dart';
import 'package:aqua_rythu/features/growth/growth_provider.dart';
import 'package:aqua_rythu/features/growth/sampling_log.dart';

// ── Design constants (matches pond dashboard light theme) ─────────────────────
const _bgDark      = Color(0xFFF5F7FA);
const _cardDark    = Colors.white;
const _cardDark2   = Color(0xFFF8FAFC);
const _borderDark  = Color(0xFFE2E8F0);
const _textPrimary = Color(0xFF1E293B);
const _textSub     = Color(0xFF64748B);
const _accentGreen = Color(0xFF16A34A);
const _accentBlue  = Color(0xFF2563EB);
const _red         = Color(0xFFEF4444);
const _amber       = Color(0xFFF59E0B);
const _costPerKg   = 60.0;   // shrimp feed cost ₹/kg
const _pricePerKg  = 220.0;  // shrimp market price ₹/kg

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState    = ref.watch(farmProvider);
    final currentFarm  = farmState.currentFarm;
    final feedHistory  = ref.watch(feedHistoryProvider);

    if (currentFarm == null) return _noFarmView(context);

    final ponds       = currentFarm.ponds.where((p) => p.status.name == 'active').toList();
    final activePonds = ponds.length;

    // ── Per-pond data ─────────────────────────────────────────────────────────
    final List<_PondSummary> summaries = ponds.map((pond) {
      final doc        = ref.watch(docProvider(pond.id));
      final growthLogs = ref.watch(growthProvider(pond.id));
      final logs       = feedHistory[pond.id] ?? [];

      final double abw = growthLogs.isNotEmpty
          ? growthLogs.first.abw
          : (pond.currentAbw ?? 0.0);

      // survival estimate
      double survival = 1.0;
      if (doc > 60)      survival = 0.90;
      else if (doc > 30) survival = 0.95;

      final double biomass = (pond.seedCount * survival * abw) / 1000;
      final double totalFeed = logs.isNotEmpty ? logs.first.cumulative : 0.0;
      final double fcr   = biomass > 0.1 ? totalFeed / biomass : 0.0;

      final double cropValue  = biomass * _pricePerKg;
      final double feedCost   = totalFeed * _costPerKg;
      final double pondProfit = cropValue - feedCost;

      // DOC prev week ABW for delta
      double? prevAbw;
      if (growthLogs.length >= 2) {
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final older = growthLogs.where((l) => l.date.isBefore(weekAgo)).firstOrNull;
        prevAbw = older?.abw ?? growthLogs.last.abw;
      }

      // FCR trend (last 7 days) — compute daily cumulative FCR from feed history
      final List<_FCRPoint> fcrTrend = _buildFcrTrend(logs, growthLogs, pond.seedCount);

      // Status
      String status = 'On Track';
      if (fcr > 1.8)       status = 'Critical';
      else if (fcr > 1.5)  status = 'Slow';
      else if (abw > 0 && _growthDeltaPerWeek(growthLogs) < 1.0) status = 'Slow';

      return _PondSummary(
        id:         pond.id,
        name:       pond.name,
        doc:        doc,
        abw:        abw,
        prevAbw:    prevAbw,
        fcr:        fcr,
        seedCount:  pond.seedCount,
        totalFeed:  totalFeed,
        survival:   survival * 100,
        biomass:    biomass,
        cropValue:  cropValue,
        feedCost:   feedCost,
        profit:     pondProfit,
        status:     status,
        fcrTrend:   fcrTrend,
        area:       pond.area,
      );
    }).toList();

    // ── Farm-level aggregates ─────────────────────────────────────────────────
    double totalBiomass  = summaries.fold(0.0, (s, p) => s + p.biomass);
    double totalFeedFarm = summaries.fold(0.0, (s, p) => s + p.totalFeed);
    double totalCropVal  = summaries.fold(0.0, (s, p) => s + p.cropValue);
    double totalProfit   = summaries.fold(0.0, (s, p) => s + p.profit);
    double avgAbw        = summaries.isNotEmpty
        ? summaries.fold(0.0, (s, p) => s + p.abw) / summaries.length
        : 0.0;
    double avgSurvival   = summaries.isNotEmpty
        ? summaries.fold(0.0, (s, p) => s + p.survival) / summaries.length
        : 0.0;
    double farmFcr       = totalBiomass > 0.1 ? totalFeedFarm / totalBiomass : 0.0;

    // Feed today (across all ponds)
    double feedToday = 0.0;
    int roundsToday  = 0;
    for (final pond in ponds) {
      final logs = feedHistory[pond.id] ?? [];
      if (logs.isNotEmpty) {
        final today = DateTime.now();
        final first = logs.first;
        if (first.date.year == today.year &&
            first.date.month == today.month &&
            first.date.day == today.day) {
          feedToday  += first.total;
          roundsToday += first.rounds.where((r) => r > 0).length;
        }
      }
    }

    // Farm health score (0–100)
    int healthScore = _computeHealthScore(farmFcr, avgSurvival, summaries);

    // Alerts
    final List<_Alert> alerts = _buildAlerts(summaries);

    // ABW delta this week
    double avgAbwDelta = summaries.isNotEmpty
        ? summaries
            .where((p) => p.prevAbw != null && p.abw > 0)
            .fold(0.0, (s, p) => s + (p.abw - (p.prevAbw ?? p.abw))) /
            math.max(1, summaries.where((p) => p.prevAbw != null).length)
        : 0.0;

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _bgDark,
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────────────────────────
              _buildHeader(context, ref, farmState, currentFarm, activePonds, now),

              // ── BODY ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Farm Health gauge + 4 KPIs
                    _buildHealthAndKpiSection(
                      healthScore: healthScore,
                      totalCropVal: totalCropVal,
                      totalProfit: totalProfit,
                      feedToday: feedToday,
                      roundsToday: roundsToday,
                      farmFcr: farmFcr,
                    ),

                    const SizedBox(height: 20),

                    // Key Metrics row
                    _buildKeyMetrics(
                      totalBiomass: totalBiomass,
                      avgAbw: avgAbw,
                      avgAbwDelta: avgAbwDelta,
                      avgDoc: summaries.isNotEmpty
                          ? summaries.fold(0, (s, p) => s + p.doc) ~/
                              summaries.length
                          : 0,
                      avgSurvival: avgSurvival,
                      totalFeedCost: summaries.fold(0.0, (s, p) => s + p.feedCost),
                    ),

                    const SizedBox(height: 20),

                    // Active Alerts
                    if (alerts.isNotEmpty) ...[
                      _sectionLabel('ACTIVE ALERTS'),
                      const SizedBox(height: 10),
                      ...alerts.map((a) => _AlertCard(alert: a)),
                      const SizedBox(height: 20),
                    ],

                    // Pond Status
                    if (summaries.isNotEmpty) ...[
                      _sectionLabel('POND STATUS'),
                      const SizedBox(height: 10),
                      _buildPondStatusGrid(context, ref, currentFarm.id, summaries),
                      const SizedBox(height: 20),
                    ],

                    // FCR Trend
                    if (summaries.any((s) => s.fcrTrend.length >= 2)) ...[
                      _sectionLabel('FCR TREND — LAST 7 DAYS'),
                      const SizedBox(height: 10),
                      _FcrTrendChart(summaries: summaries),
                      const SizedBox(height: 20),
                    ],

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, WidgetRef ref, FarmState farmState,
      dynamic currentFarm, int activePonds, DateTime now) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        border: Border(bottom: BorderSide(color: _borderDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AQUARYTHU — FARM INTELLIGENCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _textSub,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                DateFormat('d MMM yyyy').format(now),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _FarmDropdown(
                  farmState: farmState,
                  currentFarmName: currentFarm.name,
                  onSelect: (id) =>
                      ref.read(farmProvider.notifier).selectFarm(id),
                  onAddFarm: () =>
                      Navigator.pushNamed(context, AppRoutes.addFarm),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _accentGreen.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$activePonds active ponds',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _accentGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _accentGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Live sync',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _accentGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── HEALTH + KPI SECTION ───────────────────────────────────────────────────
  Widget _buildHealthAndKpiSection({
    required int healthScore,
    required double totalCropVal,
    required double totalProfit,
    required double feedToday,
    required int roundsToday,
    required double farmFcr,
  }) {
    final double margin =
        totalCropVal > 0 ? (totalProfit / totalCropVal * 100) : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Farm Health Gauge
        _FarmHealthGauge(score: healthScore),
        const SizedBox(width: 12),
        // 2×2 KPI grid
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      label: 'CROP VALUE',
                      value: _formatCurrency(totalCropVal),
                      sub: totalCropVal > 0 ? '≈ market price' : 'No data',
                      subColor: _accentGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiTile(
                      label: 'EST. PROFIT',
                      value: _formatCurrency(totalProfit),
                      sub: totalCropVal > 0
                          ? 'Margin ${margin.toStringAsFixed(1)}%'
                          : 'No data',
                      subColor: totalProfit >= 0 ? _accentGreen : _red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _KpiTile(
                      label: 'FEED TODAY',
                      value: feedToday > 0
                          ? '${feedToday.toStringAsFixed(0)} kg'
                          : '--',
                      sub: roundsToday > 0
                          ? '$roundsToday rounds logged'
                          : 'No rounds yet',
                      subColor: _textSub,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _KpiTile(
                      label: 'OVERALL FCR',
                      value:
                          farmFcr > 0 ? farmFcr.toStringAsFixed(2) : '--',
                      sub: farmFcr > 0
                          ? (farmFcr <= 1.4
                              ? 'On target 1.4'
                              : 'Above target 1.4')
                          : 'No data',
                      subColor: farmFcr > 0
                          ? (farmFcr <= 1.4 ? _accentGreen : _amber)
                          : _textSub,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── KEY METRICS ────────────────────────────────────────────────────────────
  Widget _buildKeyMetrics({
    required double totalBiomass,
    required double avgAbw,
    required double avgAbwDelta,
    required int avgDoc,
    required double avgSurvival,
    required double totalFeedCost,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEY METRICS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _textSub,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetricItem(
                label: 'Biomass',
                value: totalBiomass > 0
                    ? '${totalBiomass.toStringAsFixed(0)} kg'
                    : '--',
                sub: 'total',
              ),
              _MetricDivider(),
              _MetricItem(
                label: 'Avg ABW',
                value: avgAbw > 0 ? '${avgAbw.toStringAsFixed(1)}g' : '--',
                sub: avgAbwDelta != 0
                    ? '${avgAbwDelta >= 0 ? '+' : ''}${avgAbwDelta.toStringAsFixed(1)}g / $avgDoc'
                    : 'DOC $avgDoc',
              ),
              _MetricDivider(),
              _MetricItem(
                label: 'Survival',
                value:
                    avgSurvival > 0 ? '${avgSurvival.toStringAsFixed(0)}%' : '--',
                sub: 'target >80%',
                valueColor: avgSurvival >= 80 ? _accentGreen : _amber,
              ),
              _MetricDivider(),
              _MetricItem(
                label: 'Feed Cost',
                value: totalFeedCost > 0
                    ? _formatCurrency(totalFeedCost)
                    : '--',
                sub: 'cumulative',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── POND STATUS GRID ───────────────────────────────────────────────────────
  Widget _buildPondStatusGrid(BuildContext context, WidgetRef ref,
      String farmId, List<_PondSummary> summaries) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summaries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, i) => _PondStatusCard(
        summary: summaries[i],
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.pondDashboard,
          arguments: summaries[i].id,
        ),
        onEdit: () => Navigator.pushNamed(
          context,
          AppRoutes.editPond,
          arguments: summaries[i].id,
        ),
        onDelete: () => _confirmDelete(context, summaries[i].name, () async {
          try {
            await ref
                .read(farmProvider.notifier)
                .deletePond(farmId, summaries[i].id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete pond: $e')),
              );
            }
          }
        }),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  static Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _textSub,
          letterSpacing: 1.2,
        ),
      );

  static String _formatCurrency(double v) {
    if (v.abs() >= 100000) {
      return '₹${(v / 100000).toStringAsFixed(1)}L';
    } else if (v.abs() >= 1000) {
      return '₹${(v / 1000).toStringAsFixed(1)}K';
    }
    return '₹${v.toStringAsFixed(0)}';
  }

  static int _computeHealthScore(
      double fcr, double survival, List<_PondSummary> summaries) {
    int score = 100;
    if (fcr > 2.0)       score -= 25;
    else if (fcr > 1.8)  score -= 18;
    else if (fcr > 1.5)  score -= 10;
    else if (fcr > 1.3)  score -= 5;

    if (survival < 70)   score -= 20;
    else if (survival < 80) score -= 10;
    else if (survival < 85) score -= 5;

    final critCount = summaries.where((s) => s.status == 'Critical').length;
    final slowCount = summaries.where((s) => s.status == 'Slow').length;
    score -= critCount * 12;
    score -= slowCount * 5;

    return score.clamp(0, 100);
  }

  static List<_Alert> _buildAlerts(List<_PondSummary> summaries) {
    final alerts = <_Alert>[];
    for (final p in summaries) {
      if (p.fcr > 1.8) {
        alerts.add(_Alert(
          title: 'High FCR in ${p.name}',
          body:
              'FCR ${p.fcr.toStringAsFixed(1)} — reduce feed by 8% in next round',
          type: _AlertType.critical,
        ));
      } else if (p.fcr > 1.5) {
        alerts.add(_Alert(
          title: 'Elevated FCR in ${p.name}',
          body: 'FCR ${p.fcr.toStringAsFixed(1)} — tighten tray checks',
          type: _AlertType.warning,
        ));
      }
      if (p.prevAbw != null &&
          p.abw > 0 &&
          _growthDeltaForPond(p) < 1.0) {
        alerts.add(_Alert(
          title: 'Slow growth in ${p.name}',
          body: 'ABW gain below 1g/week — check aeration',
          type: _AlertType.warning,
        ));
      }
    }
    return alerts.take(4).toList();
  }

  static double _growthDeltaForPond(_PondSummary p) {
    if (p.prevAbw == null) return 999.0;
    return p.abw - (p.prevAbw ?? p.abw);
  }

  static double _growthDeltaPerWeek(List<SamplingLog> logs) {
    if (logs.isEmpty) return 999.0;
    if (logs.length == 1) return 0.0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final older = logs.where((l) => l.date.isBefore(weekAgo)).firstOrNull;
    if (older == null) return logs.first.abw - logs.last.abw;
    return logs.first.abw - older.abw;
  }

  static List<_FCRPoint> _buildFcrTrend(List<FeedHistoryLog> feedLogs,
      List<SamplingLog> growthLogs, int seedCount) {
    final result = <_FCRPoint>[];
    final last7 =
        feedLogs.take(7).toList().reversed.toList(); // oldest → newest
    for (final log in last7) {
      final double abw = _abwAtDoc(growthLogs, log.doc) ?? 0;
      double survival = 1.0;
      if (log.doc > 60)      survival = 0.90;
      else if (log.doc > 30) survival = 0.95;
      final double biomass = (seedCount * survival * abw) / 1000;
      final double fcr = biomass > 0.1 ? log.cumulative / biomass : 0;
      if (fcr > 0) result.add(_FCRPoint(date: log.date, fcr: fcr));
    }
    return result;
  }

  static double? _abwAtDoc(List<SamplingLog> logs, int doc) {
    if (logs.isEmpty) return null;
    SamplingLog? closest;
    int bestDiff = 9999;
    for (final l in logs) {
      final diff = (l.doc - doc).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = l;
      }
    }
    return closest?.abw;
  }

  void _confirmDelete(
      BuildContext context, String pondName, VoidCallback onConfirmed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pond'),
        content: Text(
            "Delete '$pondName'? This cannot be undone if the pond has no feed or harvest data."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirmed();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _noFarmView(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dashboard_customize_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'No Farm Selected',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create or select a farm to get started.',
                style: TextStyle(color: _textSub),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.addFarm),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.black),
                child: const Text('Create Farm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class _PondSummary {
  final String id, name, status;
  final int doc, seedCount;
  final double abw, fcr, survival, biomass, cropValue, feedCost, profit,
      totalFeed, area;
  final double? prevAbw;
  final List<_FCRPoint> fcrTrend;

  const _PondSummary({
    required this.id,
    required this.name,
    required this.doc,
    required this.abw,
    this.prevAbw,
    required this.fcr,
    required this.seedCount,
    required this.totalFeed,
    required this.survival,
    required this.biomass,
    required this.cropValue,
    required this.feedCost,
    required this.profit,
    required this.status,
    required this.fcrTrend,
    required this.area,
  });
}

class _FCRPoint {
  final DateTime date;
  final double fcr;
  const _FCRPoint({required this.date, required this.fcr});
}

enum _AlertType { critical, warning }

class _Alert {
  final String title, body;
  final _AlertType type;
  const _Alert({required this.title, required this.body, required this.type});
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── Farm Health Gauge ─────────────────────────────────────────────────────────
class _FarmHealthGauge extends StatelessWidget {
  final int score;
  const _FarmHealthGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    final label = score >= 85
        ? 'Excellent'
        : score >= 70
            ? 'Good'
            : score >= 50
                ? 'Fair'
                : 'Critical';
    final color = score >= 70 ? _accentGreen : score >= 50 ? _amber : _red;

    return Container(
      width: 100,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _GaugePainter(score: score, color: color),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'FARM HEALTH',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: _textSub,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;
  const _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      Paint()
        ..color = const Color(0xFF252D3D)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc
    final sweep = sweepTotal * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score;
}

// ── KPI Tile ─────────────────────────────────────────────────────────────────
class _KpiTile extends StatelessWidget {
  final String label, value, sub;
  final Color subColor;
  const _KpiTile(
      {required this.label,
      required this.value,
      required this.sub,
      required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _textSub,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric Item ───────────────────────────────────────────────────────────────
class _MetricItem extends StatelessWidget {
  final String label, value, sub;
  final Color? valueColor;
  const _MetricItem(
      {required this.label,
      required this.value,
      required this.sub,
      this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _textSub,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: valueColor ?? _textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(
                  fontSize: 9,
                  color: _textSub,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: _borderDark,
      );
}

// ── Alert Card ────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final _Alert alert;
  const _AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isCritical = alert.type == _AlertType.critical;
    final bgColor = isCritical
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFFFFBEB);
    final borderColor = isCritical
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFFDE68A);
    final badgeColor = isCritical ? _red : _amber;
    final badgeLabel = isCritical ? 'Critical' : 'Warning';
    final icon = isCritical ? Icons.warning_rounded : Icons.info_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: badgeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.body,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pond Status Card ──────────────────────────────────────────────────────────
class _PondStatusCard extends StatelessWidget {
  final _PondSummary summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PondStatusCard({
    required this.summary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = summary.status == 'On Track'
        ? _accentGreen
        : summary.status == 'Critical'
            ? _red
            : _amber;

    final seedStr = summary.seedCount >= 100000
        ? '${(summary.seedCount / 100000).toStringAsFixed(1)}L'
        : summary.seedCount >= 1000
            ? '${(summary.seedCount / 1000).toStringAsFixed(0)}K'
            : '${summary.seedCount}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row — name + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    summary.status,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Area · DOC + 3-dot menu
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${summary.area.toStringAsFixed(1)} ac  ·  DOC ${summary.doc}',
                    style: const TextStyle(
                        fontSize: 10,
                        color: _textSub,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.more_horiz_rounded,
                        size: 16, color: _textSub),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 15),
                            SizedBox(width: 8),
                            Text('Edit Pond', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 15, color: _red),
                            SizedBox(width: 8),
                            Text('Delete Pond',
                                style: TextStyle(
                                    fontSize: 13, color: _red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Metrics 2×2
            Row(
              children: [
                _PondMetric(label: 'HBW', value: summary.abw > 0 ? '${summary.abw.toStringAsFixed(0)}g' : '--'),
                const SizedBox(width: 8),
                _PondMetric(label: 'FCR', value: summary.fcr > 0 ? summary.fcr.toStringAsFixed(1) : '--',
                    valueColor: summary.fcr > 1.5 ? _red : summary.fcr > 1.3 ? _amber : null),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _PondMetric(label: 'SEED', value: seedStr),
                const SizedBox(width: 8),
                _PondMetric(
                    label: 'FEED',
                    value: summary.totalFeed > 0
                        ? '${summary.totalFeed.toStringAsFixed(0)}kg'
                        : '--'),
              ],
            ),
            const SizedBox(height: 10),
            // Survival bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Survival',
                        style: TextStyle(
                            fontSize: 9,
                            color: _textSub,
                            fontWeight: FontWeight.w600)),
                    Text(
                      '${summary.survival.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 9,
                          color: _textPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.survival / 100,
                    minHeight: 5,
                    backgroundColor: _borderDark,
                    valueColor: AlwaysStoppedAnimation(
                      summary.survival >= 80 ? _accentGreen : _amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Profit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Est. Pond Profit',
                  style: TextStyle(
                      fontSize: 9,
                      color: _textSub,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatVal(summary.profit),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: summary.profit >= 0 ? _accentGreen : _red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatVal(double v) {
    if (v.abs() >= 100000) return '${v >= 0 ? '' : '-'}₹${(v.abs() / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '${v >= 0 ? '' : '-'}₹${(v.abs() / 1000).toStringAsFixed(1)}K';
    return '${v >= 0 ? '' : '-'}₹${v.abs().toStringAsFixed(0)}';
  }
}

class _PondMetric extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _PondMetric({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          decoration: BoxDecoration(
            color: _cardDark2,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 8,
                      color: _textSub,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? _textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── FCR Trend Chart ───────────────────────────────────────────────────────────
class _FcrTrendChart extends StatelessWidget {
  final List<_PondSummary> summaries;
  const _FcrTrendChart({required this.summaries});

  static const List<Color> _lineColors = [
    _accentGreen,
    _accentBlue,
    _amber,
    Color(0xFF8B5CF6),
  ];

  @override
  Widget build(BuildContext context) {
    final activePonds =
        summaries.where((s) => s.fcrTrend.length >= 2).toList();
    if (activePonds.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _FcrLinePainter(
                summaries: activePonds,
                colors: _lineColors,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // X axis labels
          _buildXLabels(activePonds),
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              ...activePonds.asMap().entries.map((e) => _LegendDot(
                    color: _lineColors[e.key % _lineColors.length],
                    label: e.value.name,
                  )),
              const _LegendDot(
                  color: Color(0xFF374151), label: 'Target 1.4'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildXLabels(List<_PondSummary> ponds) {
    if (ponds.isEmpty || ponds.first.fcrTrend.isEmpty) {
      return const SizedBox.shrink();
    }
    final dates = ponds.first.fcrTrend.map((p) => p.date).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dates
          .map((d) => Text(
                DateFormat('d MMM').format(d),
                style: const TextStyle(
                    fontSize: 8, color: _textSub, fontWeight: FontWeight.w500),
              ))
          .toList(),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: _textSub, fontWeight: FontWeight.w500)),
        ],
      );
}

class _FcrLinePainter extends CustomPainter {
  final List<_PondSummary> summaries;
  final List<Color> colors;
  const _FcrLinePainter({required this.summaries, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (summaries.isEmpty) return;

    // Collect all FCR values for scale
    final allFcr = summaries.expand((s) => s.fcrTrend.map((p) => p.fcr)).toList();
    allFcr.add(1.4); // target line
    final maxFcr = (allFcr.reduce(math.max) * 1.1).clamp(1.5, 3.0);
    final minFcr = (allFcr.reduce(math.min) * 0.9).clamp(0.5, 1.2);

    double toY(double v) =>
        size.height - ((v - minFcr) / (maxFcr - minFcr) * size.height);
    double toX(int i, int total) =>
        total <= 1 ? size.width / 2 : i * size.width / (total - 1);

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = _borderDark
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Target line (dashed appearance via short segments)
    final targetPaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final targetY = toY(1.4);
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, targetY), Offset(math.min(x + 6, size.width), targetY), targetPaint);
      x += 10;
    }

    // Draw each pond's FCR line
    for (int p = 0; p < summaries.length; p++) {
      final pts = summaries[p].fcrTrend;
      if (pts.length < 2) continue;
      final color = colors[p % colors.length];

      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final x = toX(i, pts.length);
        final y = toY(pts[i].fcr);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Dots
      final dotPaint = Paint()..color = color;
      for (int i = 0; i < pts.length; i++) {
        canvas.drawCircle(
            Offset(toX(i, pts.length), toY(pts[i].fcr)), 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_FcrLinePainter old) => old.summaries != summaries;
}

// ── Farm Dropdown ─────────────────────────────────────────────────────────────
class _FarmDropdown extends StatelessWidget {
  final FarmState farmState;
  final String currentFarmName;
  final void Function(String id) onSelect;
  final VoidCallback onAddFarm;

  const _FarmDropdown({
    required this.farmState,
    required this.currentFarmName,
    required this.onSelect,
    required this.onAddFarm,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == '__add__') {
          onAddFarm();
        } else {
          onSelect(value);
        }
      },
      itemBuilder: (_) => [
        // Existing farms
        ...farmState.farms.map((farm) {
          final isSelected = farm.id == farmState.selectedId;
          return PopupMenuItem<String>(
            value: farm.id,
            child: Row(
              children: [
                Icon(
                  Icons.eco_rounded,
                  size: 15,
                  color: isSelected ? _accentGreen : _textSub,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    farm.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _accentGreen : _textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_rounded,
                      size: 15, color: _accentGreen),
              ],
            ),
          );
        }),
        // Divider
        const PopupMenuDivider(),
        // Add new farm
        PopupMenuItem<String>(
          value: '__add__',
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 14, color: _accentGreen),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add New Farm',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _accentGreen,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              currentFarmName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: _textSub),
        ],
      ),
    );
  }
}


