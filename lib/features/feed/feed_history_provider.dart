import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedHistoryLog {
  final DateTime date;
  final int doc;
  final double r1;
  final double r2;
  final double r3;
  final double r4;
  final double expected;
  final double cumulative;

  FeedHistoryLog({
    required this.date,
    required this.doc,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.expected,
    required this.cumulative,
  });

  double get total => r1 + r2 + r3 + r4;
  double get delta => total - expected;
  
  // Logic: if delta < -1 => Warning
  bool get isWarning => delta < -1;
}

class FeedHistoryNotifier extends StateNotifier<List<FeedHistoryLog>> {
  FeedHistoryNotifier() : super([]) {
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();
    final List<FeedHistoryLog> logs = [];
    double runningCum = 0;

    // Generate 30 days of mock data (Oldest -> Newest for calculation, then reversed for UI)
    // Actually, usually we calculate cumulative from start. 
    // Let's generate from DOC 1 to DOC 32.
    
    for (int i = 0; i < 32; i++) {
      final doc = i + 1;
      final date = now.subtract(Duration(days: 32 - doc));
      
      // Mock Algorithm: Feed increases with DOC
      final double baseFeed = doc * 0.8; 
      
      // Add some noise
      final r1 = (baseFeed * 0.25).roundToDouble();
      final r2 = (baseFeed * 0.25).roundToDouble();
      final r3 = (baseFeed * 0.25).roundToDouble();
      final r4 = (baseFeed * 0.25).roundToDouble();
      
      final total = r1 + r2 + r3 + r4;
      runningCum += total;
      
      // Mock Expected (Simulate overfeeding/underfeeding occasionally)
      final expected = (i % 7 == 0) ? total + 2.0 : total;

      logs.add(FeedHistoryLog(
        date: date,
        doc: doc,
        r1: r1,
        r2: r2,
        r3: r3,
        r4: r4,
        expected: expected,
        cumulative: runningCum,
      ));
    }
    
    // UI needs Newest First (Top)
    state = logs.reversed.toList(); 
  }
}

final feedHistoryProvider = StateNotifierProvider<FeedHistoryNotifier, List<FeedHistoryLog>>((ref) {
  return FeedHistoryNotifier();
});