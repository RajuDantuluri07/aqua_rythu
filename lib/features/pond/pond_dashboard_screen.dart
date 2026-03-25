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
import '../supplements/supplement_mix_screen.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../feed/feed_round_card.dart';
import '../feed/completed_round_card.dart';
import '../feed/upcoming_round_card.dart';
import '../water/water_test_screen.dart';
import '../feed/feed_history_screen.dart';
import '../harvest/harvest_screen.dart';
import '../growth/sampling_screen.dart';
import '../../features/supplements/supplement_provider.dart';
import '../farm/new_cycle_setup_screen.dart';
import '../harvest/harvest_summary_screen.dart';
import 'package:intl/intl.dart';
import '../../core/engines/feed_state_engine.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_calculator.dart';
import '../../core/theme/app_theme.dart';





class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen> {
  // 🔄 Dynamic Rounds based on DOC (PRD 5.5)
  // Note: Data model currently limited to 4 rounds. 
  // PRD requires 6 rounds for DOC 1-15.
  List<Map<String, dynamic>> _getFeedRounds(int doc) {
    // Default / Precision / Habit (4 rounds)
    // 6 AM, 10 AM, 2 PM, 6 PM
    return [
      {"round": 1, "time": "06:00 AM"},
      {"round": 2, "time": "10:00 AM"},
      {"round": 3, "time": "02:00 PM"},
      {"round": 4, "time": "06:00 PM"},
    ];
    
    // TODO: When DB supports 6 rounds, add:
    // if (doc <= 15) return 6 rounds configuration...
  }

  void openTray(int round, bool isLocked) async {
    if (isLocked) return;
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
    
    // 🎯 NEW: Read pondId from arguments if provided
    String selectedPond = dashboardState.selectedPond;
    final args = ModalRoute.of(context)?.settings.arguments as String?;
    if (args != null && args != selectedPond) {
       // Sync provider with arguments
       Future.microtask(() {
         ref.read(pondDashboardProvider.notifier).selectPond(args);
       });
       selectedPond = args;
    }

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];
    
