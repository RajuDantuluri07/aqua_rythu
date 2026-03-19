class FeedPlan {
  final int day;
  final double totalFeed; // kg per day
  final List<double> rounds; // 4 rounds

  FeedPlan({
    required this.day,
    required this.totalFeed,
    required this.rounds,
  });
}

enum FeedIntensity {
  low,     // ~140 kg / 1 lakh
  medium,  // ~160 kg / 1 lakh (recommended)
  high,    // ~180 kg / 1 lakh
}

class FeedPlanGenerator {
  static List<FeedPlan> generate({
    required int plCount,              // total seed count
    int durationDays = 30,             // 25 or 30
    FeedIntensity intensity = FeedIntensity.medium,
    double survivalRate = 0.9,         // 90% default
    int feedingsPerDay = 4,            // 4 rounds
  }) {
    List<FeedPlan> plans = [];

    // ✅ 1. Select base feed per 1 lakh PL
    double baseFeedPerLakh;
    switch (intensity) {
      case FeedIntensity.low:
        baseFeedPerLakh = 140;
        break;
      case FeedIntensity.medium:
        baseFeedPerLakh = 160;
        break;
      case FeedIntensity.high:
        baseFeedPerLakh = 180;
        break;
    }

    // ✅ 2. Adjust for survival
    final effectivePL = plCount * survivalRate;

    // ✅ 3. Total feed for full duration
    final totalFeed =
        (effectivePL / 100000) * baseFeedPerLakh; // kg

    // ✅ 4. Phase distribution (REALISTIC INDIA CURVE)
    final phaseSplit = [
      {'start': 1, 'end': 5, 'percent': 0.03},   // 3%
      {'start': 6, 'end': 10, 'percent': 0.07},  // 7%
      {'start': 11, 'end': 20, 'percent': 0.30}, // 30%
      {'start': 21, 'end': durationDays, 'percent': 0.60}, // 60%
    ];

    int currentDay = 1;

    for (var phase in phaseSplit) {
      int start = phase['start'] as int;
      int end = phase['end'] as int;
      double percent = phase['percent'] as double;

      if (start > durationDays) break;
      if (end > durationDays) end = durationDays;

      int daysInPhase = end - start + 1;

      // Feed allocated for this phase
      double phaseFeed = totalFeed * percent;

      // Base feed per day in this phase
      double baseDailyFeed = phaseFeed / daysInPhase;

      for (int i = 0; i < daysInPhase; i++) {
        // ✅ Smooth growth inside phase (8–12% increase)
        double growthFactor = 1 + (i * 0.08);
        double dailyFeed = baseDailyFeed * growthFactor;

        // ✅ Split into feeding rounds
        double perRound = dailyFeed / feedingsPerDay;

        List<double> rounds = List.generate(
          feedingsPerDay,
          (_) => double.parse(perRound.toStringAsFixed(3)),
        );

        plans.add(
          FeedPlan(
            day: currentDay,
            totalFeed: double.parse(dailyFeed.toStringAsFixed(3)),
            rounds: rounds,
          ),
        );

        currentDay++;
      }
    }

    return plans;
  }
}