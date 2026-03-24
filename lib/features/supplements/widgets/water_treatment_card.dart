import 'package:flutter/material.dart';
import '../screens/supplement_calculator.dart';
import '../supplement_provider.dart';

class WaterTreatmentCard extends StatelessWidget {
  final ActiveWaterTreatment treatment;
  final VoidCallback onApply;
  final VoidCallback onSkip;

  const WaterTreatmentCard({
    super.key,
    required this.treatment,
    required this.onApply,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = treatment.isCompleted;
    final bool isSkipped = treatment.isSkipped;
    final bool isOverdue = treatment.isOverdue && !isCompleted && !isSkipped;
    final bool isNormal = treatment.isDueToday && !isCompleted && !isSkipped;

    Color borderColor = Colors.blue.shade300;
    Color bgColor = Colors.blue.shade50;
    Color iconColor = Colors.blue.shade700;

    if (isOverdue) {
      borderColor = Colors.red.shade300;
      bgColor = Colors.red.shade50;
      iconColor = Colors.red.shade700;
    } else if (isCompleted || isSkipped) {
      borderColor = Colors.grey.shade300;
      bgColor = Colors.white;
      iconColor = isCompleted ? Colors.green : Colors.grey;
    }

    String timeLabel = "";
    if (treatment.preferredTime != null) {
      switch (treatment.preferredTime!) {
        case WaterMixTime.morning: timeLabel = "Morning"; break;
        case WaterMixTime.evening: timeLabel = "Evening"; break;
        case WaterMixTime.afterFeed: timeLabel = "After Feeding"; break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isOverdue || isNormal ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              Icon(Icons.water_drop, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                "WATER TREATMENT",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (isCompleted)
                Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    const Text("Put in pond", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                )
              else if (isSkipped)
                 Row(
                  children: const [
                    Icon(Icons.cancel, color: Colors.grey, size: 16),
                    SizedBox(width: 4),
                    Text("Skipped", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                )
              else if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    "OVERDUE",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    "DUE TODAY",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  ),
                ),
            ],
          ),
          
          if (isOverdue) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  "Risk: Water quality drop. Apply immediately.",
                  style: TextStyle(fontSize: 12, color: Colors.red.shade800, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          
          /// CONTENT
          Text(
            treatment.supplementName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          
          ...treatment.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      item.itemName,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${item.totalDose.toStringAsFixed(1)} ${item.unit}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          if (timeLabel.isNotEmpty)
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  "Time: $timeLabel",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                ),
              ],
            ),

          /// BUTTONS
          if (!isCompleted && !isSkipped) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Text("Skip Treatment?"),
                            ],
                          ),
                          content: const Text(
                            "Skipping water treatment may cause:\n\n"
                            "• Water quality drop\n"
                            "• Risk of oxygen depletion\n"
                            "• Increased disease chance\n\n"
                            "Are you sure you want to skip?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text("CANCEL"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                onSkip();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("YES, SKIP"),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text("SKIP"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOverdue ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("PUT IN POND"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
