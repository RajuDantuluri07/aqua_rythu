import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'feed_plan_provider.dart';

class FeedScheduleScreen extends ConsumerStatefulWidget {
  final String pondId;
  const FeedScheduleScreen({super.key, required this.pondId});

  @override
  ConsumerState<FeedScheduleScreen> createState() => _FeedScheduleScreenState();
}

class _FeedScheduleScreenState extends ConsumerState<FeedScheduleScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  void _scrollToToday() {
    final pond = _getPond();
    if (pond == null) return;
    
    // Estimate scroll position (roughly 80 pixels per item)
    final double offset = (pond.doc - 2) * 80.0;
    if (offset > 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Pond? _getPond() {
    final farmState = ref.read(farmProvider);
    for (var farm in farmState.farms) {
      try {
        return farm.ponds.firstWhere((p) => p.id == widget.pondId);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pond = _getPond();

    if (pond == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Feed Schedule")),
        body: const Center(child: Text("Pond not found")),
      );
    }

    final planMap = ref.watch(feedPlanProvider);
    final plan = planMap[widget.pondId];

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Feed Schedule")),
        body: const Center(child: Text("No Feed Plan Found")),
      );
    }

    // Calculate totals
    double totalFeedCycle = plan.days.fold(0, (sum, day) => sum + day.total);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 50, bottom: 16),
              title: const Text(
                "Feed Schedule",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Total Cycle Feed",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        "${totalFeedCycle.toStringAsFixed(0)} kg",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final dayPlan = plan.days[index];
                  final isToday = dayPlan.doc == pond.doc;
                  final isFuture = dayPlan.doc > pond.doc;

                  return _buildDayCard(context, dayPlan, isToday, isFuture);
                },
                childCount: plan.days.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, FeedDayPlan dayPlan, bool isToday, bool isFuture) {
    Color cardColor = Colors.white;
    Color textColor = Colors.black87;
    Color iconColor = Colors.grey.shade400;

    if (isToday) {
      cardColor = Theme.of(context).primaryColor;
      textColor = Colors.white;
      iconColor = Colors.white70;
    } else if (isFuture) {
      cardColor = Colors.white.withOpacity(0.7);
      textColor = Colors.grey.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isToday
            ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        border: isFuture ? Border.all(color: Colors.grey.shade200) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // DOC Badge
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? Colors.white.withOpacity(0.2) : (isFuture ? Colors.grey.shade100 : Colors.blue.shade50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    "DOC",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white70 : (isFuture ? Colors.grey.shade500 : Colors.blue.shade300),
                    ),
                  ),
                  Text(
                    "${dayPlan.doc}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isToday ? Colors.white : (isFuture ? Colors.grey.shade400 : Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total: ${dayPlan.total.toStringAsFixed(1)} kg",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "TODAY",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                      else if (!isFuture)
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      _mealText("R1", dayPlan.r1, textColor),
                      _mealText("R2", dayPlan.r2, textColor),
                      _mealText("R3", dayPlan.r3, textColor),
                      _mealText("R4", dayPlan.r4, textColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealText(String label, double val, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: ", style: TextStyle(color: color.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
        Text("${val.toStringAsFixed(1)}", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

