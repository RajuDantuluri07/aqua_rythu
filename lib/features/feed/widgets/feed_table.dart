import 'package:flutter/material.dart';
import '../feed_history_provider.dart';
import 'feed_row.dart';

class FeedTable extends StatelessWidget {
  final List<FeedHistoryLog> logs;

  const FeedTable({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Table Header
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: const Row(
            children: [
              _HeaderCell("DATE", flex: 3),
              _HeaderCell("DOC", flex: 2),
              _HeaderCell("R1", flex: 2),
              _HeaderCell("R2", flex: 2),
              _HeaderCell("R3", flex: 2),
              _HeaderCell("R4", flex: 2),
              _HeaderCell("TOT", flex: 3),
              _HeaderCell("Δ", flex: 2),
              _HeaderCell("CUM", flex: 3),
              _HeaderCell("ST", flex: 2),
            ],
          ),
        ),
        // Table Body
        Expanded(
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, thickness: 0.5),
            itemBuilder: (context, index) {
              final log = logs[index];
              // Check for Today
              final now = DateTime.now();
              final isToday = log.date.year == now.year &&
                  log.date.month == now.month &&
                  log.date.day == now.day;

              return FeedRow(log: log, isToday: isToday);
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}
