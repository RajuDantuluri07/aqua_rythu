import 'package:flutter/material.dart';
import '../../core/enums/tray_status.dart';
import 'widgets/supplement_chip.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';

class CompletedRoundCard extends StatelessWidget {
  final int round;
  final String time;
  final double feedQty;
  final double? originalQty;
  final List<TrayStatus>? trayStatuses;
  final List<String> supplements;
  final bool showTraySummary;
  final VoidCallback? onLogTray;

  const CompletedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    this.originalQty,
    this.trayStatuses,
    this.supplements = const [],
    this.showTraySummary = true,
    this.onLogTray,
  });



  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔝 HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "ROUND $round",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("COMPLETED", style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      if (originalQty != null && feedQty < originalQty!) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7), // Amber-100
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text("PARTIAL", style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        feedQty.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text("kg", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("DONE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// 📥 TRAY SUMMARY BOX
          if (showTraySummary && trayStatuses != null && trayStatuses!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (i) {
                  final status = (trayStatuses != null && trayStatuses!.length > i) ? trayStatuses![i] : null;
                  return Column(
                    children: [
                      Text(
                        "TRAY ${i + 1}",
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 4),
                      Text( // Fix #1: Removed unnecessary string interpolation
                        status?.label ?? "EMPTY", 
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: status?.color ?? const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${(feedQty * 10).toInt()}g", // Logic: ~10% per tray approx
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],


          if (supplements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: supplements.map((s) => SupplementChip(
                item: SupplementItem(
                  name: s,
                  unit: "",
                  quantity: 0,
                  isMandatory: false,
                  type: 'feed', // Fix #2: Added missing 'type' parameter
                ),
              )).toList(),
            ),
          ],

          if (onLogTray != null) ...[
             const SizedBox(height: 12),
             SizedBox(
               width: double.infinity,
               child: OutlinedButton.icon(
                 onPressed: onLogTray,
                 icon: const Icon(Icons.add_task_rounded, size: 16),
                 label: Text(trayStatuses != null ? "Update Tray" : "Log Tray Outcome"),
                 style: OutlinedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 10),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                 ),
               ),
             ),
          ],
        ],
      ),
    );

  }
}