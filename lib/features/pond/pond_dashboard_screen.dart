import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/enums/tray_status.dart';
import '../feed/feed_plan_provider.dart';
import '../feed/feed_schedule_screen.dart';
import 'pond_dashboard_provider.dart';
import 'package:aqua_rythu/features/tray/tray_log_screen.dart';
import '../../features/tray/tray_provider.dart';
import '../tray/tray_model.dart';
import '../farm/farm_provider.dart';
import '../harvest/harvest_provider.dart';
import '../supplements/supplement_mix_screen.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../feed/feed_round_card.dart';
import '../feed/completed_round_card.dart';
import '../water/water_test_screen.dart';
import '../feed/feed_history_screen.dart';
import '../harvest/harvest_screen.dart';
import '../growth/sampling_screen.dart';
import '../growth/growth_provider.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_calculator.dart';
import '../../core/engines/feed_state_engine.dart';
import '../../features/supplements/supplement_provider.dart';
import '../../features/supplements/widgets/water_treatment_card.dart';


class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen> {
  final List<Map<String, dynamic>> feedRoundsData = [
    {"round": 1, "time": "06:00 AM"},
    {"round": 2, "time": "10:00 AM"},
    {"round": 3, "time": "02:00 PM"},
    {"round": 4, "time": "06:00 PM"},
  ];

