import '../utils/logger.dart';
import '../utils/time_provider.dart';
import 'feed_decision_engine.dart';
import 'package:intl/intl.dart';

class FeedRecommendation {
  final double nextFeedKg;
  final DateTime nextFeedTime;
  final String instruction;

  FeedRecommendation({
    required this.nextFeedKg,
    required this.nextFeedTime,
    required this.instruction,
  });
}

class FeedRecommendationEngine {
  static double roundKg(double value) {
    return (value * 100).round() / 100;
  }

  static String formatKg(double kg) {
    return kg.toStringAsFixed(1);
  }

  static int getFeedsPerDay(int doc) {
    return 4;
  }

  static FeedRecommendation _safeFallback() {
    final now = TimeProvider.now();
    return FeedRecommendation(
      nextFeedKg: 0.0,
      nextFeedTime: now,
      instruction: 'System fallback — check manually',
    );
  }

  static FeedRecommendation compute({
    required double finalFeedPerDay,
    required FeedDecision decision,
    required DateTime? lastFeedTime,
    required int doc,
  }) {
    try {
      if (finalFeedPerDay.isNaN || finalFeedPerDay <= 0 || doc <= 0) {
        return _safeFallback();
      }

      final feedsPerDay = getFeedsPerDay(doc);
      final perFeed = finalFeedPerDay / feedsPerDay;
      if (perFeed.isNaN || perFeed <= 0) {
        return _safeFallback();
      }

      if (decision.action == 'Stop Feeding') {
        return FeedRecommendation(
          nextFeedKg: 0.0,
          nextFeedTime: TimeProvider.now(),
          instruction: 'Do not feed now. Check water quality',
        );
      }

      if (lastFeedTime == null) {
        final kg = roundKg(perFeed);
        final timeStr = DateFormat('h:mm a').format(TimeProvider.now());
        return FeedRecommendation(
          nextFeedKg: kg,
          nextFeedTime: TimeProvider.now(),
          instruction: 'Start first feed — give ${formatKg(kg)} kg at $timeStr',
        );
      }

      double adjusted = perFeed;
      if (decision.action == 'Reduce Feeding') {
        adjusted *= 0.9;
      } else if (decision.action == 'Increase Feeding') {
        adjusted *= 1.1;
      }

      adjusted = adjusted.clamp(perFeed * 0.7, perFeed * 1.3);
      adjusted = roundKg(adjusted);
      if (adjusted.isNaN || adjusted <= 0) {
        return _safeFallback();
      }

      final now = TimeProvider.now();
      final computed = lastFeedTime.add(Duration(minutes: doc > 30 ? 180 : 150));
      final nextTime = computed.isBefore(now) ? now : computed;

      final timeStr = DateFormat('h:mm a').format(nextTime);

      final instruction = decision.action == 'Reduce Feeding'
          ? 'Reduce feed. Give ${formatKg(adjusted)} kg at $timeStr'
          : decision.action == 'Increase Feeding'
              ? 'Increase feed. Give ${formatKg(adjusted)} kg at $timeStr'
              : 'Feed ${formatKg(adjusted)} kg at $timeStr';

      return FeedRecommendation(
        nextFeedKg: adjusted,
        nextFeedTime: nextTime,
        instruction: instruction,
      );
    } catch (e, stack) {
      AppLogger.error('RECOMMENDATION_FALLBACK', e, stack);
      return _safeFallback();
    }
  }
}
