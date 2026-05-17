import '../../../features/feed/models/feed_input.dart';

class FeedBlendResult {
  final double blendedFeed;
  final double curveWeight;
  final double observedWeight;
  final List<String> factors;

  const FeedBlendResult({
    required this.blendedFeed,
    required this.curveWeight,
    required this.observedWeight,
    required this.factors,
  });
}

class FeedConfidenceDetail {
  final String level;
  final String summary;
  final List<String> factorExplanations;

  const FeedConfidenceDetail({
    required this.level,
    required this.summary,
    required this.factorExplanations,
  });
}

class FeedIntelligenceLayer {
  static FeedBlendResult blendBaseFeed({
    required double curveFeed,
    required double trayFactor,
    required double envFactor,
    required FeedInput input,
  }) {
    final observedSignal = curveFeed * trayFactor * envFactor;
    // Only count ABW as "observed" if the sample is fresh (≤7 days old).
    final freshAbw = input.abw != null && input.sampleAgeDays <= 7;
    final hasObserved = input.trayStatuses.isNotEmpty || freshAbw;
    final observedWeight = hasObserved ? 0.35 : 0.0;
    final curveWeight = 1.0 - observedWeight;
    final blendedFeed = (curveFeed * curveWeight) + (observedSignal * observedWeight);

    final factors = <String>[
      'Curve baseline weight ${(curveWeight * 100).toStringAsFixed(0)}%',
      'Observed signal weight ${(observedWeight * 100).toStringAsFixed(0)}%',
      if (input.trayStatuses.isNotEmpty) 'Tray observations included',
      if (freshAbw) 'Sampling observation included',
      if (input.abw != null && !freshAbw)
        'Sampling data stale (${input.sampleAgeDays}d) — ignored',
    ];

    return FeedBlendResult(
      blendedFeed: blendedFeed,
      curveWeight: curveWeight,
      observedWeight: observedWeight,
      factors: factors,
    );
  }

  static double applyRampMode({required int doc, required double feed}) {
    if (doc < 31 || doc > 35) return feed;
    final progress = ((doc - 31) / 4.0).clamp(0.0, 1.0);
    final rampFactor = 0.75 + (0.25 * progress);
    return feed * rampFactor;
  }

  static FeedConfidenceDetail buildConfidence({
    required double trayFactor,
    required double envFactor,
    required FeedInput input,
  }) {
    final factors = <String>[];
    var score = 100;

    if (input.trayStatuses.isEmpty) {
      score -= 20;
      factors.add('No tray logs today (-20)');
    } else {
      factors.add('Tray logs available (+0)');
    }

    if (input.abw == null) {
      score -= 15;
      factors.add('No recent sampling data (-15)');
    } else if (input.sampleAgeDays > 7) {
      score -= 10;
      factors.add('Sampling data stale — ${input.sampleAgeDays}d old (-10)');
    } else {
      factors.add('Sampling data available (+0)');
    }

    if (envFactor < 1.0) {
      score -= 15;
      factors.add('Water stress correction active (-15)');
    }

    if (trayFactor != 1.0) {
      score -= 10;
      factors.add('Tray correction active (-10)');
    }

    if (input.validationErrors.isNotEmpty) {
      score -= 20;
      factors.add('Input validation warnings present (-20)');
    }

    final level = score >= 80 ? 'High' : (score >= 60 ? 'Medium' : 'Low');
    return FeedConfidenceDetail(
      level: level,
      summary: 'Confidence $level ($score/100)',
      factorExplanations: factors,
    );
  }
}

