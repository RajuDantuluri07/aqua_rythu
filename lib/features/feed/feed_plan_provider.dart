import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/core/engines/feed_calculation_engine.dart';

/// =======================
/// MODELS
/// =======================

class FeedDayPlan {
  final int doc;
  double r1;
  double r2;
  double r3;
  double r4;

  FeedDayPlan({
    required this.doc,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
  });

  double get total => r1 + r2 + r3 + r4;
}

class FeedPlan {
  final String pondId;
  final List<FeedDayPlan> days;

  FeedPlan({
    required this.pondId,
    required this.days,
  });

  double get totalProjected =>
      days.fold(0, (sum, d) => sum + d.total);
}

/// =======================
/// NOTIFIER
/// =======================

class FeedPlanNotifier extends StateNotifier<Map<String, FeedPlan>> {
  FeedPlanNotifier() : super({});

  /// ✅ CLEAN PLAN GENERATION
  void createPlan({
    required String pondId,
    required int seedCount,
    required int plSize,
  }) {
    final List<FeedDayPlan> days = [];

    for (int day = 1; day <= 30; day++) {
      final totalFeed = FeedCalculationEngine.calculateFeed(
        seedCount: seedCount,
        doc: day,
      );

      final splits = FeedCalculationEngine.distributeFeed(totalFeed, 4);

      days.add(
        FeedDayPlan(
          doc: day,
          r1: splits[0],
          r2: splits[1],
          r3: splits[2],
          r4: splits[3],
        ),
      );
    }

    state = {
      ...state,
      pondId: FeedPlan(
        pondId: pondId,
        days: days,
      ),
    };
  }

  /// ✏️ UPDATE FEED
  void updateFeed({
    required String pondId,
    required int doc,
    double? r1,
    double? r2,
    double? r3,
    double? r4,
  }) {
    final plan = state[pondId];
    if (plan == null) return;

    final dayPlan = plan.days.firstWhere((d) => d.doc == doc);

    if (r1 != null) dayPlan.r1 = r1;
    if (r2 != null) dayPlan.r2 = r2;
    if (r3 != null) dayPlan.r3 = r3;
    if (r4 != null) dayPlan.r4 = r4;

    state = {...state};
  }

  /// 💾 SAVE PLAN
  void savePlan(String pondId) {
    final plan = state[pondId];
    if (plan == null) return;

    print("✅ Feed Plan Saved for $pondId");
    print("Total: ${plan.totalProjected}");
  }
}

/// =======================
/// PROVIDER
/// =======================

final feedPlanProvider =
    StateNotifierProvider<FeedPlanNotifier, Map<String, FeedPlan>>(
  (ref) => FeedPlanNotifier(),
);