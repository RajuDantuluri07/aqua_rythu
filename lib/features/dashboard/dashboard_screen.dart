import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aqua_rythu/features/farm/farm_provider.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:aqua_rythu/features/pond/controllers/pond_dashboard_controller.dart';
import 'package:aqua_rythu/core/constants/app_constants.dart';
import '../common/banner_widget.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFFF5F7FA);
const _white = Colors.white;
const _border = Color(0xFFE2E8F0);
const _textPrimary = Color(0xFF1E293B);
const _textSub = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _redLight = Color(0xFFFEF2F2);
const _amberLight = Color(0xFFFFFBEB);

// ── Data models ───────────────────────────────────────────────────────────────

class _PondRow {
  final String id, name, status;
  final int doc, seedCount;
  final double abw, fcr, biomass, todayFeed, yesterdayFeed, area;
  final bool fcrTrendUp, feedTrendUp, hasAbwData;
  final PondViewState feedState;

  const _PondRow({
    required this.id,
    required this.name,
    required this.doc,
    required this.abw,
    required this.fcr,
    required this.biomass,
    required this.todayFeed,
    required this.yesterdayFeed,
    required this.status,
    required this.fcrTrendUp,
    required this.feedTrendUp,
    required this.hasAbwData,
    required this.area,
    required this.seedCount,
    required this.feedState,
  });
}

class _Insight {
  final String title, subtitle, ctaLabel, pondId;
  final bool isCritical;

  const _Insight({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.pondId,
    required this.isCritical,
  });
}

