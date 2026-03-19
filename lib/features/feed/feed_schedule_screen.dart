import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../pond/feed_plan_generator.dart';

class FeedScheduleScreen extends ConsumerWidget {
  final String pondId;
  const FeedScheduleScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get Pond Details
    final farmState = ref.watch(farmProvider);
    Pond? pond;
    for (var farm in farmState.farms) {
      try {
        pond = farm.ponds.firstWhere((p) => p.id == pondId);
        break;
      } catch (_) {}
    }

    if (pond == null) return const Scaffold(body: Center(child: Text("Pond not found")));

    final plan = FeedPlanGenerator.generate(plCount: pond.seedCount, durationDays: 60);
    final currentDoc = pond.doc;

    return Scaffold(
      appBar: AppBar(title: Text("${pond.name} Feed Schedule")),
      body: ListView.builder(
        itemCount: plan.length,
        itemBuilder: (context, index) {
          final dayPlan = plan[index];
          final isToday = dayPlan.day == currentDoc;

          return ListTile(
            tileColor: isToday ? Colors.green.shade100 : null,
            leading: CircleAvatar(
              backgroundColor: isToday ? Colors.green : Colors.grey.shade300,
              child: Text("${dayPlan.day}", style: TextStyle(color: isToday ? Colors.white : Colors.black)),
            ),
            title: Text("Total: ${dayPlan.totalFeed.toStringAsFixed(2)} kg"),
            subtitle: Text("R1: ${dayPlan.rounds[0]}  R2: ${dayPlan.rounds[1]}  R3: ${dayPlan.rounds[2]}  R4: ${dayPlan.rounds[3]}"),
            trailing: isToday ? const Icon(Icons.star, color: Colors.green) : null,
          );
        },
      ),
    );
  }
}