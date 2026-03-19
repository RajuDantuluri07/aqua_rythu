import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_provider.dart';
import '../feed/feed_plan_provider.dart';
import '../feed/feed_schedule_screen.dart';
import 'pond_dashboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:aqua_rythu/features/tray/tray_log_screen.dart';
import '../../features/tray/tray_provider.dart';
import '../feed/feed_history_screen.dart';
import '../farm/farm_provider.dart';
import '../harvest/harvest_screen.dart';
import '../harvest/harvest_provider.dart';
import '../growth/sampling_screen.dart';
import '../water/water_test_screen.dart';
import '../supplements/supplement_mix_screen.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../../shared/constants/feed_phase.dart';
import '../feed/feed_phase_utils.dart';
import 'phase_indicator_card.dart';
import '../feed/feed_adjustment_engine.dart';
import 'widgets/operation_item.dart';
import 'widgets/feed_round_card.dart';

class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() => _PondDashboardScreenState();
}

class _PondDashboardScreenState extends ConsumerState<PondDashboardScreen> {
  int currentRound = 2;

  final List<Map<String, dynamic>> feedRoundsData = [
    {"round": 1, "time": "06:00 AM"},
    {"round": 2, "time": "10:00 AM"},
    {"round": 3, "time": "02:00 PM"},
    {"round": 4, "time": "06:00 PM"},
  ];

  void openTray(int round) async {
    final pondId = ref.read(pondDashboardProvider).selectedPond;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TrayLogScreen(pondId: pondId, round: round)),
    );

    if (result != null && result is String) {
      ref.read(pondDashboardProvider.notifier).logTray(round, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH THE DASHBOARD STATE
    final dashboardState = ref.watch(pondDashboardProvider);
    final selectedPond = dashboardState.selectedPond;
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];
    
    /// 🚨 EMPTY STATE CHECK
    if (currentFarm != null && currentFarm.ponds.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        bottomNavigationBar: const AppBottomBar(currentIndex: 1),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 20),
                Text("No Ponds in ${currentFarm.name}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.addPond),
                  child: const Text("Add First Pond"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 2. WATCH DATA FOR THAT POND
    final feedsAsync = ref.watch(feedProvider(selectedPond));
    final feeds = feedsAsync.valueOrNull ?? [];
    final plannedFeed = ref.watch(todayFeedProvider(selectedPond)); // 🔥 Plan Data

    final consumedFeed = feeds
        .where((f) => f.doc == dashboardState.doc)
        .fold(0.0, (sum, f) => sum + f.quantity);

    // 3. DETERMINE PHASE
    final phase = FeedPhaseUtils.getPhase(dashboardState.doc);
    
    // 4. GET FEED SUGGESTION (Smart Phase)
    final trayLogs = ref.watch(trayProvider(selectedPond));
    final feedAdjustment = FeedAdjustmentEngine.getFeedAdjustment(trayLogs);
    final suggestionText = FeedAdjustmentEngine.getSuggestionText(feedAdjustment);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      bottomNavigationBar: const AppBottomBar(currentIndex: 1),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "AquaRythu",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.addPond);
                    },
                    child: const Text("+ ADD POND"),
                  )
                ],
              ),

              const SizedBox(height: 16),

              /// POND TABS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ponds.map((pond) {
                    bool isSelected = pond.id == selectedPond;
                    return GestureDetector(
                      onTap: () {
                        ref.read(pondDashboardProvider.notifier).selectPond(pond.id);
                      },
                      onLongPress: () {
                        // 🔥 VALIDATION CHECK: Prevent delete if data exists
                        final hasFeed = ref.read(feedProvider(pond.id)).isNotEmpty;
                        final hasHarvest = ref.read(harvestProvider(pond.id)).isNotEmpty;

                        if (hasFeed || hasHarvest) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Cannot Delete Pond"),
                              content: const Text("This pond contains active feed or harvest records. Please clear the data before deleting."),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                              ],
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Pond"),
                            content: Text(
                                "Are you sure you want to delete ${pond.name}? This action cannot be undone."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  if (currentFarm != null) {
                                    ref.read(farmProvider.notifier).deletePond(currentFarm.id, pond.id);
                                    
                                    if (isSelected) {
                                      final remaining = ponds.where((p) => p.id != pond.id).toList();
                                      if (remaining.isNotEmpty) {
                                        ref.read(pondDashboardProvider.notifier).selectPond(remaining.first.id);
                                      }
                                    }
                                  }
                                },
                                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1F9D55)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          pond.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              /// 🧠 PHASE INDICATOR CARD
              PhaseIndicatorCard(doc: dashboardState.doc),

              const SizedBox(height: 16),

              /// 🧠 SMART FEED SUGGESTION (Only in Smart Phase)
              if (phase == FeedPhase.smart)
                Card(
                  color: feedAdjustment < 0 ? Colors.red.shade50 : (feedAdjustment > 0 ? Colors.green.shade50 : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: feedAdjustment != 0 ? BorderSide(
                      color: feedAdjustment < 0 ? Colors.red : Colors.green
                    ) : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: Icon(
                      feedAdjustment == 0 ? Icons.check_circle_outline : (feedAdjustment > 0 ? Icons.trending_up : Icons.trending_down),
                      color: feedAdjustment == 0 ? Colors.grey : (feedAdjustment > 0 ? Colors.green : Colors.red),
                    ),
                    title: const Text("AI Feed Suggestion", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(suggestionText),
                  ),
                ),
              if (phase == FeedPhase.smart) const SizedBox(height: 16),

              /// INFO CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoItem("Species", "L. vannamei"),
                    _infoItem("DOC", "${dashboardState.doc} Days"),
                    _infoItem("Survival", "92%"),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedScheduleScreen(
                              pondId: selectedPond,
                            ),
                          ),
                        );
                      },
                      child: const Text("Feed Schedule"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SupplementMixScreen(pondId: selectedPond)),
                        );
                      },
                      child: const Text("Supplement Mix"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// 🔥 PROGRESS CARD (UPDATED)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TODAY'S PROGRESS"),
                    const SizedBox(height: 10),

                    /// 🔥 DYNAMIC VALUE
                    Text(
                      "${consumedFeed.toStringAsFixed(1)} / ${plannedFeed.toStringAsFixed(2)} kg",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    /// 🔥 DYNAMIC PROGRESS
                    LinearProgressIndicator(
                      value: plannedFeed == 0 ? 0 : (consumedFeed / plannedFeed).clamp(0, 1),
                    ),

                    const SizedBox(height: 10),

                    if (phase == FeedPhase.transition)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lightbulb, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Tip: Start using feed trays for better results",
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// FEED ROUNDS
              ...feedRoundsData.map((data) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FeedRoundCard(
                    round: data["round"],
                    time: data["time"],
                    currentRound: currentRound,
                    onOpenTray: openTray,
                  ),
                );
              }).toList(),

              const SizedBox(height: 20),

              /// OPERATIONS
              const Text("TANK OPERATIONS"),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OperationItem(
                    "Sampling",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SamplingScreen(pondId: selectedPond),
                        ),
                      );
                    },
                  ),
                  OperationItem(
                    "Water Test",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                         builder: (_) => WaterTestScreen(pondId: selectedPond),
                        ),
                      );
                    },
                  ),
                  OperationItem(
                    "Harvest",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HarvestScreen(pondId: selectedPond),
                        ),
                      );
                    },
                  ),
                  OperationItem(
                    "History",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeedHistoryScreen(pondId: selectedPond),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

}