// ══════════════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🧪 DEBUG: Temporarily test with simple UI
    const testDebugMode = false; // Set to true to test with simple widget
    if (testDebugMode) {
      return const Scaffold(
        body: Center(child: Text("HOME OK - Layout test passed ✅")),
      );
    }

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;

    // Show loading spinner while farms are being fetched on startup
    if (farmState.farms.isEmpty && farmState.selectedId.isEmpty) {
      return _loadingView();
    }

    if (currentFarm == null) return _noFarmView(context);

    final ponds =
        currentFarm.ponds.where((p) => p.status.name == 'active').toList();
    if (ponds.isEmpty)
      return _noPondsView(context, ref, farmState, currentFarm);

    final today = DateTime.now();

    // ── Load feed data from controller for each pond ────────────────────────
    Future<List<_PondRow>> _buildPondRows() async {
      final rows = <_PondRow>[];

      for (final pond in ponds) {
        try {
          // Get feed state from single source of truth
          final feedState = await pondDashboardController.load(pond.id);

          // Extract data from controller result
          final feedResult = feedState.feedResult;
          final double abw = pond.currentAbw ?? 0.0;
          final bool hasAbwData = abw > 0;

          // Get feed amounts from controller state
          final double todayFeed = feedState.roundFeedAmounts.values
              .where((status) => status > 0)
              .fold(0.0, (sum, amount) => sum + amount);

          // Simplified biomass and FCR from controller data
          final double biomass = feedResult?.finalFeed != null
              ? (pond.seedCount * 0.95 * abw) / 1000 // Simplified calculation
              : 0.0;
          final double fcr = biomass > 0.1 ? todayFeed / biomass : 0.0;

          // Status based on controller feed result
          String status = 'Good';
          if (feedResult?.decision.action == 'Stop Feeding') {
            status = 'Critical';
          } else if (fcr > 1.5) {
            status = 'Warning';
          }

          rows.add(_PondRow(
            id: pond.id,
            name: pond.name,
            doc: feedState.doc,
            abw: abw,
            fcr: fcr,
            biomass: biomass,
            todayFeed: todayFeed,
            yesterdayFeed: 0.0, // TODO: Get from feed history if needed
            status: status,
            fcrTrendUp: false, // Simplified for now
            feedTrendUp: false, // Simplified for now
            hasAbwData: hasAbwData,
            area: pond.area,
            seedCount: pond.seedCount,
            feedState: feedState,
          ));
        } catch (e) {
          // Fallback for controller errors
          rows.add(_PondRow(
            id: pond.id,
            name: pond.name,
            doc: 0,
            abw: 0.0,
            fcr: 0.0,
            biomass: 0.0,
            todayFeed: 0.0,
            yesterdayFeed: 0.0,
            status: 'Error',
            fcrTrendUp: false,
            feedTrendUp: false,
            hasAbwData: false,
            area: pond.area,
            seedCount: pond.seedCount,
            feedState: PondViewState(
              pondId: pond.id,
              doc: 0,
              error: 'Failed to load: $e',
            ),
          ));
        }
      }

      return rows;
    }

    return FutureBuilder<List<_PondRow>>(
      future: _buildPondRows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loadingView();
        }

        if (!snapshot.hasData) {
          return _noPondsView(context, ref, farmState, currentFarm);
        }

        final rows = snapshot.data!;

        // ── Farm-level aggregates ─────────────────────────────────────────────────
        final double totalFeedFarm = rows.fold(0.0, (s, r) => s + r.todayFeed);
        final double feedToday = totalFeedFarm;
        final double feedYesterday =
            rows.fold(0.0, (s, r) => s + r.yesterdayFeed);
        final double totalFeedCost = totalFeedFarm * kFeedCostPerKg;
        final double totalBiomass = rows.fold(0.0, (s, r) => s + r.biomass);

        final double feedChangePct = feedYesterday > 0
            ? ((feedToday - feedYesterday) / feedYesterday) * 100
            : 0.0;

        final double farmFcr =
            totalBiomass > 0.1 ? totalFeedFarm / totalBiomass : 0.0;
        final String biomassStatus = farmFcr < 1.5
            ? 'Within optimal range'
            : farmFcr < 2.0
                ? 'Monitor closely'
                : 'Needs attention';

        final int needsAttentionCount =
            rows.where((r) => r.status != 'Good').length;

        // ── Insights ─────────────────────────────────────────────────────────────
        final insights = _buildInsights(rows, ponds, today);

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    farmState: farmState,
                    currentFarm: currentFarm,
                    onSelectFarm: (id) =>
                        ref.read(farmProvider.notifier).selectFarm(id),
                    onAddFarm: () =>
                        Navigator.pushNamed(context, AppRoutes.addFarm),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 2×2 KPI grid ──────────────────────────────────────
                        _KpiGrid(
                          totalFeedFarm: totalFeedFarm,
                          feedToday: feedToday,
                          feedChangePct: feedChangePct,
                          totalFeedCost: totalFeedCost,
                          totalBiomass: totalBiomass,
                          biomassStatus: biomassStatus,
                        ),

                        // ── Farm Insights ─────────────────────────────────────
                        if (insights.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const Text(
                            'Farm Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...insights.map((ins) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _InsightCard(
                                  insight: ins,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.pondDashboard,
                                    arguments: ins.pondId,
                                  ),
                                ),
                              )),
                        ],

                        // ── Pond list ─────────────────────────────────────────
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${rows.length} ACTIVE PONDS',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _textSub,
                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.addPond),
                              child: const Text(
                                'VIEW ALL',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _green,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...rows.map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _PondCard(
                                row: r,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.pondDashboard,
                                  arguments: r.id,
                                ),
                                onEdit: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.editPond,
                                  arguments: r.id,
                                ),
                                onDelete: () => _confirmDelete(
                                  context,
                                  r.name,
                                  () async {
                                    try {
                                      await ref
                                          .read(farmProvider.notifier)
                                          .deletePond(currentFarm.id, r.id);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Failed to delete: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Insights builder ───────────────────────────────────────────────────────
  static List<_Insight> _buildInsights(
    List<_PondRow> rows,
    List<Pond> ponds,
    DateTime today,
  ) {
    final result = <_Insight>[];

    // Overfeeding: today's feed > 2.5% of biomass (in kg)
    for (final r in rows) {
      if (r.biomass > 0.1 && r.todayFeed > 0) {
        final ratio =
            r.todayFeed / r.biomass; // biomass already in kg, feed in kg
        if (ratio > 0.025) {
          result.add(_Insight(
            title: '${r.name}: Overfeeding risk',
            subtitle: 'Feed ratio exceeded 2.5% of biomass today.',
            ctaLabel: 'Check Feed',
            pondId: r.id,
            isCritical: true,
          ));
        }
      }
    }

    // No sampling in 10+ days (only for tanks with DOC > 5, since new tanks don't need early samples)
    // Create a lookup map for O(1) access instead of O(n²) where().firstOrNull
    final rowMap = {for (final row in rows) row.id: row};

    for (final pond in ponds) {
      final row = rowMap[pond.id];
      if (row == null || row.doc < 6)
        continue; // Skip tanks DOC <= 5 (too young to sample)
      final lastSample = pond.latestSampleDate;
      final daysSince =
          lastSample == null ? 999 : today.difference(lastSample).inDays;
      if (daysSince >= 10) {
        result.add(_Insight(
          title: '${row.name}: No sampling in $daysSince days',
          subtitle: 'Biomass estimation may be inaccurate.',
          ctaLabel: 'View Pond',
          pondId: row.id,
          isCritical: false,
        ));
      }
    }

    return result;
  }

  // Removed _abwAtDoc - no longer needed with controller-based approach

  void _confirmDelete(
      BuildContext context, String name, VoidCallback onConfirmed) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pond'),
        content: Text("Delete '$name'? This cannot be undone."),
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

  // ── Loading state ──────────────────────────────────────────────────────────
  Widget _loadingView() {
    return const Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
        ),
      ),
    );
  }

  // ── Empty states ───────────────────────────────────────────────────────────
  Widget _noFarmView(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dashboard_customize_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text('No Farm Selected',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              const SizedBox(height: 8),
              const Text('Create or select a farm to get started.',
                  style: TextStyle(color: _textSub)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.addFarm),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: _white),
                child: const Text('Create Farm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noPondsView(BuildContext context, WidgetRef ref, FarmState farmState,
      dynamic currentFarm) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              farmState: farmState,
              currentFarm: currentFarm,
              onSelectFarm: (id) =>
                  ref.read(farmProvider.notifier).selectFarm(id),
              onAddFarm: () => Navigator.pushNamed(context, AppRoutes.addFarm),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.water_outlined,
                            size: 40, color: _green),
                      ),
                      const SizedBox(height: 24),
                      const Text('Start your first pond',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary)),
                      const SizedBox(height: 10),
                      const Text(
                          'Track feed, growth, and profit easily.\nAdd a pond to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14, color: _textSub, height: 1.5)),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.addPond),
                          icon: const Icon(Icons.add_rounded,
                              size: 20, color: _white),
                          label: const Text('+ Add Pond',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
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
// HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final FarmState farmState;
  final dynamic currentFarm;
  final void Function(String) onSelectFarm;
  final VoidCallback onAddFarm;

  const _Header({
    required this.farmState,
    required this.currentFarm,
    required this.onSelectFarm,
    required this.onAddFarm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Farm icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.agriculture_rounded, color: _green, size: 22),
          ),
          const SizedBox(width: 10),

          // Farm name + attention label
          Expanded(
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              color: _white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == '__add__') {
                  onAddFarm();
                } else {
                  onSelectFarm(value);
                }
              },
              itemBuilder: (_) => [
                ...farmState.farms.map((farm) {
                  final sel = farm.id == farmState.selectedId;
                  return PopupMenuItem<String>(
                    value: farm.id,
                    child: Row(
                      children: [
                        Icon(Icons.eco_rounded,
                            size: 15, color: sel ? _green : _textSub),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(farm.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sel ? _green : _textPrimary,
                              )),
                        ),
                        if (sel)
                          const Icon(Icons.check_rounded,
                              size: 15, color: _green),
                      ],
                    ),
                  );
                }),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: '__add__',
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 14, color: _green),
                      ),
                      const SizedBox(width: 10),
                      const Text('Add New Farm',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _green)),
                    ],
                  ),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          currentFarm.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: _textSub),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// KPI GRID  (2 × 2)
