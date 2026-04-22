import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../farm/farm_provider.dart';
import '../pond/pond_dashboard_provider.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../core/language/app_localizations.dart';
import 'widgets/farm_kpi_card.dart';
import 'widgets/today_action_card.dart';
import 'widgets/overview_card.dart';
import 'widgets/pond_card.dart';
import 'widgets/farm_health_indicator.dart';
import 'widgets/quick_action_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    if (currentFarm == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('home')),
          backgroundColor: const Color(0xFFF9F9F9),
          elevation: 0,
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.landscape_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No farm found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(context, currentFarm.name),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildFarmKPIs(context, ponds),
                    const SizedBox(height: 24),
                    _buildTodaysActions(context, ponds),
                    const SizedBox(height: 24),
                    _buildOverview(context, ponds),
                    const SizedBox(height: 24),
                    _buildActivePonds(context, ponds),
                    const SizedBox(height: 100), // Bottom nav padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
    );
  }

  Widget _buildTopAppBar(BuildContext context, String farmName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00864B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.agriculture,
              color: Color(0xFF006A3A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  farmName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1C),
                  ),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final dashboardState = ref.watch(pondDashboardProvider);
                    final criticalPonds =
                        0; // TODO: Calculate critical ponds based on actual data

                    if (criticalPonds > 0) {
                      return Text(
                        '⚠️ $criticalPonds pond${criticalPonds > 1 ? 's' : ''} need attention',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE53935),
                          letterSpacing: 0.5,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Implement notifications
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF64748B),
              size: 24,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmKPIs(BuildContext context, List<dynamic> ponds) {
    return Consumer(
      builder: (context, ref, child) {
        final dashboardState = ref.watch(pondDashboardProvider);
        final totalFeed = _calculateTotalFeed(ref, ponds);
        final todayFeed = _calculateTodayFeed(ref, ponds);
        final totalFeedCost = _calculateTotalFeedCost(ref, ponds);
        final estimatedBiomass = _calculateEstimatedBiomass(ref, ponds);
        final estimatedProfit = _calculateEstimatedProfit(ref, ponds);
        final farmHealthScore = _calculateFarmHealthScore(ref, ponds);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            FarmKPICard(
              title: 'Total feed',
              value: totalFeed.toStringAsFixed(0),
              unit: 'kg',
            ),
            FarmKPICard(
              title: 'Today feed',
              value: todayFeed.toStringAsFixed(0),
              unit: 'kg',
            ),
            FarmKPICard(
              title: 'Total feed cost',
              value: '₹${(totalFeedCost / 100000).toStringAsFixed(1)}L',
            ),
            FarmKPICard(
              title: 'Estimated biomass',
              value: estimatedBiomass.toStringAsFixed(0),
              unit: 'kg',
            ),
            FarmKPICard(
              title: 'Estimated profit',
              value: '₹${(estimatedProfit / 100000).toStringAsFixed(1)}L',
              valueColor: const Color(0xFF006A3A),
            ),
            FarmHealthIndicator(
              healthScore: farmHealthScore,
              status: farmHealthScore >= 90
                  ? 'Excellent'
                  : farmHealthScore >= 70
                      ? 'Good'
                      : 'Needs Attention',
            ),
          ],
        );
      },
    );
  }

  Widget _buildTodaysActions(BuildContext context, List<dynamic> ponds) {
    return Consumer(
      builder: (context, ref, child) {
        final actions = _getTodaysActions(ref, ponds);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's actions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1C1C),
              ),
            ),
            const SizedBox(height: 16),
            ...actions.map((action) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TodayActionCard(
                    title: action['title'],
                    description: action['description'],
                    priority: action['priority'],
                    icon: action['icon'],
                    onTap: action['onTap'],
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildOverview(BuildContext context, List<dynamic> ponds) {
    return Consumer(
      builder: (context, ref, child) {
        final growthData = _getGrowthOverview(ref, ponds);
        final riskData = _getRiskOverview(ref, ponds);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1C1C),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                OverviewCard(
                  title: 'Growth overview',
                  data: growthData,
                ),
                OverviewCard(
                  title: 'Risk overview',
                  data: riskData,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.inventory_2_outlined,
                    title: 'Inventory',
                    subtitle: 'Check stocks',
                    onTap: () {
                      Navigator.of(context).pushNamed('/inventory_dashboard');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: QuickActionButton(
                    icon: Icons.payments_outlined,
                    title: 'Expenses',
                    subtitle: 'Track spend',
                    onTap: () {
                      // TODO: Navigate to expenses
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivePonds(BuildContext context, List<dynamic> ponds) {
    return Consumer(
      builder: (context, ref, child) {
        final activePonds =
            ponds.where((p) => p.status != 'completed').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activePonds.length} active ponds',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006A3A),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      'Active ponds',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1C1C),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to all ponds
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A3A),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.6,
              ),
              itemCount: activePonds.length,
              itemBuilder: (context, index) {
                final pond = activePonds[index];
                return PondCard(
                  pond: pond,
                  onTap: () {
                    // TODO: Navigate to pond details
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Data calculation methods
  double _calculateTotalFeed(WidgetRef ref, List<dynamic> ponds) {
    double total = 0;
    for (final pond in ponds) {
      final history = ref.watch(feedHistoryProvider)[pond.id] ?? [];
      if (history.isNotEmpty) {
        total += history.first.cumulative;
      }
    }
    return total;
  }

  double _calculateTodayFeed(WidgetRef ref, List<dynamic> ponds) {
    double total = 0;
    final today = DateTime.now();
    for (final pond in ponds) {
      final history = ref.watch(feedHistoryProvider)[pond.id] ?? [];
      final todayHistory = history
          .where((h) =>
              h.date.year == today.year &&
              h.date.month == today.month &&
              h.date.day == today.day)
          .toList();
      total += todayHistory.fold(0.0, (sum, h) => sum + h.total);
    }
    return total;
  }

  double _calculateTotalFeedCost(WidgetRef ref, List<dynamic> ponds) {
    final totalFeed = _calculateTotalFeed(ref, ponds);
    return totalFeed * 35; // Assuming ₹35 per kg
  }

  double _calculateEstimatedBiomass(WidgetRef ref, List<dynamic> ponds) {
    double total = 0;
    for (final pond in ponds) {
      final growthLogs = ref.watch(growthProvider(pond.id));
      if (growthLogs.isNotEmpty) {
        final lastLog = growthLogs.first;
        final survival = _getSurvivalRate(lastLog.doc);
        total += (pond.seedCount * survival * lastLog.abw) / 1000;
      }
    }
    return total;
  }

  double _calculateEstimatedProfit(WidgetRef ref, List<dynamic> ponds) {
    final biomass = _calculateEstimatedBiomass(ref, ponds);
    final feedCost = _calculateTotalFeedCost(ref, ponds);
    final revenue = biomass * 300; // Assuming ₹300 per kg
    return revenue - feedCost;
  }

  double _calculateFarmHealthScore(WidgetRef ref, List<dynamic> ponds) {
    if (ponds.isEmpty) return 0;

    double totalScore = 0;
    for (final pond in ponds) {
      final growthLogs = ref.watch(growthProvider(pond.id));
      final history = ref.watch(feedHistoryProvider)[pond.id] ?? [];

      double pondScore = 50; // Base score

      // Growth score
      if (growthLogs.isNotEmpty) {
        final lastLog = growthLogs.first;
        final expectedAbw = _getExpectedABW(lastLog.doc);
        final ratio = lastLog.abw / expectedAbw;
        if (ratio >= 0.9)
          pondScore += 25;
        else if (ratio >= 0.8)
          pondScore += 15;
        else if (ratio >= 0.7) pondScore += 5;
      }

      // FCR score
      if (history.isNotEmpty) {
        final fcr = _calculateFCR(ref, pond);
        if (fcr <= 1.2)
          pondScore += 25;
        else if (fcr <= 1.4)
          pondScore += 15;
        else if (fcr <= 1.6) pondScore += 5;
      }

      totalScore += pondScore;
    }

    return totalScore / ponds.length;
  }

  List<Map<String, dynamic>> _getTodaysActions(
      WidgetRef ref, List<dynamic> ponds) {
    final actions = <Map<String, dynamic>>[];

    for (final pond in ponds) {
      final growthLogs = ref.watch(growthProvider(pond.id));
      final history = ref.watch(feedHistoryProvider)[pond.id] ?? [];

      // Check for high FCR
      if (history.isNotEmpty) {
        final fcr = _calculateFCR(ref, pond);
        if (fcr > 1.8) {
          actions.add({
            'title': 'Reduce feed by 10-15% today',
            'description': '${pond.name}: Feed ratio exceeded limits.',
            'priority': 'critical',
            'icon': Icons.scale_outlined,
            'onTap': () {
              // TODO: Navigate to feed adjustment
            },
          });
        }
      }

      // Check for sampling needed
      if (growthLogs.isNotEmpty) {
        final lastLog = growthLogs.first;
        final daysSinceLastSample =
            DateTime.now().difference(lastLog.date).inDays;
        if (daysSinceLastSample > 14) {
          actions.add({
            'title': 'Do sampling today',
            'description': '${pond.name}: Critical for biomass estimation.',
            'priority': 'warning',
            'icon': Icons.biotech_outlined,
            'onTap': () {
              // TODO: Navigate to sampling
            },
          });
        }
      }
    }

    // Add healthy ponds
    final healthyPonds = ponds.length - actions.length;
    if (healthyPonds > 0) {
      actions.add({
        'title':
            '✅ ${healthyPonds} pond${healthyPonds > 1 ? 's' : ''} running well',
        'description': '',
        'priority': 'success',
        'icon': Icons.check_circle_outline,
        'onTap': null,
      });
    }

    return actions.take(3).toList();
  }

  List<Map<String, dynamic>> _getGrowthOverview(
      WidgetRef ref, List<dynamic> ponds) {
    int good = 0, slow = 0;

    for (final pond in ponds) {
      final growthLogs = ref.watch(growthProvider(pond.id));
      if (growthLogs.isNotEmpty) {
        final lastLog = growthLogs.first;
        final expectedAbw = _getExpectedABW(lastLog.doc);
        final ratio = lastLog.abw / expectedAbw;
        if (ratio >= 0.9)
          good++;
        else if (ratio < 0.8) slow++;
      }
    }

    return [
      {'count': good, 'status': 'Good', 'color': Color(0xFF006A3A)},
      {'count': slow, 'status': 'Slow', 'color': Color(0xFFFFC107)},
    ];
  }

  List<Map<String, dynamic>> _getRiskOverview(
      WidgetRef ref, List<dynamic> ponds) {
    int critical = 0, healthy = 0;

    for (final pond in ponds) {
      final history = ref.watch(feedHistoryProvider)[pond.id] ?? [];
      if (history.isNotEmpty) {
        final fcr = _calculateFCR(ref, pond);
        if (fcr > 1.8)
          critical++;
        else if (fcr <= 1.4) healthy++;
      }
    }

    return [
      {
        'count': critical,
        'status': 'pond needs immediate attention',
        'color': Color(0xFFE53935)
      },
      {'count': healthy, 'status': 'Healthy', 'color': Color(0xFF006A3A)},
    ];
  }

  double _calculateFCR(WidgetRef ref, dynamic pond) {
    final history = ref.watch(feedHistoryProvider)[pond.id] ?? [];
    final growthLogs = ref.watch(growthProvider(pond.id));

    if (history.isEmpty || growthLogs.isEmpty) return 0;

    final totalFeed = history.first.cumulative;
    final lastLog = growthLogs.first;
    final survival = _getSurvivalRate(lastLog.doc);
    final biomass = (pond.seedCount * survival * lastLog.abw) / 1000;

    return biomass > 0 ? totalFeed / biomass : 0;
  }

  double _getSurvivalRate(int doc) {
    if (doc > 60) return 0.90;
    if (doc > 30) return 0.95;
    return 1.0;
  }

  double _getExpectedABW(int doc) {
    // Simple expected ABW calculation - can be improved
    if (doc <= 30) return doc * 0.1;
    if (doc <= 60) return 3 + (doc - 30) * 0.2;
    return 9 + (doc - 60) * 0.15;
  }
}
