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

class FeedRoundCard extends ConsumerStatefulWidget {
  final int round;
  final String time;
  final double feedQty;
  final double? originalQty; // Added for strikethrough display
  final bool isDone;
  final bool isCurrent;
  final bool isLocked;
  final bool showTrayCTA;
  final bool isPendingTray;
  final bool isAutoAdjusted;
  final Function(int) onOpenTray;
  final VoidCallback? onMarkDone;

  const FeedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    this.originalQty,
    required this.isDone,
    required this.isCurrent,
    required this.isLocked,
    required this.showTrayCTA,
    this.isPendingTray = false,
    this.isAutoAdjusted = false,
    required this.onOpenTray,
    this.onMarkDone,
  });

  @override
  ConsumerState<FeedRoundCard> createState() => _FeedRoundCardState();
}

class _FeedRoundCardState extends ConsumerState<FeedRoundCard> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(pondDashboardProvider);
    final supplements = ref.watch(supplementProvider);

    final trayStatus = dashboardState.trayResults[widget.round];
    final tray = trayStatus?.name;

    /// ✅ FROM PROVIDER
    final currentDoc = dashboardState.doc;

    /// 🔁 Map round
    final feedingTime = mapRoundToTimeKey(widget.round);

    /// 🧠 Calculate supplements
    // print("DOC: $currentDoc | Feed: $feedQty | Time: $feedingTime");

    final supplementResults = SupplementCalculator.calculate(
      supplements: supplements,
      currentDoc: currentDoc,
      currentFeedingTime: feedingTime,
      feedQty: widget.feedQty, // ✅ Uses passed qty (plan-based), not static state
    );
    // print("Supplements: $supplementResults");

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isLocked ? Colors.grey.shade100 : (widget.isCurrent ? Colors.green.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: widget.isLocked
            ? Border.all(color: Colors.grey.shade300)
            : (widget.isPendingTray 
                ? Border.all(color: Colors.orange, width: 2) // ⚠️ Pending Tray Border
                : widget.isCurrent
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
                "Round ${widget.round} • ${widget.time}",
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              if (widget.isLocked) 
                const Icon(Icons.lock, size: 16, color: Colors.grey)
              else if (widget.isPendingTray)
                 Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text("TRAY CHECK PENDING", style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          /// FEED
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "${widget.feedQty.toStringAsFixed(1)} kg",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.isAutoAdjusted && widget.originalQty != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      "${widget.originalQty!.toStringAsFixed(1)} kg",
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (widget.isAutoAdjusted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    "AUTO ADJUSTED",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          /// ⚠️ ADJUSTMENT WARNING
          if (widget.isAutoAdjusted && widget.originalQty != null && widget.originalQty! > widget.feedQty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                "Feed reduced due to leftover\nPrevious: ${widget.originalQty!.toStringAsFixed(1)} kg → Now: ${widget.feedQty.toStringAsFixed(1)} kg",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                  height: 1.4,
                ),
              ),
            ),
          ],

          /// TRAY
          if (tray != null)
            Text(
              "Tray: $tray",
              style: const TextStyle(color: Colors.grey),
            ),

          /// 🧠 SUPPLEMENTS
          if (!widget.isLocked && supplementResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_turned_in, size: 16, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "SUPPLEMENT REQUIRED",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.purple.shade800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          "MANDATORY",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
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
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.purple.shade700),
                      const SizedBox(width: 6),
                      Text(
                        "Mix supplements into feed before feeding",
                        style: TextStyle(
                            fontSize: 12, color: Colors.purple.shade800, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          /// BUTTONS
          if (widget.isCurrent && !widget.isDone && !widget.isLocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () async {
                  if (widget.onMarkDone != null) {
                    setState(() => _isSubmitting = true);
                    widget.onMarkDone!(); 
                    // Note: Widget typically rebuilds as DONE immediately after state update, 
                    // so resetting _isSubmitting to false isn't strictly visible but good practice.
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("MARK AS FED"),
              ),
            )
          else if (widget.isDone && !widget.isPendingTray)
            const Row( // Only show simple "Feeding Completed" if tray is also done (or not needed)
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text("Feeding Completed", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),

          if (widget.showTrayCTA) ...[
             const SizedBox(height: 8),
             SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => widget.onOpenTray(widget.round),
                child: Text(trayStatus != null ? "Update Tray" : "Log Tray Check"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}