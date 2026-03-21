import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'feed_plan_provider.dart';

class FeedScheduleScreen extends ConsumerWidget {
  final String pondId;
  const FeedScheduleScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmState = ref.watch(farmProvider);

    Pond? pond;
    for (var farm in farmState.farms) {
      try {
        pond = farm.ponds.firstWhere((p) => p.id == pondId);
        break;
      } catch (_) {}
    }

    if (pond == null) {
      return const Scaffold(
        body: Center(child: Text("Pond not found")),
      );
    }

    final planMap = ref.watch(feedPlanProvider);
    final plan = planMap[pondId];

    if (plan == null) {
      return const Scaffold(
        body: Center(child: Text("No Feed Plan Found")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("${pond.name} Feed Schedule")),
      body: ListView.builder(
        itemCount: plan.days.length,
        itemBuilder: (context, index) {
          final dayPlan = plan.days[index];
          final isToday = dayPlan.doc == pond!.doc;

          return ListTile(
            tileColor: isToday ? Colors.green.shade100 : null,
            leading: CircleAvatar(
              backgroundColor:
                  isToday ? Colors.green : Colors.grey.shade300,
              child: Text(
                "${dayPlan.doc}",
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.black,
                ),
              ),
            ),
            title: Text(
              "Total: ${dayPlan.total.toStringAsFixed(2)} kg",
            ),
            subtitle: Text(
              "R1: ${dayPlan.r1.toStringAsFixed(2)}  "
              "R2: ${dayPlan.r2.toStringAsFixed(2)}  "
              "R3: ${dayPlan.r3.toStringAsFixed(2)}  "
              "R4: ${dayPlan.r4.toStringAsFixed(2)}",
            ),
            trailing: isToday
                ? const Icon(Icons.star, color: Colors.green)
                : null,
          );
        },
      ),
    );
  }
}
