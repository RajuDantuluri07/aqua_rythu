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
import 'package:aqua_rythu/core/constants/app_constants.dart';
import 'package:aqua_rythu/core/utils/shrimp_metrics.dart';

// ── Design constants (matches pond dashboard light theme) ─────────────────────
const _bgDark      = Color(0xFFF5F7FA);
const _cardDark    = Colors.white;
const _borderDark  = Color(0xFFE2E8F0);
const _textPrimary = Color(0xFF1E293B);
const _textSub     = Color(0xFF64748B);
const _accentGreen = Color(0xFF16A34A);
const _red         = Color(0xFFEF4444);
const _amber       = Color(0xFFF59E0B);

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

    if (ponds.isEmpty) return _noPondsView(context, ref, farmState, currentFarm);

    // ── Per-pond data ─────────────────────────────────────────────────────────
    final List<_PondSummary> summaries = ponds.map((pond) {
      final doc        = ref.watch(docProvider(pond.id));
      final growthLogs = ref.watch(growthProvider(pond.id));
      final logs       = feedHistory[pond.id] ?? [];

      final double abw = growthLogs.isNotEmpty
          ? growthLogs.first.abw
          : (pond.currentAbw ?? 0.0);

      final double survival = estimateSurvival(doc);
      final double biomass = calcBiomassKg(pond.seedCount, abw, survival);
      final double totalFeed = logs.isNotEmpty ? logs.first.cumulative : 0.0;
      final double fcr   = biomass > 0.1 ? totalFeed / biomass : 0.0;

      final double cropValue  = biomass * kShrimpMarketPricePerKg;
      final double feedCost   = totalFeed * kFeedCostPerKg;
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
      if (fcr > 1.8) {
        status = 'Critical';
      } else if (fcr > 1.5)  status = 'Slow';
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
    double avgSurvival   = summaries.isNotEmpty
        ? summaries.fold(0.0, (s, p) => s + p.survival) / summaries.length
        : 0.0;
    double farmFcr       = totalBiomass > 0.1 ? totalFeedFarm / totalBiomass : 0.0;
    double totalFeedCost = summaries.fold(0.0, (s, p) => s + p.feedCost);

    // Weighted survival: sum(survival * seedCount) / totalSeeds
    final int totalSeeds = summaries.fold(0, (s, p) => s + p.seedCount);
    final double combinedSurvival = totalSeeds > 0
        ? summaries.fold(0.0, (s, p) => s + p.survival * p.seedCount) / totalSeeds
        : avgSurvival;
    // True when no pond has real ABW sampling data — survival is a model estimate.
    final bool survivalIsEstimated = summaries.every((s) => s.abw <= 0);

    // Feed today (per-pond tracking for action bar)
    double feedToday = 0.0;
    final Set<String> pondsFedToday = {};
    for (final pond in ponds) {
      final logs = feedHistory[pond.id] ?? [];
      if (logs.isNotEmpty) {
        final today = DateTime.now();
        final first = logs.first;
        if (first.date.year == today.year &&
            first.date.month == today.month &&
            first.date.day == today.day) {
          feedToday += first.total;
          pondsFedToday.add(pond.id);
        }
      }
    }

    // Farm health score (0–100)
    int healthScore = _computeHealthScore(farmFcr, avgSurvival, summaries);

    // Action bar items (priority-ordered, max 2)
    final List<_ActionItem> actionItems =
        _buildActionItems(ponds, summaries, pondsFedToday, feedHistory);

    final int avgDoc = summaries.isNotEmpty
        ? summaries.fold(0, (s, p) => s + p.doc) ~/ summaries.length
        : 0;

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
                    // Action Bar
                    _ActionBar(
                      items: actionItems,
                      onTap: (pondId) => Navigator.pushNamed(
                        context,
                        AppRoutes.pondDashboard,
                        arguments: pondId,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Farm Health gauge + Core Metrics Grid
                    _buildHealthAndMetricsSection(
                      healthScore: healthScore,
                      totalCropVal: totalCropVal,
                      totalProfit: totalProfit,
                      feedToday: feedToday,
                      totalFeedCost: totalFeedCost,
                      combinedSurvival: combinedSurvival,
                      survivalIsEstimated: survivalIsEstimated,
                      avgDoc: avgDoc,
                    ),

                    const SizedBox(height: 20),

                    // Pond Status
                    if (summaries.isNotEmpty) ...[
                      _sectionLabel('POND STATUS'),
                      const SizedBox(height: 10),
                      _buildPondStatusGrid(context, ref, currentFarm.id, summaries, pondsFedToday, feedHistory),
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
                'Data saved',
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

  // ── HEALTH + CORE METRICS SECTION ───────────────────────────────────
  Widget _buildHealthAndMetricsSection({
    required int healthScore,
    required double totalCropVal,
    required double totalProfit,
    required double feedToday,
    required double totalFeedCost,
    required double combinedSurvival,
    required bool survivalIsEstimated,
    required int avgDoc,
  }) {
    final bool investmentPhase = avgDoc <= 30;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FarmHealthGauge(score: healthScore),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              // Row 1: Crop Value + Est. Profit
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'CROP VALUE',
                      value: totalCropVal > 0
                          ? _formatCurrency(totalCropVal)
                          : 'Calculating...',
                      sub: totalCropVal > 0
                          ? 'Est. at ₹${kShrimpMarketPricePerKg.toStringAsFixed(0)}/kg'
                          : '',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      label: 'EST. PROFIT',
                      value: investmentPhase
                          ? 'Invest. Phase'
                          : _formatCurrency(totalProfit),
                      sub: investmentPhase
                          ? 'Building phase'
                          : 'After feed cost',
                      valueColor: investmentPhase
                          ? _textSub
                          : (totalProfit >= 0 ? _accentGreen : _red),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: Feed Today + Feed Cost
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'FEED TODAY',
                      value: feedToday > 0
                          ? '${feedToday.toStringAsFixed(0)} kg'
                          : 'No feed yet',
                      sub: 'All ponds',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      label: 'FEED COST',
                      value: totalFeedCost > 0
                          ? _formatCurrency(totalFeedCost)
                          : 'Starting...',
                      sub: 'Till date',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 3: Survival (full width)
              _MetricTile(
                label: 'SURVIVAL',
                value: combinedSurvival > 0
                    ? survivalIsEstimated
                        ? '~${combinedSurvival.toStringAsFixed(0)}% Est.'
                        : '${combinedSurvival.toStringAsFixed(0)}% overall'
                    : 'Estimating...',
                sub: survivalIsEstimated
                    ? 'No sampling yet — model estimate'
                    : 'Weighted avg across ponds',
                valueColor: survivalIsEstimated
                    ? _textSub
                    : combinedSurvival >= 80 ? _accentGreen : _amber,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── POND STATUS GRID ───────────────────────────────────────────────────────
  Widget _buildPondStatusGrid(
    BuildContext context,
    WidgetRef ref,
    String farmId,
    List<_PondSummary> summaries,
    Set<String> pondsFedToday,
    Map<String, List<FeedHistoryLog>> feedHistory,
  ) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now();

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
      itemBuilder: (context, i) {
        final s = summaries[i];
        final fedToday = pondsFedToday.contains(s.id);
        // Today's fed amount — first log entry if it was logged today
        final logs = feedHistory[s.id] ?? [];
        double todayFed = 0;
        if (logs.isNotEmpty) {
          final first = logs.first;
          if (first.date.year == today.year &&
              first.date.month == today.month &&
              first.date.day == today.day) {
            todayFed = first.total;
          }
        }
        return _PondStatusCard(
          summary: s,
          fedToday: fedToday,
          todayFedKg: todayFed,
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.pondDashboard,
            arguments: s.id,
          ),
          onEdit: () => Navigator.pushNamed(
            context,
            AppRoutes.editPond,
            arguments: s.id,
          ),
          onDelete: () => _confirmDelete(context, s.name, () async {
            try {
              await ref.read(farmProvider.notifier).deletePond(farmId, s.id);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete pond: $e')),
                );
              }
            }
          }),
        );
      },
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
    if (fcr > 2.0) {
      score -= 25;
    } else if (fcr > 1.8)  score -= 18;
    else if (fcr > 1.5)  score -= 10;
    else if (fcr > 1.3)  score -= 5;

    if (survival < 70) {
      score -= 20;
    } else if (survival < 80) score -= 10;
    else if (survival < 85) score -= 5;

    final critCount = summaries.where((s) => s.status == 'Critical').length;
    final slowCount = summaries.where((s) => s.status == 'Slow').length;
    score -= critCount * 12;
    score -= slowCount * 5;

    return score.clamp(0, 100);
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
      final double survival = estimateSurvival(log.doc);
      final double biomass = calcBiomassKg(seedCount, abw, survival);
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
            "Delete '$pondName'? This action is permanent and cannot be undone."),
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

  // ── ACTION ITEMS ───────────────────────────────────────────────────────────
  static List<_ActionItem> _buildActionItems(
    List<Pond> ponds,
    List<_PondSummary> summaries,
    Set<String> pondsFedToday,
    Map<String, List<FeedHistoryLog>> feedHistory,
  ) {
    final items = <_ActionItem>[];
    final now = DateTime.now();

    // Priority 1: Feed pending — pond has not been fed today
    for (final pond in ponds) {
      if (!pondsFedToday.contains(pond.id)) {
        // Use most recent planned amount as today's proxy
        final planned = feedHistory[pond.id]?.firstOrNull?.expected ?? 0.0;
        final qtyLabel = planned > 0
            ? ' — ${planned.toStringAsFixed(1)} kg due'
            : '';
        items.add(_ActionItem(
          message: '⚠️ Feed ${pond.name}$qtyLabel',
          pondId: pond.id,
          priority: 1,
        ));
      }
    }

    // Priority 2: Sampling due — DOC ≥ 30 and last sample ≥ 10 days ago
    for (final pond in ponds) {
      final summary = summaries.where((s) => s.id == pond.id).firstOrNull;
      if (summary == null || summary.doc < 30) continue;
      final lastSample = pond.latestSampleDate;
      final daysSince = lastSample == null ? 999 : now.difference(lastSample).inDays;
      if (daysSince >= 10) {
        items.add(_ActionItem(
          message: '📊 Sampling due in ${pond.name}',
          pondId: pond.id,
          priority: 2,
        ));
      }
    }

    // Priority 3: Growth alert
    for (final s in summaries) {
      if (s.status == 'Slow' || s.status == 'Critical') {
        items.add(_ActionItem(
          message: '🚨 Growth slower than expected in ${s.name}',
          pondId: s.id,
          priority: 3,
        ));
      }
    }

    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items.take(2).toList();
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

  Widget _noPondsView(BuildContext context, WidgetRef ref,
      FarmState farmState, dynamic currentFarm) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: _bgDark,
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keep the farm header so the user can switch farms
            _buildHeader(context, ref, farmState, currentFarm, 0, now),

            // Empty state — centered in remaining space
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _accentGreen.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.water_outlined,
                            size: 40,
                            color: _accentGreen,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Start your first pond',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Track feed, growth, and profit easily.\nAdd a pond to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSub,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.addPond),
                            icon: const Icon(Icons.add_rounded,
                                size: 20, color: Colors.white),
                            label: const Text(
                              '+ Add Pond',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentGreen,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTION BAR
// ══════════════════════════════════════════════════════════════════════════════

class _ActionItem {
  final String message;
  final String pondId;
  final int priority;
  const _ActionItem({
    required this.message,
    required this.pondId,
    required this.priority,
  });
}

class _ActionBar extends StatelessWidget {
  final List<_ActionItem> items;
  final void Function(String pondId) onTap;
  const _ActionBar({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                '✅ All ponds on track',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.map((item) {
        return GestureDetector(
          onTap: () => onTap(item.pondId),
          child: Container(
            margin: EdgeInsets.only(bottom: items.indexOf(item) < items.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _actionBg(item.priority),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _actionBorder(item.priority)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _actionText(item.priority),
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: _actionText(item.priority)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static Color _actionBg(int p) {
    if (p == 1) return const Color(0xFFFFF7ED);
    if (p == 2) return const Color(0xFFEFF6FF);
    return const Color(0xFFFFF1F2);
  }

  static Color _actionBorder(int p) {
    if (p == 1) return const Color(0xFFFED7AA);
    if (p == 2) return const Color(0xFFBFDBFE);
    return const Color(0xFFFCA5A5);
  }

  static Color _actionText(int p) {
    if (p == 1) return const Color(0xFF9A3412);
    if (p == 2) return const Color(0xFF1E40AF);
    return const Color(0xFF991B1B);
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _GaugePainter(score: score, color: color),
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

// ── METRIC TILE ─────────────────────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label, value, sub;
  final Color? valueColor;
  final bool fullWidth;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: valueColor ?? _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _textSub,
            ),
          ),
        ],
      ),
    );

    return fullWidth ? tile : Expanded(child: tile);
  }
}

// ── Pond Status Card ──────────────────────────────────────────────────────────
class _PondStatusCard extends StatelessWidget {
  final _PondSummary summary;
  final bool fedToday;
  final double todayFedKg;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _PondStatusCard({
    required this.summary,
    required this.fedToday,
    required this.todayFedKg,
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
            // Header row — name + status badge + 3-dot menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
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
                ),
                // 3-dot menu
                PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: _textSub),
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: _textSub),
                            SizedBox(width: 10),
                            Text('Edit Pond',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 16, color: _red),
                            SizedBox(width: 10),
                            Text('Delete',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Area · DOC
            Text(
              '${summary.area.toStringAsFixed(1)} ac  ·  DOC ${summary.doc}',
              style: const TextStyle(
                  fontSize: 10,
                  color: _textSub,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            // Survival %
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Survival',
                  style: TextStyle(
                      fontSize: 9,
                      color: _textSub,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  // Fix #6: tag survival as estimated when no real ABW data exists
                  // (abw == 0 means no sampling has been done yet).
                  // Showing "100%" on a brand-new pond is misleading.
                  summary.abw <= 0
                      ? '~${summary.survival.toStringAsFixed(0)}% Est.'
                      : '${summary.survival.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Survival bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.survival / 100,
                minHeight: 5,
                backgroundColor: _borderDark,
                valueColor: AlwaysStoppedAnimation(
                  // Fix #6: gray bar when survival is a model estimate (no real data).
                  summary.abw <= 0
                      ? const Color(0xFFCBD5E1)
                      : summary.survival >= 80 ? _accentGreen : _amber,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Seed count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Seed',
                  style: TextStyle(
                      fontSize: 9,
                      color: _textSub,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatSeedCount(summary.seedCount),
                  style: const TextStyle(
                      fontSize: 12,
                      color: _textPrimary,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Today's feed status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: fedToday
                    ? _accentGreen.withOpacity(0.08)
                    : _red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                fedToday
                    ? '✅ Fed ${todayFedKg.toStringAsFixed(1)} kg today'
                    : '🔴 Not fed yet',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fedToday ? _accentGreen : _red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSeedCount(int count) {
    if (count >= 100000) return '${(count / 100000).toStringAsFixed(1)}L';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    return '$count';
  }
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