  void openTray(int round) async {
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

    if (!mounted) return;

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
              decoration: const InputDecoration(
                labelText: "Farm Name",
                hintText: "e.g. Sri Rama Farm",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locCtrl,
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

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    final allSupplements = ref.watch(supplementProvider);
    final supplements = allSupplements
        .where((s) => s.pondIds.contains(selectedPond) || s.pondIds.contains('ALL'))
        .toList();

    /// ✅ TRAY DATA
    final trayLogs = ref.watch(trayProvider(selectedPond));
    final today = DateTime.now();
    
    final Map<int, TrayLog> todayTrayMap = {
      for (var log in trayLogs)
        if (log.time.year == today.year &&
            log.time.month == today.month &&
            log.time.day == today.day)
          log.round: log
    };
    final Map<int, bool> trayDone = todayTrayMap.map((key, value) => MapEntry(key, true));

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
                const SizedBox(height: 20),
                Text("No Ponds in ${currentFarm.name}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
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
            seedCount: pondObj!.seedCount,
            plSize: pondObj!.plSize,
          );
        });
      }
    }

    final currentDoc = ref.watch(docProvider(selectedPond));
    final dayPlan = plan?.days.firstWhere(
      (d) => d.doc == currentDoc,
      orElse: () => FeedDayPlan(doc: 0, r1: 0, r2: 0, r3: 0, r4: 0),
    );

    /// SAFE VALUES
    final plannedFeed = dayPlan?.total ?? 0.0;

    // 🔄 REFACTORED: Calculate actually consumed feed (taking adjustments into account)
    double consumedFeed = 0.0;
    if (dayPlan != null) {
      for (int i = 1; i <= 4; i++) {
        if (dashboardState.feedDone[i] == true) {
           // Calculate what was actually fed in that round
           consumedFeed += _calculateAdjustedQty(dayPlan, i, todayTrayMap);
        }
      }
    }

    /// ✅ ENGINE STATE
    final feedMode = FeedStateEngine.getMode(currentDoc);
    
    /// ✅ CALCULATE WATER TREATMENTS
    final waterTreatments = SupplementCalculator.calculateWaterTreatments(
      supplements: supplements,
      currentDoc: currentDoc,
      treatmentLogs: dashboardState.waterTreatmentLogs,
    );

    final overdueTreatments = waterTreatments.where((t) => t.isOverdue).toList();
    final otherTreatments = waterTreatments.where((t) => !t.isOverdue).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Icon(Icons.water_drop_rounded,
                            color: Theme.of(context).primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "AquaRythu",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ],
                  ),

                  // RIGHT: Farm Selector
                  InkWell(
                    onTap: () => _showFarmSwitchDialog(farmState),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
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
                              color: Colors.grey.shade800
                            ),
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

              const SizedBox(height: 20),

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
                        if (hasFeed || hasHarvest) return;

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
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text("Delete"),
                                  onPressed: () {
                                    if (currentFarm != null) {
                                      ref.read(farmProvider.notifier).deletePond(currentFarm.id, pond.id);
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
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pond.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.black,
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
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Theme.of(context).primaryColor),
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

              const SizedBox(height: 20),

              /// 📊 POND STATUS SUMMARY
              // KPI Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _kpi("SPECIES", "L. vannamei", Icons.pets_rounded, Colors.orange),
                    _divider(),
                    _kpi("DOC", "${currentDoc} Days", Icons.calendar_month_rounded, Colors.blue),
                    _divider(),
                    _kpi("SURVIVAL", "98%", Icons.health_and_safety_rounded, Colors.green),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// TANK OPERATIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OperationButton(
                    label: "Sampling",
                    icon: Icons.science_rounded,
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SamplingScreen(pondId: selectedPond))),
                  ),
                  _OperationButton(
                    label: "Water",
                    icon: Icons.water_drop_rounded,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                WaterTestScreen(pondId: selectedPond))),
                  ),
                  _OperationButton(
                    label: "Harvest",
                    icon: Icons.agriculture_rounded,
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                HarvestScreen(pondId: selectedPond))),
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

              const SizedBox(height: 20),

              /// ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FeedScheduleScreen(pondId: selectedPond),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Feed Schedule"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplementMixScreen(
                                pondId: selectedPond),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Supplement Mix"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// PROGRESS CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("TODAY'S PROGRESS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "BLIND PLAN BASED",
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          consumedFeed.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 36, color: Colors.white, fontWeight: FontWeight.w900, height: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 4),
                          child: Text(
                            "/ ${plannedFeed.toStringAsFixed(2)} kg",
                            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: plannedFeed == 0
                            ? 0
                            : (consumedFeed / plannedFeed).clamp(0, 1),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getTrayInfoText(feedMode),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// DAILY TASKS TIMELINE
              Column(
                children: [
                  /// 1. OVERDUE WATER TREATMENTS
                  ...overdueTreatments.map((wt) => WaterTreatmentCard(
                    treatment: wt,
                    onApply: () => ref.read(pondDashboardProvider.notifier).markWaterTreatmentApplied(wt.supplementId, wt.scheduledDoc),
                    onSkip: () => ref.read(pondDashboardProvider.notifier).markWaterTreatmentSkipped(wt.supplementId, wt.scheduledDoc),
                  )),

                  /// 2. DUE/COMPLETED WATER TREATMENTS
                  ...otherTreatments.map((wt) => WaterTreatmentCard(
                    treatment: wt,
                    onApply: () => ref.read(pondDashboardProvider.notifier).markWaterTreatmentApplied(wt.supplementId, wt.scheduledDoc),
                    onSkip: () => ref.read(pondDashboardProvider.notifier).markWaterTreatmentSkipped(wt.supplementId, wt.scheduledDoc),
                  )),

                  /// 3. FEED ROUNDS
                  ...feedRoundsData.map<Widget>((data) {
                  final round = data['round'] as int;
                  final time = data['time'] as String;

                  // 🧠 CALCULATE QTY (Centralized Logic)
                  final double baseQty = _getFeedQty(dayPlan, round);
                  final double qty = _calculateAdjustedQty(dayPlan, round, todayTrayMap);
                  
                  final bool isAutoAdjusted = (qty - baseQty).abs() > 0.01;
                  
                  // Get tray log for THIS round if it exists (for Completed Card display)
                  final thisRoundLog = todayTrayMap[round];

                  // ✅ Use Engine to determine state
                  final roundState = FeedStateEngine.getRoundState(
                    doc: currentDoc,
                    round: round,
                    totalRounds: 4,
                    feedDone: dashboardState.feedDone,
                    trayDone: trayDone,
                  );

                  // ✅ RENDER COMPLETED CARD
                  if (roundState.isDone && !roundState.showTrayCTA) {
                    // Calculate supplements for display
                    // We re-calculate based on plan because we don't store exact strings yet
                    final feedingTime = mapRoundToTimeKey(round);
                    final supplementResults = SupplementCalculator.calculate(
                      supplements: supplements,
                      currentDoc: currentDoc,
                      currentFeedingTime: feedingTime,
                      feedQty: qty,
                    );

                    // Flatten for UI: "MINERAL MIX 135g"
                    final List<String> supplementStrings = [];
                    for (var group in supplementResults) {
                      for (var item in group.items) {
                        supplementStrings.add(
                          "${item.itemName.toUpperCase()} ${item.totalDose.toInt()}${item.unit}"
                        );
                      }
                    }

                    return CompletedRoundCard(
                      round: round,
                      time: time,
                      feedQty: qty,
                      // Verified: qty includes tray adjustment from logic above
                      // Only show trays if logged
                      trayStatuses: thisRoundLog?.trays,
                      supplements: supplementStrings,
                    );
                  }

                  return FeedRoundCard(
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
                    onOpenTray: (r) => openTray(r),
                    onMarkDone: () {
                      if (!roundState.isLocked) {
                        ref.read(pondDashboardProvider.notifier).markFeedDone(round);
                      }
                    },
                  );
                }).toList(),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  /// 🧠 CORE LOGIC: Calculates feed quantity for a round, applying tray adjustments if needed.
  double _calculateAdjustedQty(FeedDayPlan? plan, int round, Map<int, TrayLog> todayTrayMap) {
    double qty = _getFeedQty(plan, round);
    
    // Adjustment Logic: Round N is adjusted by Tray N-1
    if (round > 1) {
      final prevLog = todayTrayMap[round - 1];
      if (prevLog != null) {
        qty = FeedStateEngine.applyTrayAdjustment(
          plannedQty: qty,
          trayResults: prevLog.trays,
        );
      }
    }
    return qty;
  }

  double _getFeedQty(FeedDayPlan? plan, int round) {
    if (plan == null) return 0;
    switch (round) {
      case 1:
        return plan.r1;
      case 2:
        return plan.r2;
      case 3:
        return plan.r3;
      case 4:
        return plan.r4;
      default:
        return 0;
    }
  }
  
  Widget _statusBadge(bool isDone, bool isCurrent) {
    if (isDone) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: const Text("NOW", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox();
  }

  Widget _kpi(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color.withOpacity(0.7)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 24, color: Colors.grey.shade300);
  }

  // Helpers
  Color _getModeColor(FeedMode mode) {
    switch (mode) {
      case FeedMode.beginner: return Colors.blue;
      case FeedMode.habit: return Colors.orange;
      case FeedMode.precision: return Colors.purple;
    }
  }

  String _getModeLabel(FeedMode mode) {
    switch (mode) {
      case FeedMode.beginner: return "BEGINNER MODE";
      case FeedMode.habit: return "HABIT MODE";
      case FeedMode.precision: return "PRECISION MODE";
    }
  }

  String _getTrayInfoText(FeedMode mode) {
    switch (mode) {
      case FeedMode.beginner: return "Tray Feeding: Not Started (Recommended after DOC 15)";
      case FeedMode.habit: return "Tray Feeding: Optional (Habit Phase)";
      case FeedMode.precision: return "Tray Feeding: Mandatory (Next Feed Locked)";
    }
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
                  BoxShadow(color: color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}