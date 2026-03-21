import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feed_history_provider.dart';
import 'widgets/summary_strip.dart';
import 'widgets/feed_table.dart';

class FeedHistoryScreen extends ConsumerWidget {
  final String pondId;
  const FeedHistoryScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the new history provider
    final logs = ref.watch(feedHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      
      // 1. HEADER SECTION
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Feed History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("POND 1 | DOC 32", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {}, // Date picker placeholder
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {}, // Export placeholder
          ),
        ],
      ),
      
      body: Column(
        children: [
          // 2. SUMMARY STRIP
          const SummaryStrip(),
          
          const Divider(height: 1),
          
          // 3. TABLE LAYOUT
          Expanded(child: FeedTable(logs: logs)),
        ],
      ),
    );
  }
}