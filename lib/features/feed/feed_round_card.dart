import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aqua_rythu/features/pond/pond_dashboard_provider.dart';
import 'package:aqua_rythu/features/supplements/supplement_provider.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_calculator.dart';

/// 🔁 Round → Feeding Time
String mapRoundToTimeKey(int round) {
  switch (round) {
    case 1:
      return "morning";
    case 2:
      return "noon";
    case 3:
      return "evening";
    case 4:
      return "night";
    default:
      return "morning";
  }
}

class FeedRoundCard extends ConsumerWidget {
  final int round;
  final String time;
  final double feedQty;
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showTrayCTA;
  final Function(int) onOpenTray;
  final VoidCallback? onMarkDone;

  const FeedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.showTrayCTA,
    required this.onOpenTray,
    this.onMarkDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final supplements = ref.watch(supplementProvider);

    final trayStatus = dashboardState.trayResults[round];
    final tray = trayStatus?.name;

    /// ✅ FROM PROVIDER
    final currentDoc = dashboardState.doc;

    /// 🔁 Map round
    final feedingTime = mapRoundToTimeKey(round);

    /// 🧠 Calculate supplements
    // print("DOC: $currentDoc | Feed: $feedQty | Time: $feedingTime");

    final supplementResults = SupplementCalculator.calculate(
      supplements: supplements,
      currentDoc: currentDoc,
      currentFeedingTime: feedingTime,
      feedQty: feedQty, // ✅ Uses passed qty (plan-based), not static state
      trayCount: 4,
    );
    // print("Supplements: $supplementResults");

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLocked ? Colors.grey.shade100 : (isCurrent ? Colors.green.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isLocked
            ? Border.all(color: Colors.grey.shade300)
            : (isCurrent
                ? Border.all(color: Colors.green, width: 2)
                : Border.all(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Round $round • $time",
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              if (isLocked) const Icon(Icons.lock, size: 16, color: Colors.grey),
            ],
          ),

          const SizedBox(height: 8),

          /// FEED
          Text(
            "${feedQty.toStringAsFixed(1)} kg",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          /// TRAY
          if (tray != null)
            Text(
              "Tray: $tray",
              style: const TextStyle(color: Colors.grey),
            ),

          /// 🧠 SUPPLEMENTS
          if (supplementResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medication_liquid, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "MIX REQUIRED",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...supplementResults.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.supplementName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        ...group.items.map((item) {
                          if (item.totalDose <= 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Flex(
                              direction: Axis.horizontal,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    item.itemName,
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${item.totalDose.toStringAsFixed(1)} ${item.unit}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          /// BUTTONS
          if (isCurrent && !isDone && !isLocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onMarkDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text("MARK AS FED"),
              ),
            )
          else if (isDone)
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text("Feeding Completed", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),

          if (showTrayCTA) ...[
             const SizedBox(height: 8),
             SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onOpenTray(round),
                child: Text(trayStatus != null ? "Update Tray" : "Log Tray Check"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}