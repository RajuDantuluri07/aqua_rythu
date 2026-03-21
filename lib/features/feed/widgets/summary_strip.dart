import 'package:flutter/material.dart';

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.green.shade50,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Last 7d: 112kg (+5.2%)"),
          Text("Avg: 16kg"),
        ],
      ),
    );
  }
}