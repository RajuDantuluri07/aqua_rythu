import 'package:flutter/material.dart';
import '../../core/enums/tray_status.dart';

class CompletedRoundCard extends StatelessWidget {
  final int round;
  final String time;
  final double feedQty;
  final List<TrayStatus>? trayStatuses;
  final List<String> supplements;

  const CompletedRoundCard({
    super.key,
    required this.round,
    required this.time,
    required this.feedQty,
    this.trayStatuses,
    this.supplements = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Round $round • $time",
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              const Row(
                children: [
                   Icon(Icons.check_circle, color: Colors.green, size: 20),
                   SizedBox(width: 4),
                   Text("DONE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),

          // Feed Qty
          Text(
            "${feedQty.toStringAsFixed(1)} kg",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          
          // Trays
          if (trayStatuses != null && trayStatuses!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: trayStatuses!.map((status) {
                 return Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: status.color.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: status.color.withOpacity(0.3)),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(status.icon, size: 12, color: status.color),
                       const SizedBox(width: 4),
                       Text(
                         status.label, 
                         style: TextStyle(fontSize: 10, color: status.color, fontWeight: FontWeight.bold)
                       ),
                     ],
                   ),
                 );
              }).toList(),
            ),
          ],
          
          // Supplements
          if (supplements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Supplements Added:", style: TextStyle(fontSize: 10, color: Colors.purple.shade900, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...supplements.map((s) => Text("• $s", style: TextStyle(fontSize: 12, color: Colors.purple.shade800))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}