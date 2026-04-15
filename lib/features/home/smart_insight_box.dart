import 'package:flutter/material.dart';
import 'home_view_model.dart';

/// Displays the single highest-priority insight computed by HomeBuilder.
/// Returns SizedBox.shrink() when insight is null (not enough data).
class SmartInsightBox extends StatelessWidget {
  final InsightData? insight;

  const SmartInsightBox({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    if (insight == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧠', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight!.message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C4A6E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
