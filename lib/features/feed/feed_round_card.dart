import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pond/pond_dashboard_provider.dart';

class FeedRoundCard extends ConsumerWidget {
  final int round;
  final String time;
  final int currentRound;
  final Function(int) onOpenTray;

  const FeedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.currentRound,
    required this.onOpenTray,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(pondDashboardProvider);

    final trayStatus = dashboardState.trayResults[round];
    final tray = trayStatus?.name;
    final isCurrent = round == currentRound;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Round $round • $time"),
          const SizedBox(height: 8),

          /// TEMP FEED VALUE
          Text(
            "${dashboardState.currentFeed.toStringAsFixed(1)} kg",
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          if (tray != null) Text("Tray: $tray"),

          const SizedBox(height: 10),

          /// ✅ SIMPLIFIED BUTTON (NO OLD PROVIDER)
          ElevatedButton(
            onPressed: () => onOpenTray(round),
            child: const Text("Open Tray"),
          ),
        ],
      ),
    );
  }
}