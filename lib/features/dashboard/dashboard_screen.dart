import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../../widgets/app_bottom_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;

    if (currentFarm == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text("Create Farm"),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// HEADER
              Row(
                children: [
                  const Text(
                    "AquaRythu",
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("FARM",
                          style: TextStyle(fontSize: 10)),
                      Text(
                        currentFarm.name,
                        style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),

              const SizedBox(height: 16),

              /// TITLE
              const Text(
                "Farm Dashboard",
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),
              const Text(
                "Today Overview",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 16),

              /// METRIC GRID
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: const [
                  _StatCard(
                    title: "FEED CONSUMED",
                    value: "1245 kg",
                    subtitle: "+18% vs last crop",
                    positive: true,
                  ),
                  _StatCard(
                    title: "EST. BIOMASS",
                    value: "2180 kg",
                    subtitle: "Sampling in 3d",
                    positive: true,
                  ),
                  _StatCard(
                    title: "FEED EFFICIENCY",
                    value: "1.18 FCR",
                    subtitle: "-0.02 from target",
                    positive: false,
                  ),
                  _StatCard(
                    title: "AVG GROWTH",
                    value: "0.28 g/day",
                    subtitle: "+0.03 vs last week",
                    positive: true,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// WEATHER CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F9D55), Color(0xFF2196F3)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Nellore, AP",
                        style: TextStyle(color: Colors.white)),
                    SizedBox(height: 10),
                    Text(
                      "32°C",
                      style: TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    Text("Sunny",
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// PONDS
              const Text(
                "Ponds",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              ...currentFarm.ponds.map((pond) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(pond.name),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// STAT CARD
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool positive;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: positive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
