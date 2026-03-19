import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feed/feed_provider.dart';
import '../growth/growth_provider.dart';
import '../farm/farm_provider.dart';
import 'package:aqua_rythu/routes/app_routes.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';
import '../water/water_provider.dart';
import '../harvest/harvest_provider.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends ConsumerState<DashboardScreen> {

  @override
  Widget build(BuildContext context) {

    /// ✅ FARM STATE
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;

    /// 🚨 EMPTY STATE CHECK
    if (currentFarm == null || currentFarm.ponds.isEmpty) {
      final isNoFarm = currentFarm == null;
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        bottomNavigationBar: const AppBottomBar(currentIndex: 0),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.water_drop_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 20),
                Text(
                    isNoFarm ? "No Farms Found" : "No Ponds in ${currentFarm.name}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                      context, isNoFarm ? AppRoutes.addFarm : AppRoutes.addPond),
                  child: Text(isNoFarm ? "Create Farm" : "Add First Pond"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Get the first pond of the selected farm to show on the main dashboard
    final String pondId = (currentFarm?.ponds.isNotEmpty ?? false)
        ? currentFarm!.ponds.first.id
        : 'Pond 1';

    /// ✅ FEED DATA
    // By watching the provider, the widget will rebuild when feed data changes.
    final feedAsync = ref.watch(feedProvider(pondId));
    // We can then read the notifier to access calculation methods without re-watching.
    final feedNotifier = ref.read(feedProvider(pondId).notifier);
    final totalFeed = feedNotifier.totalFeed;
    final todayFeed = feedNotifier.todayTotalFeed();
    final avgFeed = feedNotifier.averageFeedPerDay;
    final allFeeds = feedAsync.valueOrNull ?? [];

    /// 📊 PREPARE CHART DATA (Last 7 Days)
    final List<double> chartData = [];
    final List<String> chartLabels = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayFeeds = allFeeds.where((f) {
        return f.time.year == day.year &&
            f.time.month == day.month &&
            f.time.day == day.day;
      });
      final sum = dayFeeds.fold(0.0, (prev, f) => prev + f.quantity);
      chartData.add(sum);
      chartLabels.add("${day.day}/${day.month}");
    }

    /// ✅ GROWTH DATA
    // Watch the state object directly to get its properties and ensure reactivity.
    final growthState = ref.watch(growthProvider(pondId));
    final biomass = growthState.biomass;

    /// ✅ HARVEST DATA
    ref.watch(harvestProvider(pondId));
    final harvestNotifier = ref.read(harvestProvider(pondId).notifier);
    final totalHarvest = harvestNotifier.totalHarvest;

    /// ⚖️ REAL BIOMASS
    double adjustedBiomass = biomass - totalHarvest;
    if (adjustedBiomass < 0) {
      adjustedBiomass = 0;
    }

    /// ✅ WATER DATA
    final water = ref.watch(waterProvider(pondId));
    final waterNotifier = ref.watch(waterProvider(pondId).notifier);
    final waterStatus = waterNotifier.status;

    /// ✅ FCR
    final fcr = adjustedBiomass == 0 ? 0 : totalFeed / adjustedBiomass;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      bottomNavigationBar: const AppBottomBar(currentIndex: 0),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔝 HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Row(
                    children: const [
                      CircleAvatar(
                        backgroundColor: Color(0xFF1F9D55),
                        child: Text("A",
                            style: TextStyle(color: Colors.white)),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "AquaRythu",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  /// FARM SELECTOR
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("FARM",
                          style: TextStyle(fontSize: 12)),

                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == "add") {
                            Navigator.pushNamed(
                                context, AppRoutes.addFarm);
                          } else {
                            ref.read(farmProvider.notifier).selectFarm(value);
                          }
                        },
                        itemBuilder: (context) => [
                          ...farmState.farms.map(
                            (farm) => PopupMenuItem(
                              value: farm.id,
                              child: Text(farm.name),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: "add",
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 18),
                                SizedBox(width: 6),
                                Text("Add New Farm"),
                              ],
                            ),
                          ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentFarm?.name ?? "Select Farm",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),

              const SizedBox(height: 20),

              /// TITLE
              Text(
                "Farm Dashboard",
                style: Theme.of(context).textTheme.headlineLarge,
              ),

              const Text("Live Feed & Growth Data",
                  style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 20),

              /// Test button to simulate growth updates
              ElevatedButton(
                onPressed: () {
                  // Use the correct method `updateStats` from the GrowthNotifier
                  ref.read(growthProvider(pondId).notifier).updateStats(
                        avgWeight: 20, // Using a different value to see change
                        totalCount: 95000,
                      );
                },
                child: const Text("Simulate Growth Update"),
              ),

              const SizedBox(height: 20),

              /// 📊 LIVE STATS GRID
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [

                  /// WATER QUALITY
                  StatCard(
                    title: "WATER STATUS",
                    value: waterStatus,
                    subtitle: "pH ${water.ph} • DO ${water.oxygen}",
                    color: waterStatus == "Danger"
                        ? Colors.red
                        : (waterStatus == "Warning" ? Colors.orange : Colors.green),
                  ),

                  /// BIOMASS
                  StatCard(
                    title: "BIOMASS",
                    value: "${adjustedBiomass.toStringAsFixed(0)} kg",
                    subtitle: "After harvest",
                    color: Colors.blue,
                  ),

                  /// FCR
                  StatCard(
                    title: "FCR",
                    value: fcr == 0 ? "-" : fcr.toStringAsFixed(2),
                    subtitle: "Real efficiency",
                    color: Colors.orange,
                  ),

                  /// TOTAL FEED
                  StatCard(
                    title: "TOTAL FEED",
                    value: "${totalFeed.toStringAsFixed(0)} kg",
                    subtitle: "Cumulative",
                    color: Colors.green,
                  ),

                  /// TODAY FEED
                  StatCard(
                    title: "TODAY FEED",
                    value: "${todayFeed.toStringAsFixed(1)} kg",
                    subtitle: "Daily Usage",
                    color: Colors.purple,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// 📈 FEED TREND CHART
              FeedConsumptionChart(
                data: chartData,
                labels: chartLabels,
              ),

              const SizedBox(height: 20),

              /// 🌦 WEATHER CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F9D55), Color(0xFF2196F3)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentFarm?.location ?? "Unknown Location",
                        style: const TextStyle(color: Colors.white70)),
                    SizedBox(height: 10),
                    const Text(
                      "32°C",
                      style: TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text("Sunny",
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 📈 CUSTOM PAINTED CHART WIDGET
class FeedConsumptionChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;

  const FeedConsumptionChart({
    super.key,
    required this.data,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    // Find max value for normalization (avoid divide by zero)
    double maxVal = data.reduce(math.max);
    if (maxVal == 0) maxVal = 10;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Feed Consumption (Last 7 Days)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Icon(Icons.show_chart, color: Colors.green.shade700),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(data.length, (index) {
                final value = data[index];
                // Normalize height between 0.1 and 1.0 of available space
                final heightFactor = (value / maxVal).clamp(0.05, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Bar Label (Value)
                    if (value > 0)
                      Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 4),

                    // The Bar
                    Container(
                      width: 12,
                      height: 100 * heightFactor, // Scale height
                      decoration: BoxDecoration(
                        color: value > 0
                            ? const Color(0xFF1F9D55)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date Label
                    Text(
                      labels[index],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// 📊 STAT CARD WIDGET
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}