import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed_calculation_engine.dart';

class FeedDayPlan {
  final int doc;
  final List<double> rounds;

  FeedDayPlan({
    required this.doc,
    required this.rounds,
  });

  double get total => rounds.fold(0.0, (sum, qty) => sum + qty);

  // Getters for backward compatibility in strictly typed UIs (optional, but clean to use list access)
  double get r1 => rounds.isNotEmpty ? rounds[0] : 0.0;
  double get r2 => rounds.length > 1 ? rounds[1] : 0.0;
  double get r3 => rounds.length > 2 ? rounds[2] : 0.0;
  double get r4 => rounds.length > 3 ? rounds[3] : 0.0;
}

class FeedPlan {
  final String pondId;
  final List<FeedDayPlan> days;

  FeedPlan({required this.pondId, required this.days});

  double get totalProjected => days.fold(0.0, (sum, day) => sum + day.total);
}

class FeedPlanNotifier extends StateNotifier<Map<String, FeedPlan>> {
  FeedPlanNotifier() : super({});

  void createPlan({
    required String pondId,
    required int seedCount,
    required int plSize,
  }) {
    // if (state.containsKey(pondId)) return; // Allow overwrite for New Cycle

    // Generate 120 days of Standard Blind Plan using Engine (PRD Harvest Cycle)
    final List<FeedDayPlan> days = [];
    for (int i = 1; i <= 120; i++) {
      final dailyTotal = FeedCalculationEngine.calculateFeed(
        seedCount: seedCount,
        doc: i,
      );
      
      // Distribute logic from Engine
      final rounds = FeedCalculationEngine.distributeFeed(dailyTotal, 4);
      
      days.add(FeedDayPlan(
        doc: i,
        rounds: rounds,
      ));
    }

    state = {
      ...state,
      pondId: FeedPlan(pondId: pondId, days: days),
    };
  }

  /// 🔄 RECALCULATE PLAN BASED ON SAMPLING (PRD 3.6)
  /// Call this when Sampling is saved
  void recalculatePlan({
    required String pondId,
    required int currentDoc,
    required double sampledAbw,
    required int seedCount,
  }) {
    final oldPlan = state[pondId];
    if (oldPlan == null) return;

    // 1. Keep past/today days as is (locked)
    final updatedDays = oldPlan.days.where((day) => day.doc <= currentDoc).toList();

    // 2. Project future days up to DOC 120 (Standard Harvest Cycle)
    // Extends the plan if it was short (e.g. only 30 days) and updates existing future days
    const int projectionLimit = 120;

    for (int d = currentDoc + 1; d <= projectionLimit; d++) {
      // Project future ABW (Simple linear growth of 0.2g/day)
      final docDiff = d - currentDoc;
      final projectedAbw = sampledAbw + (docDiff * 0.2); 

      final newTotal = FeedCalculationEngine.calculateFeed(
        seedCount: seedCount,
        doc: d,
        currentAbw: projectedAbw,
      );

      // Distribute into 4 rounds (V1 standard)
      final newRounds = FeedCalculationEngine.distributeFeed(newTotal, 4);
      
      updatedDays.add(FeedDayPlan(doc: d, rounds: newRounds));
    }

    state = {
      ...state,
      pondId: FeedPlan(pondId: pondId, days: updatedDays),
    };
  }

  void updateFeed({
    required String pondId,
    required int doc,
    required int roundIndex,
    required double qty,
  }) {
    final plan = state[pondId];
    if (plan == null) return;

    final updatedDays = plan.days.map((day) {
      if (day.doc == doc) {
        // Create new rounds list with updated value
        if (roundIndex >= 0 && roundIndex < day.rounds.length) {
           final newRounds = List<double>.from(day.rounds);
           newRounds[roundIndex] = qty;
           return FeedDayPlan(doc: doc, rounds: newRounds);
        }
      }
      return day;
    }).toList();

    state = {
      ...state,
      pondId: FeedPlan(pondId: pondId, days: updatedDays),
    };
  }

  void savePlan(String pondId) {
    // In a real app, this would write to Supabase
    // For now, state is already updated in memory
  }

  // Helper to get today's plan safely
  FeedDayPlan? getDayPlan(String pondId, int doc) {
    final plan = state[pondId];
    if (plan == null) return null;
    return plan.days.firstWhere((d) => d.doc == doc, 
      orElse: () => FeedDayPlan(doc: doc, rounds: [0.0, 0.0, 0.0, 0.0]));
  }
}

final feedPlanProvider = StateNotifierProvider<FeedPlanNotifier, Map<String, FeedPlan>>((ref) {
  return FeedPlanNotifier();
});