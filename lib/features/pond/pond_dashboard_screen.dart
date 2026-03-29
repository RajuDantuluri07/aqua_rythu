import '../supplements/supplement_mix_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_plan_provider.dart';
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
import '../feed/feed_round_card.dart';
import '../feed/completed_round_card.dart';
import '../feed/upcoming_round_card.dart';
import '../water/water_test_screen.dart';
import '../feed/feed_history_screen.dart';
import '../harvest/harvest_screen.dart';
import '../growth/sampling_screen.dart';
import '../farm/new_cycle_setup_screen.dart';
import '../harvest/harvest_summary_screen.dart';
import 'package:intl/intl.dart';
import '../../core/engines/feed_state_engine.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';
import '../../core/theme/app_theme.dart';

class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen> {
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
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                ref
                    .read(farmProvider.notifier)
                    .addFarm(nameCtrl.text, locCtrl.text);
                Navigator.pop(context);
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

    // Safe argument handling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments as String?;
      if (args != null && args.isNotEmpty && args != selectedPond) {
        ref.read(pondDashboardProvider.notifier).selectPond(args);
      }
    });

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    final currentPond = ponds.firstWhere((p) => p.id == selectedPond,
        orElse: () => ponds.isNotEmpty
            ? ponds.first
            : Pond(
                id: "Dummy",
                name: "No Pond",
                area: 1.0,
                stockingDate: DateTime.now()));

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
        bottomNavigationBar: const AppBottomBar(currentIndex: 1),
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

    /// ✅ NEW: FEED PLAN (Auto-generate if missing)
    final planMap = ref.watch(feedPlanProvider);
    var plan = planMap[selectedPond];

    // Auto-create plan if no plan exists for this pond
    if (plan == null) {
      Pond? pondObj;
      for (var farm in farmState.farms) {
        for (var p in farm.ponds) {
          if (p.id == selectedPond) {
            pondObj = p;
            break;
          }
        }
      }
      if (pondObj != null) {
        Future.microtask(() {
          ref.read(feedPlanProvider.notifier).createPlan(
                pondId: selectedPond,
                seedCount: pondObj?.seedCount ?? 0,
                plSize: pondObj?.plSize ?? 0,
              );
        });
      }
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
      currentAbw = lastLog.averageBodyWeight;
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
      prevAbw = prevGrowthLog.averageBodyWeight;
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
      prevAbw = prevGrowthLog.averageBodyWeight;
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

    // Feed plan details
    final dayPlan = plan?.days.firstWhere(
      (d) => d.doc == currentDoc,
      orElse: () => FeedDayPlan(doc: currentDoc, rounds: [0, 0, 0, 0]),
    );

    final plannedFeed = dayPlan?.total ?? 0.0;

    double consumedFeed = 0.0;
    if (dayPlan != null) {
      for (int i = 1; i <= 4; i++) {
        if (dashboardState.feedDone[i] == true) {
          consumedFeed +=
              _calculateAdjustedQty(dayPlan, i, todayTrayMap, currentDoc);
        }
      }
    }

    final feedMode = FeedStateEngine.getMode(currentDoc);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 1),
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

                      final hasFeed = planMap[pond.id] != null;
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
                        "ABW",
                        currentAbw > 0
                            ? "${currentAbw.toStringAsFixed(1)}g"
                            : "--",
                        Icons.fitness_center_rounded,
                        Colors.cyan,
                        trend: abwTrend,
                        inverseColor: false),
                    _divider(),
                    _kpi("FCR", pondFcr > 0 ? pondFcr.toStringAsFixed(2) : "--",
                        Icons.trending_up_rounded, Colors.purple,
                        trend: fcrTrend, inverseColor: true),
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
                        child: GestureDetector(
                          onTap: () {
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
                              color: Colors.white,
                              borderRadius: AppRadius.rm,
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_month_rounded,
                                    color: AppColors.primary, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "FEED SCHEDULE",
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.hM,

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
                        _getTrayInfoText(feedMode),
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
                Column(
                  children: [
                    ..._buildTimeline(
                      today: today,
                      currentDoc: currentDoc,
                      pondName: currentPond.name,
                      pondArea: currentPond.area,
                      dayPlan: dayPlan,
                      todayTrayMap: todayTrayMap,
                      dashboardState: dashboardState,
                      trayDone: trayDone,
                      activePlansToday: activePlansToday,
                      todaySupplementLogs: todaySupplementLogs,
                      feedMode: feedMode,
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
    required FeedDayPlan? dayPlan,
    required Map<int, TrayLog> todayTrayMap,
    required PondDashboardState dashboardState,
    required Map<int, bool> trayDone,
    required List<Supplement> activePlansToday,
    required List<SupplementLog> todaySupplementLogs,
    required FeedMode feedMode,
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

      if (isFeed) {
        final round = itemData['round'] as int;
        final time = itemData['time'] as String;
        final timeKey = itemData['key'] as String;
        final double baseQty = _getFeedQty(dayPlan, round);
        final double qty =
            _calculateAdjustedQty(dayPlan, round, todayTrayMap, currentDoc);
        final bool isAutoAdjusted = (qty - baseQty).abs() > 0.01;
        final thisRoundLog = todayTrayMap[round];
        final roundState = FeedStateEngine.getRoundState(
            doc: currentDoc,
            round: round,
            totalRounds: 4,
            feedDone: dashboardState.feedDone,
            trayDone: trayDone);

        timelineColor = roundState.isDone && !roundState.showTrayCTA
            ? const Color(0xFF10B981)
            : (roundState.isCurrent
                ? const Color(0xFFF59E0B)
                : const Color(0xFFCBD5E1));

        final bool isDoneInHabitOrBeginner =
            roundState.isDone && feedMode != FeedMode.precision;
        final bool isActuallyDoneInPrecision =
            roundState.isDone && !roundState.showTrayCTA;
        final appliedSupplements = _getAppliedFeedSupplements(
          round,
          todaySupplementLogs,
        );

        if (isDoneInHabitOrBeginner || isActuallyDoneInPrecision) {
          final supplementStrings = appliedSupplements
              .map((item) =>
                  "${item.name.toUpperCase()} ${item.quantity.toStringAsFixed(1)}${item.unit}")
              .toList();
          card = CompletedRoundCard(
            round: round,
            time: time,
            feedQty: qty,
            originalQty: isAutoAdjusted ? baseQty : null,
            trayStatuses: thisRoundLog?.trays,
            supplements: supplementStrings,
            showTraySummary: feedMode != FeedMode.beginner,
            onLogTray: (feedMode == FeedMode.habit && !roundState.isTrayLogged)
                ? () => openTray(round, false)
                : null,
          );
        } else if (roundState.isLocked) {
          bool isRoundNext = false;
          if (round > 1) {
            final prevRoundState = FeedStateEngine.getRoundState(
                doc: currentDoc,
                round: round - 1,
                totalRounds: 4,
                feedDone: dashboardState.feedDone,
                trayDone: trayDone);
            if (prevRoundState.isDone || prevRoundState.isCurrent) {
              isRoundNext = true;
            }
          }
          card = UpcomingRoundCard(
              round: round, time: time, feedQty: qty, isNext: isRoundNext);
        } else {
          card = FeedRoundCard(
            key: ValueKey("round_$round"),
            round: round,
            time: time,
            feedQty: qty,
            originalQty: isAutoAdjusted ? baseQty : null,
            isAutoAdjusted: isAutoAdjusted,
            isDone: roundState.isDone,
            isCurrent: roundState.isCurrent,
            isLocked: roundState.isLocked,
            showTrayCTA: roundState.showTrayCTA,
            isPendingTray: roundState.isDone && roundState.showTrayCTA,
            onOpenTray: (r) => openTray(r, false),
            supplements:
                _getPlannedFeedSupplements(activePlansToday, timeKey, qty),
            onMarkDone: () {
              if (!roundState.isLocked) {
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Feed quantity must be greater than zero"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                _logFeedSupplementApplication(
                  pondId: dashboardState.selectedPond,
                  pondName: pondName,
                  round: round,
                  feedQty: qty,
                  activePlansToday: activePlansToday,
                );
                ref.read(pondDashboardProvider.notifier).markFeedDone(round);
              }
            },
          );
        }
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

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (index < timelineItems.length - 1)
                  Positioned(
                      top: 12,
                      bottom: -12,
                      child:
                          Container(width: 2, color: const Color(0xFFE2E8F0))),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: timelineColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: timelineColor.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1)
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: card),
        ],
      );
    }).toList();
  }

  /// 🧠 CORE LOGIC: Calculates feed quantity for a round, applying tray adjustments if needed.
  double _calculateAdjustedQty(
      FeedDayPlan? plan, int round, Map<int, TrayLog> todayTrayMap, int doc) {
    double qty = _getFeedQty(plan, round);

    // Adjustment Logic: Round N is adjusted by Tray N-1
    if (round > 1) {
      final prevLog = todayTrayMap[round - 1];
      if (prevLog != null) {
        final mode = FeedStateEngine.getMode(doc);
        qty = FeedStateEngine.applyTrayAdjustment(prevLog.trays, qty, mode);
      }
    }
    return qty;
  }

  // This method was already present in the provided context, but added here
  // to address the user's reported "CRITICAL ERROR" as if it were missing.
  double _getFeedQty(FeedDayPlan? plan, int round) {
    if (plan == null) {
      return 0;
    }
    final index = round - 1;
    if (index >= 0 && index < plan.rounds.length) {
      return plan.rounds[index];
    }
    return 0;
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

  String _getTrayInfoText(FeedMode mode) {
    switch (mode) {
      case FeedMode.beginner:
        return "Tray feeding optional (habit phase)";
      case FeedMode.habit:
        return "Tray observation Recommended";
      case FeedMode.precision:
        return "Tray based adjustments Active";
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
