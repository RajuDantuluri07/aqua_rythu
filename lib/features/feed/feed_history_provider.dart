import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedHistoryLog {
  final DateTime date;
  final int doc;
  final List<double> rounds; // Use a list for flexibility
  final double expected;
  final double cumulative;

  FeedHistoryLog({
    required this.date,
    required this.doc,
    required this.rounds,
    required this.expected,
    required this.cumulative,
  });

  double get total => rounds.fold(0.0, (sum, item) => sum + item);
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
      // Mocking 4 rounds for now, but this can be dynamic
      final mockRounds = List.generate(4, (_) => (baseFeed * 0.25).roundToDouble());
      
      final total = mockRounds.reduce((a, b) => a + b);
      runningCum += total;
      
      // Mock Expected (Simulate overfeeding/underfeeding occasionally)
      final expected = (i % 7 == 0) ? total + 2.0 : total;

      logs.add(FeedHistoryLog(
        date: date,
        doc: doc,
        rounds: mockRounds,
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