// ══════════════════════════════════════════════════════════════════════════════

class _KpiGrid extends StatelessWidget {
  final double totalFeedFarm,
      feedToday,
      feedChangePct,
      totalFeedCost,
      totalBiomass;
  final String biomassStatus;

  const _KpiGrid({
    required this.totalFeedFarm,
    required this.feedToday,
    required this.feedChangePct,
    required this.totalFeedCost,
    required this.totalBiomass,
    required this.biomassStatus,
  });

  @override
  Widget build(BuildContext context) {
    final hasFeedChange = feedChangePct != 0 && feedToday > 0;
    final biomassOk = biomassStatus == 'Within optimal range';
    final nf = NumberFormat('#,###');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'TOTAL FEED\n(TILL DATE)',
                value: nf.format(totalFeedFarm.round()),
                unit: 'kg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'TODAY FEED\n(ALL PONDS)',
                value: nf.format(feedToday.round()),
                unit: 'kg',
                sub: hasFeedChange
                    ? '${feedChangePct > 0 ? '↑' : '↓'} ${feedChangePct.abs().toStringAsFixed(0)}% vs yesterday'
                    : null,
                subColor: feedChangePct > 0 ? _red : _green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'TOTAL FEED COST\n(₹)',
                value: _fmtCurrency(totalFeedCost),
                valueColor: _green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                label: 'ESTIMATED\nBIOMASS',
                value: nf.format(totalBiomass.round()),
                unit: 'kg',
                sub: biomassStatus,
                subColor: biomassOk ? _green : _amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _fmtCurrency(double v) {
    if (v.abs() >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)} Cr';
    if (v.abs() >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    if (v.abs() >= 1000) return '₹${(v / 1000).toStringAsFixed(1)} K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final String? unit, sub;
  final Color? valueColor, subColor;

  const _KpiCard({
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.valueColor,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _textSub,
              letterSpacing: 0.4,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textSub,
                    ),
                  ),
              ],
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subColor ?? _textSub,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INSIGHT CARD
// ══════════════════════════════════════════════════════════════════════════════

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  final VoidCallback onTap;

  const _InsightCard({required this.insight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = insight.isCritical ? _red : _amber;
    final bg = insight.isCritical ? _redLight : _amberLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    insight.isCritical
                        ? Icons.error_outline_rounded
                        : Icons.history_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: insight.isCritical
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        insight.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSub,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${insight.ctaLabel} →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ), // Row
        ), // IntrinsicHeight
      ), // Container
    ); // GestureDetector
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// POND CARD
// ══════════════════════════════════════════════════════════════════════════════

