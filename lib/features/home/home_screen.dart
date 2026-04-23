import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../core/language/app_localizations.dart';
import '../../core/services/admin_security_service.dart';
import '../../routes/app_routes.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Admin access tracking
  int _tapCount = 0;
  DateTime? _lastTapTime;
  static const Duration _tapResetTime = Duration(seconds: 3);
  static const int _requiredTaps = 5;

  void _handleFarmNameTap() {
    final adminService = AdminSecurityService();
    final user = Supabase.instance.client.auth.currentUser;

    if (adminService.isAdmin(user)) {
      final now = DateTime.now();

      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) > _tapResetTime) {
        _tapCount = 0;
      }

      _tapCount++;
      _lastTapTime = now;

      if (_tapCount >= _requiredTaps) {
        _tapCount = 0;
        _showAdminPasscodeDialog();
      }
    }
  }

  void _showAdminPasscodeDialog() {
    final TextEditingController passcodeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter admin passcode:'),
            const SizedBox(height: 16),
            TextField(
              controller: passcodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: '4-digit passcode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final passcode = passcodeController.text.trim();
              Navigator.of(dialogContext).pop();

              if (passcode.isEmpty) return;

              try {
                final adminService = AdminSecurityService();
                final isValid =
                    await adminService.validateAdminAccess(passcode);

                if (mounted) {
                  if (isValid) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Admin access granted! Session active for 15 minutes.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid passcode'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    if (currentFarm == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).t('home')),
          backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context, currentFarm.name),
              _buildSummaryCards(context, ponds),
              const SizedBox(height: 24),
              _buildInventoryExpenseActions(context),
              const SizedBox(height: 24),
              _buildTodaysActions(context, ponds),
              const SizedBox(height: 24),
              _buildActivePonds(context, ponds),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
    );
  }

  Widget _buildHeader(BuildContext context, String farmName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.agriculture,
              color: Color(0xFF16A34A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _handleFarmNameTap,
              child: Text(
                farmName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Implement notifications
            },
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF6B7280),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, List<dynamic> ponds) {
    // Calculate real data from ponds
    double totalFeed = 0.0;
    double todayFeed = 0.0;
    double totalFeedCost = 0.0;
    double estimatedBiomass = 0.0;
    double estimatedProfit = 0.0;

    for (final pond in ponds) {
      if (pond == null) continue;

      // Get feed data
      final pondId = pond.id.toString();
      final history = ref.watch(feedHistoryProvider)[pondId] ?? [];
      final today = DateTime.now();

      for (final entry in history) {
        final feedAmount = (entry.total as num?)?.toDouble() ?? 0.0;
        totalFeed += feedAmount;

        if (entry.date.year == today.year &&
            entry.date.month == today.month &&
            entry.date.day == today.day) {
          todayFeed += feedAmount;
        }
      }

      // Calculate biomass and profit
      final growthLogs = ref.watch(growthProvider(pondId));
      if (growthLogs.isNotEmpty) {
        final lastLog = growthLogs.first;
        final seedCount = (pond.seedCount as num?)?.toInt() ?? 0;
        final survival = _getSurvivalRate(pond.doc);
        final biomass = (seedCount * survival * lastLog.abw) / 1000;
        estimatedBiomass += biomass;

        // Simple profit calculation (biomass * market price - feed cost)
        estimatedProfit += (biomass * 300) -
            (totalFeed * 80); // Assuming ₹300/kg for shrimp, ₹80/kg for feed
      }
    }

    totalFeedCost = totalFeed * 80; // Assuming ₹80/kg for feed

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildSummaryCard(
                      'TOTAL FEED', '${totalFeed.toStringAsFixed(0)} kg')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildSummaryCard(
                      'TODAY FEED', '${todayFeed.toStringAsFixed(0)} kg')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildSummaryCard('TOTAL FEED COST',
                      '₹${(totalFeedCost / 100000).toStringAsFixed(1)}L')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildSummaryCard('ESTIMATED BIOMASS',
                      '${estimatedBiomass.toStringAsFixed(0)} kg')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildSummaryCard('ESTIMATED PROFIT',
                      '₹${(estimatedProfit / 100000).toStringAsFixed(1)}L')),
              const SizedBox(width: 12),
              Expanded(child: _buildFarmHealthCard(ponds)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmHealthCard(List<dynamic> ponds) {
    // Calculate health score based on FCR values
    double totalHealthScore = 0.0;
    int pondCount = 0;

    for (final pond in ponds) {
      if (pond == null) continue;

      final fcr = _calculateFCR(pond);
      if (fcr > 0) {
        // Convert FCR to health score (lower FCR = better health)
        double healthScore = 100.0;
        if (fcr > 2.0)
          healthScore = 60;
        else if (fcr > 1.8)
          healthScore = 70;
        else if (fcr > 1.5)
          healthScore = 80;
        else if (fcr > 1.3) healthScore = 90;

        totalHealthScore += healthScore;
        pondCount++;
      }
    }

    final avgHealthScore = pondCount > 0 ? totalHealthScore / pondCount : 100.0;
    final healthScoreInt = avgHealthScore.round();

    String status;
    Color statusColor;
    if (healthScoreInt >= 90) {
      status = 'Excellent';
      statusColor = const Color(0xFF16A34A);
    } else if (healthScoreInt >= 70) {
      status = 'Good';
      statusColor = const Color(0xFF16A34A);
    } else {
      status = 'Needs Attention';
      statusColor = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FARM HEALTH STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$healthScoreInt',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 3),
                ),
                child: Center(
                  child: Text(
                    'HEALTHY',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryExpenseActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INVENTORY & EXPENSE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Inventory',
                  Icons.inventory_2_rounded,
                  Colors.blue,
                  () {
                    Navigator.pushNamed(context, AppRoutes.inventoryDashboard);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Expense',
                  Icons.receipt_long_rounded,
                  Colors.orange,
                  () {
                    final farmState = ref.read(farmProvider);
                    final currentFarm = farmState.currentFarm;
                    if (currentFarm != null) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addExpense,
                        arguments: {
                          'cropId': currentFarm.id,
                          'farmId': currentFarm.id,
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select a farm first')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysActions(BuildContext context, List<dynamic> ponds) {
    final actions = <Map<String, dynamic>>[];

    // Generate actions based on pond data
    for (final pond in ponds) {
      if (pond == null) continue;

      final fcr = _calculateFCR(pond);
      final pondId = pond.id.toString();
      final growthLogs = ref.watch(growthProvider(pondId));

      // Check for high FCR
      if (fcr > 1.8) {
        actions.add({
          'title': 'Reduce feed by 10-15% today',
          'description':
              '${pond.name ?? 'Pond $pondId'}: Feed ratio exceeded limits.',
          'color': const Color(0xFFFEE2E2),
          'iconColor': const Color(0xFFDC2626),
          'icon': Icons.warning,
        });
      }

      // Check for sampling needed
      if (growthLogs.isEmpty ||
          (growthLogs.isNotEmpty &&
              DateTime.now().difference(growthLogs.first.date).inDays > 14)) {
        actions.add({
          'title': 'Do sampling today',
          'description':
              '${pond.name ?? 'Pond $pondId'}: Critical for biomass estimation.',
          'color': const Color(0xFFFEF3C7),
          'iconColor': const Color(0xFFD97706),
          'icon': Icons.schedule,
        });
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          ...actions.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActionCard(
                  action['color'],
                  action['iconColor'],
                  action['icon'],
                  action['title'],
                  action['description'],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionCard(Color backgroundColor, Color iconColor, IconData icon,
      String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePonds(BuildContext context, List<dynamic> ponds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ponds.length} ACTIVE PONDS',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/pond-dashboard');
                },
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ponds.map((pond) => _buildPondCard(pond)).toList(),
        ],
      ),
    );
  }

  Widget _buildPondCard(dynamic pond) {
    String status;
    Color statusColor;
    String? actionText;

    final fcr = _calculateFCR(pond);

    if (fcr > 1.8) {
      status = 'CRITICAL';
      statusColor = const Color(0xFFDC2626);
      actionText = '⚠️ REDUCE FEED BY 10-15% TODAY';
    } else if (fcr > 1.4) {
      status = 'WARNING';
      statusColor = const Color(0xFFD97706);
      actionText = '⚠️ DO SAMPLING TODAY';
    } else {
      status = 'GOOD';
      statusColor = const Color(0xFF16A34A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              if (actionText != null)
                Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${((pond.area as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)} AC',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      '${(((pond.seedCount as num?)?.toInt() ?? 0) / 100000).toStringAsFixed(1)} LAC',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'DOC',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      '${(pond.doc as num?)?.toInt() ?? 0}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'FEED (D)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      _calculateTodayFeed(pond).toStringAsFixed(0) + ' kg',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'FCR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      fcr > 0 ? fcr.toStringAsFixed(1) : '--',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculateFCR(dynamic pond) {
    try {
      final pondId = pond.id.toString();
      final history = ref.read(feedHistoryProvider)[pondId] ?? [];

      if (history.isEmpty) return 0.0;

      double totalFeed = 0.0;

      for (final entry in history) {
        totalFeed += (entry.total as num?)?.toDouble() ?? 0.0;
      }

      final growthLogs = ref.read(growthProvider(pondId));
      if (growthLogs.isNotEmpty) {
        final lastLog = growthLogs.first;
        final seedCount = (pond.seedCount as num?)?.toInt() ?? 0;
        final survival = _getSurvivalRate(pond.doc);
        final biomass = (seedCount * survival * lastLog.abw) / 1000;

        return biomass > 0 ? totalFeed / biomass : 0.0;
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateTodayFeed(dynamic pond) {
    try {
      final pondId = pond.id.toString();
      final history = ref.read(feedHistoryProvider)[pondId] ?? [];
      final today = DateTime.now();

      double todayFeed = 0.0;
      for (final entry in history) {
        if (entry.date.year == today.year &&
            entry.date.month == today.month &&
            entry.date.day == today.day) {
          todayFeed += (entry.total as num?)?.toDouble() ?? 0.0;
        }
      }

      return todayFeed;
    } catch (e) {
      return 0.0;
    }
  }

  double _getSurvivalRate(int? doc) {
    if (doc == null || doc <= 0) return 0.85;
    if (doc <= 30) return 0.90;
    if (doc <= 60) return 0.85;
    if (doc <= 90) return 0.80;
    return 0.75;
  }
}