    final currentPond = ponds.firstWhere((p) => p.id == selectedPond, orElse: () => ponds.isNotEmpty ? ponds.first : Pond(id: "Dummy", name: "No Pond", area: 0, stockingDate: DateTime.now()));
    final isCompleted = currentPond.status == PondStatus.completed;

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
            seedCount: pondObj?.seedCount ?? 0,
            plSize: pondObj?.plSize ?? 0,
          );
        });
      }
    }

    final currentDoc = ref.watch(docProvider(selectedPond));
    final dayPlan = plan?.days.firstWhere(
      (d) => d.doc == currentDoc,
      orElse: () => FeedDayPlan(doc: 0, rounds: [0, 0, 0, 0]),
    );

    /// SAFE VALUES
    final plannedFeed = dayPlan?.total ?? 0.0;

    // 🔄 REFACTORED: Calculate actually consumed feed (taking adjustments into account)
    double consumedFeed = 0.0;
    if (dayPlan != null) {
      for (int i = 1; i <= 4; i++) {
        if (dashboardState.feedDone[i] == true) {
           // Calculate what was actually fed in that round
           consumedFeed += _calculateAdjustedQty(dayPlan, i, todayTrayMap, currentDoc);
        }
      }
    }

    /// ✅ ENGINE STATE
    final feedMode = FeedStateEngine.getMode(currentDoc);
    

    // Get Rounds
    final feedRoundsData = _getFeedRounds(currentDoc);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
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
                        errorBuilder: (c, o, s) => Icon(Icons.water_drop, color: Theme.of(context).primaryColor, size: 32),
                      ),
                      AppSpacing.wM,
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
                          horizontal: AppSpacing.base, vertical: AppSpacing.s + 2),
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
                        margin: const EdgeInsets.only(right: AppSpacing.s + 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.base, vertical: AppSpacing.s + 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade200,
                          borderRadius: AppRadius.rl,
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
                          horizontal: AppSpacing.base, vertical: AppSpacing.s + 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadius.rl,
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
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.base, horizontal: AppSpacing.base),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.rl,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _kpi("SPECIES", "L. vannamei", Icons.water, Colors.blue), // Changed from set_meal_rounded (dog foot lookalike)
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
                    icon: Icons.texture, // Fishnet/mesh icon representation
                    color: Colors.purple,
                    onTap: () {
                      if (isCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sampling is locked for completed ponds")));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SamplingScreen(pondId: selectedPond)));
                      }
                    },
                  ),
                  _OperationButton(
                    label: "Water",
                    icon: Icons.water_drop_rounded,
                    color: AppColors.primary,
                    onTap: () {
                      if (isCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Water test is locked for completed ponds")));
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => WaterTestScreen(pondId: selectedPond)));
                      }
                    },
                  ),
                  _OperationButton(
                    label: "Harvest",
                    icon: Icons.agriculture_rounded,
                    color: AppColors.warning,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                isCompleted 
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

              const SizedBox(height: 20),

              if (isCompleted) 
                _buildCompletedDashboard(context, ref, currentPond)
              else ...[
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
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.rm,
                        ),
                      ),
                      child: const Text("Feed Schedule"),
                    ),
                  ),
                  AppSpacing.wM,
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
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.rm,
                        ),
                      ),
                      child: const Text("Supplement Mix"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// COMPACT PROGRESS BAR
              CompactProgressBar(
                progress: plannedFeed == 0 ? 0 : (consumedFeed / plannedFeed).clamp(0, 1),
                totalText: "${consumedFeed.toStringAsFixed(1)} / ${plannedFeed.toStringAsFixed(2)} kg",
              ),

              const SizedBox(height: 8),

              /// TRAY INFO HINT (Moved)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
                    AppSpacing.wS,
                    Text(
                      _getTrayInfoText(feedMode),
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              /// DAILY TASKS TIMELINE
              Column(
                children: [
                  /// 1. FEED ROUNDS
                  ...feedRoundsData.map<Widget>((data) {
                    final round = data['round'] as int;
                    final time = data['time'] as String;

                    // 🧠 CALCULATE QTY (Centralized Logic)
                    final double baseQty = _getFeedQty(dayPlan, round);
                    final double qty = _calculateAdjustedQty(dayPlan, round, todayTrayMap, currentDoc);
                    
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

                    // Determine Timeline Color
                    final Color timelineColor = roundState.isDone && !roundState.showTrayCTA 
                        ? const Color(0xFF10B981) 
                        : (roundState.isCurrent ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1));

                    Widget card;

                    // ✅ RENDER COMPLETED CARD
                    // - Always move to Completed in Beginner (DOC <= 15) after feeding
                    // - Move to Completed in Habit (DOC 16-30) after feeding (optional tray results)
                    // - Only move to Completed in Precision (DOC > 30) after BOTH feeding AND tray log
                    final bool isDoneInHabitOrBeginner = roundState.isDone && feedMode != FeedMode.precision;
                    final bool isActuallyDoneInPrecision = roundState.isDone && !roundState.showTrayCTA;

                    if (isDoneInHabitOrBeginner || isActuallyDoneInPrecision) {
                      final feedingTime = mapRoundToTimeKey(round, currentDoc);
                      
                      // ... Calculate supplements (existing logic preserved)
                      final supplementResults = SupplementCalculator.calculate(
                        supplements: supplements,
                        currentDoc: currentDoc,
                        currentFeedingTime: feedingTime,
                        feedQty: qty,
                      );

                      final List<String> supplementStrings = [];
                      for (var group in supplementResults) {
                        for (var item in group.items) {
                          supplementStrings.add(
                            "${item.itemName.toUpperCase()} ${item.totalDose.toInt()}${item.unit}"
                          );
                        }
                      }

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
                    } 
                    // ✅ RENDER UPCOMING CARD
                    else if (roundState.isLocked) {
                      // Logic for "NEXT" badge: Only the first locked round after current is NEXT
                      bool isRoundNext = false;
                      if (round > 1) {
                        final prevRoundState = FeedStateEngine.getRoundState(
                          doc: currentDoc,
                          round: round - 1,
                          totalRounds: 4,
                          feedDone: dashboardState.feedDone,
                          trayDone: trayDone,
                        );
                        if (prevRoundState.isDone || prevRoundState.isCurrent) {
                          isRoundNext = true;
                        }
                      }

                      card = UpcomingRoundCard(
                        round: round,
                        time: time,
                        feedQty: qty,
                        isNext: isRoundNext,
                      );
                    }
                    // ✅ RENDER CURRENT/ACTIVE CARD
                    else {
                      card = FeedRoundCard(
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
                        onMarkDone: () {
                          if (!roundState.isLocked) {
                            ref.read(pondDashboardProvider.notifier).markFeedDone(round);
                          }
                        },
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline Graphics
                        SizedBox(
                          width: 32,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              // Vertical Line
                              if (round < 4)
                                Positioned(
                                  top: 12,
                                  bottom: -12,
                                  child: Container(
                                    width: 2,
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                              // Dot
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: timelineColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: timelineColor.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Content Card
                        Expanded(child: card),
                      ],
                    );
                  }).toList(),


                  /// 2. MINERALS & PROBIOTICS (New Section)
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                      boxShadow: [
                         BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             Icon(Icons.science_rounded, color: Colors.blue.shade700, size: 20),
                             const SizedBox(width: 8),
                             Text("Daily Care: Minerals & Probiotics", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                           ],
                         ),
                         const SizedBox(height: 8),
                         const Text("Apply daily minerals and soil probiotics as per supplement plan.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                         const SizedBox(height: 12),
                         SizedBox(
                           width: double.infinity,
                           child: OutlinedButton(
                             onPressed: () {}, // TODO: Link to Supplement Mark Done
                             style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700),
                             child: const Text("MARK AS APPLIED"),
                           ),
                         )
                      ],
                    ),
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

  /// 🧠 CORE LOGIC: Calculates feed quantity for a round, applying tray adjustments if needed.
  double _calculateAdjustedQty(FeedDayPlan? plan, int round, Map<int, TrayLog> todayTrayMap, int doc) {
    double qty = _getFeedQty(plan, round);
    
    // Adjustment Logic: Round N is adjusted by Tray N-1
    if (round > 1) {
      final prevLog = todayTrayMap[round - 1];
      if (prevLog != null) {
        final mode = FeedStateEngine.getMode(doc);
        qty = FeedStateEngine.applyTrayAdjustment(
          prevLog.trays,
          qty,
          mode
        );
      }
    }
    return qty;
  }

  double _getFeedQty(FeedDayPlan? plan, int round) {
    if (plan == null) return 0;
    final index = round - 1;
    if (index >= 0 && index < plan.rounds.length) {
      return plan.rounds[index];
    }
    return 0;
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
      case FeedMode.beginner: return "Tray feeding optional (habit phase)";
      case FeedMode.habit: return "Tray observation Recommended";
      case FeedMode.precision: return "Tray based adjustments Active";
    }
  }

  Widget _buildCompletedDashboard(BuildContext context, WidgetRef ref, Pond pond) {
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
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(30)),
                    child: const Text("IDLE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _completedStat("TOTAL YIELD", "${totalYield.toInt()} kg"),
                  const SizedBox(width: 40),
                  _completedStat("TOTAL REVENUE", "₹${NumberFormat('#,##,###').format(totalRevenue)}"),
                ],
              ),
              const SizedBox(height: 20),
              _completedStat("DURATION", "${pond.doc} Days"),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => NewCycleSetupScreen(pondId: pond.id)));
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: const Text("START NEW CYCLE", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => HarvestSummaryScreen(pondId: pond.id))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionCard(
                context,
                "History",
                Icons.history_rounded,
                Colors.blue,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedHistoryScreen(pondId: pond.id))),
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
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
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
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              Text(
                "Blind Plan",
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