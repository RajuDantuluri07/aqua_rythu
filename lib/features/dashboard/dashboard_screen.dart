import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../routes/app_routes.dart';
import '../feed/feed_history_provider.dart';
import '../growth/growth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: SafeArea(
        child: currentFarm == null
            ? _buildNoFarmView(context)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildHeader(context, ref, farmState, currentFarm),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Today Overview",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Icon(Icons.insert_chart_outlined_rounded,
                                  color: Colors.grey.shade400, size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildMetricsGrid(context),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Active Ponds",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${currentFarm.ponds.length}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  currentFarm.ponds.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyPonds())
                      : SliverPadding(
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, bottom: 40),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  PondCard(pond: currentFarm.ponds[index]),
                              childCount: currentFarm.ponds.length,
                            ),
                          ),
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, FarmState farmState,
      Farm currentFarm) {
    return Row(
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
                    BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Icon(Icons.water_drop_rounded,
                  color: Theme.of(context).primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
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
          onTap: () => _showFarmSwitchDialog(context, ref, farmState),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  currentFarm.name,
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
    );
  }

  void _showFarmSwitchDialog(
      BuildContext context, WidgetRef ref, FarmState farmState) {
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
              _showAddFarmDialog(context, ref);
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

  void _showAddFarmDialog(BuildContext context, WidgetRef ref) {
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

  Widget _buildNoFarmView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No Farm Selected",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            "Please create or select a farm to continue.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.addFarm),
            icon: const Icon(Icons.add_rounded),
            label: const Text("Create New Farm"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyPonds() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: Icon(Icons.water_drop_outlined,
                size: 40, color: Colors.blue.shade200),
          ),
          const SizedBox(height: 16),
          Text("No ponds added yet",
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: const [
        _StatCard(
          title: "TOTAL BIOMASS",
          value: "2,180",
          unit: " kg",
          icon: Icons.monitor_weight_outlined,
          color: Colors.indigo,
          subtitle: "+120 kg this week",
          positive: true,
        ),
        _StatCard(
          title: "FEED CONSUMED",
          value: "1,245",
          unit: " kg",
          icon: Icons.grain_rounded,
          color: Colors.orange,
          subtitle: "Normal consumption",
          positive: true,
        ),
        _StatCard(
          title: "EST. FCR",
          value: "1.18",
          unit: "",
          icon: Icons.trending_up_rounded,
          color: Colors.green,
          subtitle: "Better than target",
          positive: true,
        ),
        _StatCard(
          title: "AVG GROWTH",
          value: "0.28",
          unit: " g/day",
          icon: Icons.show_chart_rounded,
          color: Colors.teal,
          subtitle: "Last 7 days",
          positive: true,
        ),
      ],
    );
  }
}

class PondCard extends ConsumerWidget {
  final Pond pond;
  const PondCard({super.key, required this.pond});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDoc = ref.watch(docProvider(pond.id));
    final growthLogs = ref.watch(growthProvider(pond.id));
    final historyMap = ref.watch(feedHistoryProvider);
    final feedLogs = historyMap[pond.id] ?? [];

    // Metrics Calculation
    double abw = 0;
    double consumedFeed = feedLogs.fold(0.0, (sum, log) => sum + log.total);
    double survival = 1.0;
    if (currentDoc > 60) {
      survival = 0.90;
    } else if (currentDoc > 30) {
      survival = 0.95;
    } else {
      survival = 1.0;
    }

    if (growthLogs.isNotEmpty) {
      abw = growthLogs.first.averageBodyWeight;
    }

    final double biomass = (pond.seedCount * survival * abw) / 1000;
    final double fcr = biomass > 0 ? consumedFeed / biomass : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.pondDashboard,
                arguments: pond.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.water_rounded,
                              color: Colors.blue.shade300, size: 28),
                          Positioned(
                            bottom: 2,
                            child: Icon(Icons.pets_rounded,
                                color: Colors.blue.shade600, size: 14),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                pond.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Active",
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.editPond,
                                        arguments: pond.id,
                                      );
                                    },
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _PondTag(Icons.calendar_month_rounded,
                                  "DOC $currentDoc"),
                              const SizedBox(width: 12),
                              _PondTag(
                                  Icons.straighten_rounded, "${pond.area} ac"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricItem("ABW", "${abw.toStringAsFixed(1)}g"),
                    _MetricItem("FEED", "${consumedFeed.toStringAsFixed(0)}kg"),
                    _MetricItem("FCR", fcr.toStringAsFixed(2)),
                    _MetricItem("SURVIVAL", "${(survival * 100).toInt()}%"),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetricItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black87)),
      ],
    );
  }
}

class _PondTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PondTag(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// STAT CARD
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool positive;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(Icons.more_horiz_rounded,
                  color: Colors.grey.shade300, size: 20),
            ],
          ),
          const Spacer(),
          Text(title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Subtitle removed to make card less cluttered, or kept simple.
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: positive ? Colors.green.shade600 : Colors.red.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
