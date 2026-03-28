import 'package:flutter/material.dart';

class FeedRow extends StatelessWidget {
  final dynamic log;
  final bool isToday;

  const FeedRow({
    super.key,
    required this.log,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Time: ${log.time ?? '--'}"),
          Text("Feed: ${log.amount ?? '--'} g"),
          Icon(
            log.done == true ? Icons.check_circle : Icons.pending,
            color: log.done == true ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }
}
