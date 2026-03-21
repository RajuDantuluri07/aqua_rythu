import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/enums/tray_status.dart';
import '../feed/feed_plan_provider.dart';
import '../feed/feed_schedule_screen.dart';
import 'pond_dashboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:aqua_rythu/features/tray/tray_log_screen.dart';
import '../../features/tray/tray_provider.dart';
import '../farm/farm_provider.dart';
import '../harvest/harvest_provider.dart';
import '../supplements/supplement_mix_screen.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import '../../shared/constants/feed_phase.dart';
import '../feed/feed_round_card.dart';
import '../water/water_test_screen.dart';
import '../feed/feed_history_screen.dart';
import '../harvest/harvest_screen.dart';
import '../growth/sampling_screen.dart';
import '../growth/growth_provider.dart';

class PondDashboardScreen extends ConsumerStatefulWidget {
  const PondDashboardScreen({super.key});

  @override
  ConsumerState<PondDashboardScreen> createState() =>
      _PondDashboardScreenState();
}

class _PondDashboardScreenState
    extends ConsumerState<PondDashboardScreen> {
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
      MaterialPageRoute(
          builder: (context) =>
              TrayLogScreen(pondId: pondId, round: round)),
    );

    if (result != null && result is String) {
      ref.read(pondDashboardProvider.notifier).logTray(round);
    }
  }

  int _getCurrentRound() {
    final hour = DateTime.now().hour;
    if (hour < 8) return 1; // Before 8 AM is round 1
    if (hour < 12) return 2; // Before 12 PM is round 2
    if (hour < 16) return 3; // Before 4 PM is round 3
    if (hour < 20) return 4; // Before 8 PM is round 4
    return 1; // Default to next day's first round
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final selectedPond = dashboardState.selectedPond;

    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    final ponds = currentFarm?.ponds ?? [];

    /// ✅ GROWTH DATA (Triggers rebuild on update)
    final growthState = ref.watch(growthProvider(selectedPond));

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
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.addPond),
                  child: const Text("Add First Pond"),
                )
              ],
            ),
          ),
        ),
      );
    }

    /// ✅ NEW: FEED PLAN
    final planMap = ref.watch(feedPlanProvider);
    final plan = planMap[selectedPond];

    final currentDoc = ref.watch(docProvider(selectedPond));
    final dayPlan = plan?.days.firstWhere(
      (d) => d.doc == currentDoc,
      orElse: () => FeedDayPlan(doc: 0, r1: 0, r2: 0, r3: 0, r4: 0),
    );

    /// SAFE VALUES
    final plannedFeed = dayPlan?.total ?? 0.0;

    double consumedFeed = 0.0;
    if (dayPlan != null) {
      if (dashboardState.feedDone[1] == true) consumedFeed += dayPlan.r1;
      if (dashboardState.feedDone[2] == true) consumedFeed += dayPlan.r2;
      if (dashboardState.feedDone[3] == true) consumedFeed += dayPlan.r3;
      if (dashboardState.feedDone[4] == true) consumedFeed += dayPlan.r4;
    }

    final currentRound = _getCurrentRound();

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
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
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
                              ? const Color(0xFF1F9D55)
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
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              /// 📊 POND STATUS SUMMARY
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        spreadRadius: 2,
                        blurRadius: 5)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("DOC ${ref.watch(docProvider(selectedPond))}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const Text("Current Day",
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    Container(
                        height: 40, width: 1, color: Colors.grey.shade200),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${growthState.avgWeight}g",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue)),
                        Text(
                            growthState.logs.isNotEmpty
                                ? "Last: ${DateFormat('dd MMM').format(growthState.logs.first.date)}"
                                : "No Sampling",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
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
                            builder: (_) =>
                                FeedScheduleScreen(pondId: selectedPond),
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
                            builder: (_) => SupplementMixScreen(
                                pondId: selectedPond),
                          ),
                        );
                      },
                      child: const Text("Supplement Mix"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// PROGRESS CARD
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
                    Text(
                      "${consumedFeed.toStringAsFixed(1)} / ${plannedFeed.toStringAsFixed(2)} kg",
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: plannedFeed == 0
                          ? 0
                          : (consumedFeed / plannedFeed).clamp(0, 1),
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
                    round: data['round'],
                    time: data['time'],
                    currentRound: currentRound,
                    onOpenTray: openTray,
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              /// TANK OPERATIONS
              const Text("Tank Operations",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _OperationButton(
                    label: "Sampling",
                    icon: Icons.science,
                    color: Colors.purple,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SamplingScreen(pondId: selectedPond))),
                  ),
                  _OperationButton(
                    label: "Water",
                    icon: Icons.water_drop,
                    color: Colors.blue,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                WaterTestScreen(pondId: selectedPond))),
                  ),
                  _OperationButton(
                    label: "Harvest",
                    icon: Icons.agriculture,
                    color: Colors.orange,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                HarvestScreen(pondId: selectedPond))),
                  ),
                  _OperationButton(
                    label: "History",
                    icon: Icons.history,
                    color: Colors.teal,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                FeedHistoryScreen(pondId: selectedPond))),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
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
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}