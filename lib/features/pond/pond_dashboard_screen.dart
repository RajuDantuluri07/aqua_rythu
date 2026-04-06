import '../supplements/supplement_mix_screen.dart';
import '../supplements/screens/supplement_item.dart';
import '../supplements/supplement_provider.dart';
import '../../services/farm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_schedule_screen.dart';
import 'pond_dashboard_provider.dart';
import 'package:aqua_rythu/features/tray/tray_log_screen.dart';
import '../../features/tray/tray_provider.dart';
import '../tray/tray_model.dart';
import '../farm/farm_provider.dart';
import '../harvest/harvest_provider.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';
import '../supplements/supplement_provider.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../feed/feed_timeline_card.dart';
import '../feed/smart_feed_provider.dart';
import '../water/water_test_screen.dart';
import '../feed/feed_history_screen.dart';
import '../harvest/harvest_screen.dart';
import '../growth/sampling_screen.dart';
import '../farm/new_cycle_setup_screen.dart';
import '../harvest/harvest_summary_screen.dart';
import 'package:intl/intl.dart';
import 'package:aqua_rythu/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _showFeedScheduleTip = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkFeedScheduleTip();
  }

  Future<void> _checkFeedScheduleTip() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('feed_schedule_tip_pending') ?? false;
    if (pending && mounted) {
      await prefs.remove('feed_schedule_tip_pending');
      setState(() => _showFeedScheduleTip = true);
      _pulseController.repeat(reverse: true);
      // Stop after ~4 seconds (5 pulses)
      Future.delayed(const Duration(milliseconds: 4000), () {
        if (mounted) {
          _pulseController.stop();
          _pulseController.animateTo(0);
          setState(() => _showFeedScheduleTip = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Round state machine
  // DOC ≤ 30: next round unlocks once prev feed is marked done
  // DOC > 30: next round unlocks only AFTER prev feed done AND prev tray logged
  Map<String, dynamic> _getSimpleRoundState({
    required int doc,
    required int round,
    required int totalRounds,
    required Map<int, bool> feedDone,
    required Map<int, bool> trayDone,
  }) {
    final isDone = feedDone[round] ?? false;
    final isTrayLogged = trayDone[round] ?? false;
    final isLocked = _isLocked(doc, round, feedDone, trayDone);
    // Current = first round that is not fully cleared
    // For DOC > 30: a round is "cleared" only when both feed done AND tray logged
    final currentRound = _getCurrentRound(doc, feedDone, trayDone, totalRounds);
    final isCurrent = !isDone && round == currentRound;
    // Tray CTA: feed done but tray not yet logged, DOC > 30 only
    final showTrayCTA = isDone && doc > 30 && !isTrayLogged;

    return {
      'isDone': isDone,
      'isCurrent': isCurrent,
      'isLocked': isLocked,
      'showTrayCTA': showTrayCTA,
      'isTrayLogged': isTrayLogged,
    };
  }

  /// Returns the next round that needs action (feed or tray).
  /// DOC ≤ 30: first round where feed is not done.
  /// DOC > 30: first round where feed is not done, but only after previous
  ///           round's tray is logged.
  int _getCurrentRound(int doc, Map<int, bool> feedDone,
      Map<int, bool> trayDone, int totalRounds) {
    for (int i = 1; i <= totalRounds; i++) {
      if (!(feedDone[i] ?? false)) return i;
      // DOC > 30: if this round's feed is done but tray not logged,
      // it still "owns" the current slot — next round stays locked
      if (doc > 30 && !(trayDone[i] ?? false)) return i;
    }
    return totalRounds + 1;
  }

  /// A round is locked when the previous round is not fully cleared.
  /// DOC ≤ 30: cleared = feed done.
  /// DOC > 30: cleared = feed done AND tray logged.
  bool _isLocked(int doc, int round, Map<int, bool> feedDone,
      Map<int, bool> trayDone) {
    if (round <= 1) return false;
    final prev = round - 1;
    final prevFeedDone = feedDone[prev] ?? false;
    if (!prevFeedDone) return true;
    // For DOC > 30, also require previous tray to be logged
    if (doc > 30 && !(trayDone[prev] ?? false)) return true;
    return false;
  }

List<SupplementItem> _getPlannedFeedSupplements(
      List<Supplement> supplements, String feedingTime, double feedQty) {
    final items = <SupplementItem>[];
    for (final supplement in supplements) {
      if (supplement.type != SupplementType.feedMix) {
        continue;
      }
      if (supplement.isPaused || !supplement.feedingTimes.contains(feedingTime)) {
        continue;
      }
      items.addAll(supplement.calculateDosage(feedQty));
    }
    return items;
  }

  List<SupplementItem> _getAppliedFeedSupplements(
      int round, List<SupplementLog> logs) {
    final items = <SupplementItem>[];
    final roundLogs = logs
        .where((log) =>
            log.supplementType == SupplementType.feedMix &&
            log.feedRound == round)
        .toList();
    for (final log in roundLogs) {
      for (final item in log.appliedItems) {
        items.add(
          SupplementItem(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            type: 'feed',
          ),
        );
      }
    }
    return items;
  }

  bool _logFeedSupplementApplication({
    required String pondId,
    required String pondName,
    required int round,
    required double feedQty,
    required List<Supplement> activePlansToday,
  }) {
    if (feedQty <= 0) {
      return false;
    }
    final alreadyLogged = ref.read(supplementLogProvider.notifier).hasFeedLogForRoundOnDate(
          pondId: pondId,
          round: round,
          date: DateTime.now(),
        );
    if (alreadyLogged) {
      return true;
    }

    final roundKey = "R$round";
    final matchingPlans = activePlansToday
        .where((plan) =>
            plan.type == SupplementType.feedMix &&
            !plan.isPaused &&
            plan.feedingTimes.contains(roundKey))
        .toList();
    if (matchingPlans.isEmpty) {
      return false;
    }

    var loggedAny = false;
    for (final plan in matchingPlans) {
      final appliedItems = plan.calculateAppliedItems(feedKg: feedQty);
      if (appliedItems.isEmpty) {
        continue;
      }
      loggedAny = true;
      ref.read(supplementLogProvider.notifier).logApplication(
            supplementId: plan.id,
            pondId: pondId,
            pondName: pondName,
            items: appliedItems,
            supplementName: plan.goal != null ? plan.name : plan.name,
            supplementType: SupplementType.feedMix,
            feedRound: round,
            inputValue: feedQty,
            inputUnit: 'kg',
          );
    }
    return loggedAny;
  }

  DateTime _waterPlanScheduleForDay(Supplement plan, DateTime day) {
    final baseDate = plan.date ?? day;
    final dateOnly = DateTime(day.year, day.month, day.day);
    final timeValue = plan.effectiveWaterTime ?? '';
    try {
      final parts = timeValue.split(':');
      if (parts.length == 2) {
        return DateTime(
          dateOnly.year,
          dateOnly.month,
          dateOnly.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return DateTime(dateOnly.year, dateOnly.month, dateOnly.day, baseDate.hour, baseDate.minute);
  }

  String _formatWaterTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  bool _logWaterSupplementApplication({
    required String pondId,
    required String pondName,
    required double pondArea,
    required Supplement plan,
    required DateTime scheduledAt,
  }) {
    if (pondArea <= 0) {
      return false;
    }
    final alreadyLogged =
        ref.read(supplementLogProvider.notifier).hasWaterLogForSupplementOnDate(
              pondId: pondId,
              supplementId: plan.id,
              date: scheduledAt,
            );
    if (alreadyLogged) {
      return true;
    }

    final appliedItems = plan.calculateAppliedItems(pondArea: pondArea);
    if (appliedItems.isEmpty) {
      return false;
    }

    ref.read(supplementLogProvider.notifier).logApplication(
          supplementId: plan.id,
          pondId: pondId,
          pondName: pondName,
          items: appliedItems,
          supplementName: plan.name,
          scheduledTime: _formatWaterTime(scheduledAt),
          supplementType: SupplementType.waterMix,
          inputValue: pondArea,
          inputUnit: 'acre',
          scheduledAt: scheduledAt,
        );
    return true;
  }

  List<Map<String, dynamic>> _getFeedRounds() {
    return [
      {"round": 1, "time": "06:00 AM", "key": "R1"},
      {"round": 2, "time": "10:00 AM", "key": "R2"},
      {"round": 3, "time": "02:00 PM", "key": "R3"},
      {"round": 4, "time": "06:00 PM", "key": "R4"},
    ];
  }

  void openTray(int round, bool isLocked) async {
    if (isLocked) {
      return;
    }
    final selectedPond = ref.read(pondDashboardProvider).selectedPond;
    final doc = ref.read(docProvider(selectedPond));

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrayLogScreen(
          pondId: selectedPond,
          doc: doc,
          round: round,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      ref.read(pondDashboardProvider.notifier).logTray(round);
    }
  }

  void _showFarmSwitchDialog(FarmState farmState) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Select Farm"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: [
          ...farmState.farms.map((farm) {
            final isSelected = farm.id == farmState.selectedId;
            return SimpleDialogOption(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              onPressed: () {
                ref.read(farmProvider.notifier).selectFarm(farm.id);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(Icons.landscape,
                      color: isSelected ? Colors.green : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      farm.name,
                      style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                ],
              ),
            );
          }),
          const Divider(),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () {
              Navigator.pop(context);
              _showAddFarmDialog();
            },
            child: Row(
              children: [
                Icon(Icons.add_circle_outline,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  "Add New Farm",
                  style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFarmDialog() {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Farm"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Farm Name",
                hintText: "e.g. Sri Rama Farm",
                border: OutlineInputBorder(),
              ),
            ),
            AppSpacing.hBase,
            TextField(
              controller: locCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Location",
                hintText: "e.g. Nellore",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                try {
                  final farmService = FarmService();
                  await farmService.createFarm(
                    name: nameCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                    farmType: 'Semi-Intensive',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Farm created successfully')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Create Farm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final selectedPond = dashboardState.selectedPond;
    final today = ref.watch(todayProvider);
    final oneWeekAgo = ref.watch(oneWeekAgoProvider);

    // Notify user when feed plan was silently regenerated (auto-recovery)
    ref.listen<PondDashboardState>(pondDashboardProvider, (previous, next) {
      if (next.feedAutoRecovered && !(previous?.feedAutoRecovered ?? false)) {
        ref.read(pondDashboardProvider.notifier).clearAutoRecoveredFlag();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Feed plan was missing and has been regenerated automatically.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });

    // Safe argument handling — provider is the single source of truth for feed data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments as String?;
      if (args != null && args.isNotEmpty && args != selectedPond) {
        ref.read(pondDashboardProvider.notifier).selectPond(args);
      } else if (selectedPond.isEmpty) {
        // Auto-select first pond (e.g. after first pond creation redirect)
        final ponds = ref.read(farmProvider).currentFarm?.ponds ?? [];
        if (ponds.isNotEmpty) {
          ref.read(pondDashboardProvider.notifier).selectPond(ponds.first.id);
        }
      } else if (selectedPond.isNotEmpty &&
          dashboardState.roundFeedAmounts.isEmpty &&
          !dashboardState.isFeedLoading) {
        ref.read(pondDashboardProvider.notifier).loadTodayFeed(selectedPond);
      }
    });

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    final currentPond = ponds.isNotEmpty
        ? ponds.firstWhere(
            (p) => p.id == selectedPond,
            orElse: () => ponds.first,
          )
        : null;  // ✅ CLEANED: Return null if no ponds - let UI handle gracefully

    /// ⚠️ HANDLED: Check for no farms first, then no ponds
    if (currentPond == null) {
      // Case 1: No farms exist - show message without CTA
      if (farmState.farms.isEmpty) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text("Ponds"),
            centerTitle: true,
          ),
          bottomNavigationBar: const AppBottomBar(currentIndex: 0),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.landscape_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "No farms created",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create a farm first to add ponds",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Case 2: Farm exists but no ponds - show Add First Pond button
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("Ponds"),
          centerTitle: true,
        ),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.water_drop_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  "No ponds found",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a new pond to get started",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.addPond);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add First Pond"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCompleted = currentPond.status == PondStatus.completed;

    final allSupplements = ref.watch(supplementProvider);
    final activePlansToday = allSupplements.where((plan) {
      return plan.appliesToPond(selectedPond) &&
          plan.isActiveOnDate(DateTime.now()) &&
          !plan.isPaused;
    }).toList();

    /// ✅ TRAY DATA
    final trayLogs = ref.watch(trayProvider(selectedPond));

    final Map<int, TrayLog> todayTrayMap = {
      for (var log in trayLogs)
        if (log.time.year == today.year &&
            log.time.month == today.month &&
            log.time.day == today.day)
          log.round: log
    };
    final Map<int, bool> trayDone =
        todayTrayMap.map((key, value) => MapEntry(key, true));

    /// EMPTY STATE
    if (currentFarm != null && currentFarm.ponds.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop_outlined,
                    size: 64, color: Colors.grey),
                AppSpacing.hBase,
                Text("No Ponds in ${currentFarm.name}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                AppSpacing.hM,
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.addPond);
                  },
                  child: const Text("Add First Pond"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentDoc = ref.watch(docProvider(selectedPond));

    /// ✅ CURRENT STATS
    final history = ref.watch(feedHistoryProvider)[selectedPond] ?? [];
    final totalFeedToDate = history.isNotEmpty ? history.first.cumulative : 0.0;

    final growthLogs = ref.watch(growthProvider(selectedPond));

    double pondFcr = 0.0;
    double currentAbw = 0.0;

    if (growthLogs.isNotEmpty) {
      final lastLog = growthLogs.first;
      currentAbw = lastLog.abw;
      double survival = 1.0;
      if (currentDoc > 60) {
        survival = 0.90;
      } else if (currentDoc > 30) {
        survival = 0.95;
      }

      final biomass =
          (currentPond.seedCount * survival * lastLog.averageBodyWeight) / 1000;
      if (biomass > 0) {
        pondFcr = totalFeedToDate / biomass;
      }
    }

    /// ✅ PREVIOUS WEEK STATS
    double prevFcr = 0.0;
    final prevHistoryLog = history.firstWhere(
      (h) => h.date.isBefore(oneWeekAgo),
      orElse: () => FeedHistoryLog(
          date: DateTime(2000),
          doc: 0,
          rounds: [],
          trayStatuses: [],
          expected: 0,
          cumulative: 0),
    );

    // Get growth log from approx 7 days ago
    final prevGrowthLog = growthLogs.isEmpty
        ? null
        : growthLogs.firstWhere(
            (l) => l.date.isBefore(oneWeekAgo),
            orElse: () =>
                growthLogs.last, // Fallback to oldest log if no weekly history
          );

    double prevAbw = 0.0;
    if (prevHistoryLog.doc > 0 && prevGrowthLog != null) {
      prevAbw = prevGrowthLog.abw;
      double prevSurvival = 1.0;
      if (prevGrowthLog.doc > 60) {
        prevSurvival = 0.90;
      } else if (prevGrowthLog.doc > 30) {
        prevSurvival = 0.95;
      }

      final prevBiomass = (currentPond.seedCount *
              prevSurvival *
              prevGrowthLog.averageBodyWeight) /
          1000;
      if (prevBiomass > 0) {
        prevFcr = prevHistoryLog.cumulative / prevBiomass;
      }
    } else if (prevGrowthLog != null) {
      // Fallback for ABW if no history log found but growth log exists
      prevAbw = prevGrowthLog.abw;
    }

    // Trend: Current - Previous
    // For FCR, negative trend (decrease) is GOOD.
    final double fcrTrend =
        (pondFcr > 0 && prevFcr > 0) ? (pondFcr - prevFcr) : 0;
    // For ABW, positive trend is GOOD.
    final double abwTrend =
        (currentAbw > 0 && prevAbw > 0) ? (currentAbw - prevAbw) : 0;

    final supplementLogs = ref.watch(supplementLogProvider);
    final now = DateTime.now();
    final todaySupplementLogs = supplementLogs
        .where((l) =>
            l.pondId == selectedPond &&
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day)
        .toList();

    // Both planned and consumed come from provider state (single source of truth)
    final double plannedFeed = dashboardState.roundFeedAmounts.values
        .fold(0.0, (sum, v) => sum + v);

    final double consumedFeed = dashboardState.roundFeedStatus.entries
        .where((e) => e.value == 'completed')
        .fold(0.0, (sum, e) => sum + (dashboardState.roundFeedAmounts[e.key] ?? 0.0));

    // Enable Smart Feed when DOC is 30 or when pond has Smart Feed enabled
    final isSmartFeedEnabled = (currentPond?.isSmartFeedEnabled ?? false) || (currentDoc >= 30);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LEFT: Logo + App Name
                  Row(
                    children: [
                      // Replaced Icon with Real Logo Asset
                      Image.asset(
                        'assets/images/logo.png',
                        height: 40,
                        errorBuilder: (c, o, s) => Icon(Icons.water_drop,
                            color: Theme.of(context).primaryColor, size: 32),
                      ),
                      AppSpacing.wM,
                      const Text(
                        "AquaRythu",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                    ],
                  ),

                  // RIGHT: Farm Selector
                  InkWell(
                    onTap: () => _showFarmSwitchDialog(farmState),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: AppSpacing.s + 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.eco_rounded,
                              size: 16, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            currentFarm?.name ?? "No Farm",
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.grey.shade800),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              AppSpacing.hBase,

              /// POND TABS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...ponds.map((pond) {
                      bool isSelected = pond.id == selectedPond;

                      final hasFeed = true;
                      final hasHarvest =
                          ref.watch(harvestProvider(pond.id)).isNotEmpty;

                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(pondDashboardProvider.notifier)
                              .selectPond(pond.id);
                        },
                        onLongPress: () {
                          if (hasFeed || hasHarvest) {
                            return;
                          }

                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text("Delete Pond?"),
                                content: Text(
                                    "Are you sure you want to delete '${pond.name}'? This action cannot be undone."),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text("Delete"),
                                    onPressed: () {
                                      if (currentFarm != null) {
                                        ref
                                            .read(farmProvider.notifier)
                                            .deletePond(
                                                currentFarm.id, pond.id);
                                      }
                                      Navigator.of(dialogContext).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.only(right: AppSpacing.s + 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.base,
                              vertical: AppSpacing.s + 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade200,
                            borderRadius: AppRadius.rl,
                          ),
                          child: Text(
                            pond.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    }),

                    // Add Pond Button (Moved from Header)
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.addPond),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.base,
                            vertical: AppSpacing.s + 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.rl,
                          border:
                              Border.all(color: Theme.of(context).primaryColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add,
                                size: 16,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 4),
                            Text("Pond",
                                style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AppSpacing.hBase,

              /// QUICK STATS STRIP
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.rm,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    _kpi("DOC", "$currentDoc Days",
                        Icons.calendar_today_rounded, Colors.orange),
                    _divider(),
                    _kpi("AREA", "${currentPond.area} Ac",
                        Icons.straighten_rounded, Colors.blue),
                    _divider(),
                    _kpi(
                        "STOCKING",
                        currentPond.seedCount > 0
                            ? "${(currentPond.seedCount / 1000).toStringAsFixed(0)}K"
                            : "--",
                        Icons.set_meal_rounded,
                        Colors.teal),
                  ],
                ),
              ),

              AppSpacing.hBase,

              /// TANK OPERATIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OperationButton(
                    label: "Sampling",
                    icon: Icons.texture, // Fishnet/mesh icon representation
                    color: Colors.purple,
                    onTap: () {
                      if (isCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    "Sampling is locked for completed ponds")));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    SamplingScreen(pondId: selectedPond)));
                      }
                    },
                  ),
                  _OperationButton(
                    label: "Water",
                    icon: Icons.water_drop_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      if (isCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "Water test is locked for completed ponds")));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    WaterTestScreen(pondId: selectedPond)));
                      }
                    },
                  ),
                  _OperationButton(
                    label: "Supplement",
                    icon: Icons.science_rounded,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SupplementMixScreen(pondId: selectedPond)),
                      );
                    },
                  ),
                  _OperationButton(
                    label: "Harvest",
                    icon: Icons.agriculture_rounded,
                    color: AppColors.warning,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => isCompleted
                                ? HarvestSummaryScreen(pondId: selectedPond)
                                : HarvestScreen(pondId: selectedPond))),
                  ),
                  _OperationButton(
                    label: "History",
                    icon: Icons.history_rounded,
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                FeedHistoryScreen(pondId: selectedPond))),
                  ),
                ],
              ),

              AppSpacing.hBase,

              if (isCompleted)
                _buildCompletedDashboard(context, ref, currentPond)
              else ...[
                /// 📊 COMBINED PLAN & SCHEDULE SECTION
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 70% Today Progress
                      Expanded(
                        flex: 7,
                        child: CompactProgressBar(
                          progress: plannedFeed == 0
                              ? 0
                              : (consumedFeed / plannedFeed).clamp(0, 1),
                          totalText:
                              "${consumedFeed.toStringAsFixed(1)} / ${plannedFeed.toStringAsFixed(1)} kg",
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 30-40% Feed Schedule
                      Expanded(
                        flex: 4,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) => Transform.scale(
                            scale: _showFeedScheduleTip ? _pulseAnim.value : 1.0,
                            child: child,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              // Dismiss tip on tap
                              if (_showFeedScheduleTip) {
                                _pulseController.stop();
                                setState(() => _showFeedScheduleTip = false);
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FeedScheduleScreen(pondId: selectedPond),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: _showFeedScheduleTip
                                    ? AppColors.primary.withOpacity(0.08)
                                    : Colors.white,
                                borderRadius: AppRadius.rm,
                                border: Border.all(
                                  color: _showFeedScheduleTip
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: _showFeedScheduleTip ? 1.8 : 1.0,
                                ),
                                boxShadow: _showFeedScheduleTip
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.30),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month_rounded,
                                      color: _showFeedScheduleTip
                                          ? AppColors.primary
                                          : AppColors.primary,
                                      size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "FEED SCHEDULE",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: _showFeedScheduleTip
                                            ? AppColors.primary
                                            : AppColors.textSecondary),
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

                AppSpacing.hM,

                if (currentDoc > 120) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: AppRadius.rs,
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Extended Culture Mode (DOC > 120). Efficiency may reduce - increase sampling frequency.",
                            style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.hS,
                ],

                /// TRAY INFO HINT (Moved)
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.textTertiary),
                      AppSpacing.wS,
                      Text(
                        _getTrayInfoText(currentDoc <= 30 ? 'blind' : 'smart'),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                AppSpacing.hS,

                /// DAILY TASKS TIMELINE
                if (dashboardState.isFeedLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                // DOC ≤ 30 with no plan → show empty state (plan should auto-generate)
                // DOC > 30 → always show timeline (amounts come from feed schedule;
                //   if not set yet, show 0.0 with edit button so farmer can fill in)
                else if (dashboardState.roundFeedAmounts.isEmpty && currentDoc <= 30)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text(
                            "No feed plan for today",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      ..._buildTimeline(
                        today: today,
                        currentDoc: currentDoc,
                        pondName: currentPond.name,
                        pondArea: currentPond.area,
                        todayTrayMap: todayTrayMap,
                        dashboardState: dashboardState,
                        trayDone: trayDone,
                        activePlansToday: activePlansToday,
                        todaySupplementLogs: todaySupplementLogs,
                        selectedPond: selectedPond,
                        smartFeedOutput: null, // Smart feed engine disabled - MVP
                        currentPond: currentPond,
                        isSmartFeedEnabled: isSmartFeedEnabled,
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeline({
    required DateTime today,
    required int currentDoc,
    required String pondName,
    required double pondArea,
    required Map<int, TrayLog> todayTrayMap,
    required PondDashboardState dashboardState,
    required Map<int, bool> trayDone,
    required List<Supplement> activePlansToday,
    required List<SupplementLog> todaySupplementLogs,
    required String selectedPond,
    required SmartFeedOutput? smartFeedOutput,
    required Pond? currentPond,
    required bool isSmartFeedEnabled,
  }) {
    final feedRoundsData = _getFeedRounds();
    final List<Map<String, dynamic>> timelineItems = [];


    // Add Feed Rounds
    for (var data in feedRoundsData) {
      final timeStr = data['time'] as String;
      DateTime sortTime;
      try {
        final dt = DateFormat("hh:mm a").parse(timeStr);
        sortTime =
            DateTime(today.year, today.month, today.day, dt.hour, dt.minute);
      } catch (_) {
        sortTime = DateTime(today.year, today.month, today.day, 0, 0);
      }
      timelineItems.add({...data, 'type': 'feed', 'sortTime': sortTime});
    }

    final waterPlans = activePlansToday
        .where((plan) => plan.type == SupplementType.waterMix)
        .toList();

    for (final plan in waterPlans) {
      final existingLogs = todaySupplementLogs
          .where((log) =>
              log.supplementType == SupplementType.waterMix &&
              log.supplementId == plan.id)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final scheduledAt = _waterPlanScheduleForDay(plan, today);
      final latestLog = existingLogs.isNotEmpty ? existingLogs.first : null;

      timelineItems.add({
        'type': 'water',
        'plan': plan,
        'log': latestLog,
        'time': latestLog?.scheduledTime ?? _formatWaterTime(scheduledAt),
        'sortTime': latestLog?.scheduledAt ?? scheduledAt,
      });
    }

    for (final log in todaySupplementLogs) {
      if (log.supplementType != SupplementType.waterMix) {
        continue;
      }
      final alreadyRepresented = waterPlans.any((plan) => plan.id == log.supplementId);
      if (alreadyRepresented) {
        continue;
      }
      final sortTime = log.timestamp;
      timelineItems.add({
        'type': 'water',
        'log': log,
        'time': DateFormat("hh:mm a").format(sortTime),
        'sortTime': sortTime,
      });
    }

    timelineItems.sort((a, b) =>
        (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime));

    return timelineItems.asMap().entries.map<Widget>((entry) {
      final index = entry.key;
      final itemData = entry.value;
      final bool isFeed = itemData['type'] == 'feed';

      Color timelineColor;
      Widget card;
      FeedRoundState? _feedDotState; // only set for feed items
      bool _feedPendingTray = false;

      if (isFeed) {
        // ── Feed round card (unified for all DOCs) ─────────────────────
        final Map<int, bool> feedDoneMap = {
          for (final e in dashboardState.roundFeedStatus.entries)
            e.key: e.value == 'completed',
        };
        final round = itemData['round'] as int;
        final time = itemData['time'] as String;
        final timeKey = itemData['key'] as String;
        final double qty = dashboardState.roundFeedAmounts[round] ?? 0.0;
        final thisRoundLog = todayTrayMap[round];

        final roundState = _getSimpleRoundState(
          doc: currentDoc,
          round: round,
          totalRounds: 4,
          feedDone: feedDoneMap,
          trayDone: trayDone,
        );

        final bool isDone = roundState['isDone'] as bool;
        final bool isCurrent = roundState['isCurrent'] as bool;
        final bool isPendingTray = isDone && currentDoc > 30 && !(roundState['isTrayLogged'] as bool);

        final FeedRoundState cardState = isDone
            ? FeedRoundState.done
            : isCurrent
                ? FeedRoundState.current
                : FeedRoundState.upcoming;

        _feedDotState = cardState;
        _feedPendingTray = isPendingTray;
        timelineColor = (cardState == FeedRoundState.done || cardState == FeedRoundState.current)
            ? const Color(0xFF22C55E)
            : const Color(0xFFCBD5E1);

        // Supplements: applied for done rounds, planned for others
        final appliedSupplements = _getAppliedFeedSupplements(round, todaySupplementLogs);
        final List<String> supplements = appliedSupplements.isNotEmpty
            ? appliedSupplements
                .map((s) => "${s.name.toUpperCase()} ${s.quantity.toStringAsFixed(1)}${s.unit}")
                .toList()
            : _getPlannedFeedSupplements(activePlansToday, timeKey, qty)
                .map((s) => "${s.name.toUpperCase()} ${s.quantity.toStringAsFixed(1)}${s.unit}")
                .toList();

        card = FeedTimelineCard(
          round: round,
          time: time,
          feedQty: qty,
          state: cardState,
          isPendingTray: isPendingTray,
          trayStatuses: thisRoundLog?.trays,
          supplements: supplements,
          // MARK AS FED: always available on the current round, for all DOCs
          onMarkDone: isCurrent
              ? () {
                  if (qty > 0) {
                    ref.read(feedHistoryProvider.notifier).logFeeding(
                      pondId: selectedPond,
                      doc: currentDoc,
                      round: round,
                      qty: qty,
                    );
                    _logFeedSupplementApplication(
                      pondId: selectedPond,
                      pondName: pondName,
                      round: round,
                      feedQty: qty,
                      activePlansToday: activePlansToday,
                    );
                  }
                  // markFeedDone updates status in DB → loadTodayFeed → Riverpod rebuild
                  // Card then transitions: current → done (+ LOG TRAY if DOC > 30)
                  ref.read(pondDashboardProvider.notifier).markFeedDone(round);
                }
              : null,
          // EDIT: only for DOC > 30 (DOC ≤ 30 edits go via Feed Schedule)
          onEdit: currentDoc > 30 && cardState != FeedRoundState.upcoming
              ? (double newQty) {
                  ref.read(pondDashboardProvider.notifier).updateRoundAmount(round, newQty);
                }
              : null,
          // LOG TRAY CHECK: only after feed is marked done (DOC > 30, tray not yet logged)
          onLogTray: isPendingTray ? () => openTray(round, false) : null,
        );
      } else {
        final log = itemData['log'] as SupplementLog?;
        final plan = itemData['plan'] as Supplement?;
        final isApplied = log != null;
        timelineColor =
            isApplied ? const Color(0xFF10B981) : AppColors.primary;

        final scheduledAt = plan != null
            ? _waterPlanScheduleForDay(plan, today)
            : (log?.scheduledAt ?? log?.timestamp ?? today);
        final items = log?.appliedItems ??
            (plan != null ? plan.calculateAppliedItems(pondArea: pondArea) : <CalculatedItem>[]);

        card = _WaterRoundCard(
          time: itemData['time'],
          title: log?.supplementName ?? plan?.name ?? "Water Mix",
          items: items,
          isApplied: isApplied,
          onMarkDone: plan == null || isApplied
              ? null
              : () {
                  if (pondArea <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Pond area must be greater than zero"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final didLog = _logWaterSupplementApplication(
                    pondId: dashboardState.selectedPond,
                    pondName: pondName,
                    pondArea: pondArea,
                    plan: plan,
                    scheduledAt: scheduledAt,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        didLog
                            ? "Water supplement marked as applied"
                            : "Unable to apply water supplement",
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
        );
      }

      // dotState is set inside the isFeed block above; null for water items
      final FeedRoundState? dotState = isFeed ? _feedDotState : null;

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Timeline column (dot + connector line) ──────────────────
            SizedBox(
              width: 36,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Vertical connector line
                  if (index < timelineItems.length - 1)
                    Positioned(
                      top: 24,
                      bottom: -4,
                      child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                    ),
                  // Dot
                  if (dotState != null)
                    buildTimelineDot(dotState, isPendingTray: _feedPendingTray)
                  else
                    // Water / supplement dot
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: timelineColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                ],
              ),
            ),
            // ── Card ───────────────────────────────────────────────────
            Expanded(child: card),
          ],
        ),
      );
    }).toList();
  }

  Widget _kpi(String title, String value, IconData icon, Color color,
      {double? trend, bool inverseColor = false}) {
    Color? trendColor;
    IconData? trendIcon;

    if (trend != null && (trend.abs() > 0.001)) {
      final isPositive = trend > 0;
      // inverseColor = true means decreasing (negative trend) is good (like FCR)
      final isGood = inverseColor ? !isPositive : isPositive;
      trendColor = isGood ? Colors.green : Colors.red;
      trendIcon =
          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    }

    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(title,
                      style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              color: Colors.black87)),
                    ),
                    if (trendIcon != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(trendIcon, size: 12, color: trendColor),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 24, color: Colors.grey.shade300);
  }

  String _getTrayInfoText(String feedMode) {
    switch (feedMode) {
      case 'blind':
        return "Blind Feed (Tray optional)";
      case 'transitional':
        return "Transitional Feed (Tray optional)";
      case 'smart':
        return "Smart Feed Active (Tray mandatory)";
      default:
        return "Standard Feed";
    }
  }

  Widget _buildCompletedDashboard(
      BuildContext context, WidgetRef ref, Pond pond) {
    final currentDoc = ref.watch(docProvider(pond.id));
    final harvests = ref.watch(harvestProvider(pond.id));
    final totalYield = harvests.fold(0.0, (sum, h) => sum + h.quantity);
    final totalRevenue = harvests.fold(0.0, (sum, h) => sum + h.revenue);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Cycle Completed",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(30)),
                    child: const Text("IDLE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _completedStat("TOTAL YIELD", "${totalYield.toInt()} kg"),
                  const SizedBox(width: 40),
                  _completedStat("TOTAL REVENUE",
                      "₹${NumberFormat('#,##,###').format(totalRevenue)}"),
                ],
              ),
              const SizedBox(height: 20),
              _completedStat("DURATION", "$currentDoc Days"),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NewCycleSetupScreen(pondId: pond.id)));
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text("START NEW CYCLE",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Secondary Summary Access
        Row(
          children: [
            Expanded(
              child: _actionCard(
                context,
                "Reports",
                Icons.analytics_rounded,
                Colors.orange,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HarvestSummaryScreen(pondId: pond.id))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                context,
                "History",
                Icons.history_rounded,
                Colors.blue,
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FeedHistoryScreen(pondId: pond.id))),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _completedStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _WaterRoundCard extends StatelessWidget {
  final String time;
  final String title;
  final List<dynamic> items;
  final bool isApplied;
  final VoidCallback? onMarkDone;

  const _WaterRoundCard({
    required this.time,
    required this.title,
    required this.items,
    required this.isApplied,
    this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rm,
        border: Border.all(
            color: isApplied
                ? const Color(0xFF10B981).withOpacity(0.2)
                : AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isApplied) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("DONE",
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    "WATER SUPPLEMENTS • $time",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isApplied
                          ? Colors.grey.shade500
                          : AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (!isApplied)
                Icon(Icons.opacity, size: 16, color: Colors.blue.shade400),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isApplied ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApplied
                            ? Colors.grey.shade100
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item is CalculatedItem
                            ? "${item.name.toUpperCase()} ${item.quantity.toStringAsFixed(1)}${item.unit}"
                            : "${item.itemName.toUpperCase()} ${item.totalDose.toStringAsFixed(1)}${item.unit}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isApplied ? Colors.grey : Colors.blue.shade800,
                          decoration:
                              isApplied ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (isApplied) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.18),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    "COMPLETED",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFF10B981),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (onMarkDone != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onMarkDone,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  "MARK DONE",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CompactProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final String totalText; // "0.0 / 0.0 kg"

  const CompactProgressBar({
    super.key,
    required this.progress,
    required this.totalText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: AppRadius.rm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  totalText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                "Today Progress",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white,
              color: Colors.green.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OperationButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