class _PondCard extends StatelessWidget {
  final _PondRow row;
  final VoidCallback onTap, onEdit, onDelete;

  const _PondCard({
    required this.row,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = row.status == 'Good'
        ? _green
        : row.status == 'Critical'
            ? _red
            : _amber;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Name + Status Badge ──────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        row.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 18, color: _textSub),
                  color: _white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 16, color: _textSub),
                        SizedBox(width: 10),
                        Text('Edit Pond',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: _red),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),

            // ── Pond Info: Area + Stocking (compact) ────────────────────
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Area
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.landscape_rounded,
                            size: 12, color: _green),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Size',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _textSub,
                                height: 1,
                              ),
                            ),
                            Text(
                              '${row.area.toStringAsFixed(1)} ac',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(width: 1, height: 28, color: _border),
                  // Stocking
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded,
                            size: 12, color: _green),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Stock',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: _textSub,
                                height: 1,
                              ),
                            ),
                            Text(
                              '${row.seedCount}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── "Needs Attention" chip if Critical ───────────────────────
            if (row.status == 'Critical') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _redLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: _red),
                    SizedBox(width: 4),
                    Text('NEEDS ATTENTION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _red,
                          letterSpacing: 0.3,
                        )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 8),

            // ── Stats row: DOC | FEED (D) | FCR ──────────────────────────
            Row(
              children: [
                // DOC
                Expanded(
                  child: _StatCell(
                    label: 'DOC',
                    value: '${row.doc}',
                  ),
                ),
                // Divider
                Container(width: 1, height: 40, color: _border),
                // FEED (D)
                Expanded(
                  child: _StatCell(
                    label: 'FEED (D)',
                    valueWidget: row.todayFeed > 0
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${row.todayFeed.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                row.feedTrendUp
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 14,
                                color: row.feedTrendUp ? _red : _green,
                              ),
                            ],
                          )
                        : const Text('—',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textSub,
                            )),
                  ),
                ),
                // Divider
                Container(width: 1, height: 40, color: _border),
                // FCR
                Expanded(
                  child: row.hasAbwData
                      ? _StatCell(
                          label: 'FCR',
                          valueWidget: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                row.fcr.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: row.fcrTrendUp ? _red : _textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                row.fcrTrendUp
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 14,
                                color: row.fcrTrendUp ? _red : _green,
                              ),
                            ],
                          ),
                        )
                      : const _StatCell(
                          label: 'FCR',
                          valueWidget: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Not available',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _amber,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'No sampling yet',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _StatCell({required this.label, this.value, this.valueWidget})
      : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _textSub,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        if (valueWidget != null)
          valueWidget!
        else
          Text(
            value!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
      ],
    );
  }
}
