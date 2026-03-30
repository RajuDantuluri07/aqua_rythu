import 'models/feed_input.dart';
import 'models/feed_output.dart';
import 'feed_calculation_engine.dart';
import 'adjustment_engine.dart';
import 'tray_engine.dart';
import 'fcr_engine.dart';
import 'enforcement_engine.dart';
import 'feed_state_engine.dart';
import '../enums/tray_status.dart';

class MasterFeedEngine {
  static FeedOutput run(FeedInput input) {
    final reasons = <String>[];

    // 1. Base feed
    final baseFeed = FeedCalculationEngine.calculateFeed(
      seedCount: input.seedCount,
      doc: input.doc,
      currentAbw: input.abw,
    );

    // 2. Adjustment
    final adjustmentFactor = AdjustmentEngine.calculate(input);

    // 🚨 STOP CONDITION
    if (adjustmentFactor == 0.0) {
      return FeedOutput(
        recommendedFeed: 0,
        baseFeed: baseFeed,
        finalFactor: 0,
        alerts: ["🚨 DO too low - STOP feeding"],
        reasons: ["Critical: Dissolved oxygen < 4 ppm"],
      );
    }

    // Track adjustment reasons
    if (adjustmentFactor > 1.0) {
      reasons.add("✅ Positive conditions (+${((adjustmentFactor - 1) * 100).toStringAsFixed(0)}%)");
    } else if (adjustmentFactor < 1.0) {
      reasons.add("⚠️ Challenging conditions (-${((1 - adjustmentFactor) * 100).toStringAsFixed(0)}%)");
    }

    if (input.feedingScore >= 4) reasons.add("✅ Good feeding response");
    if (input.feedingScore <= 2) reasons.add("⚠️ Low feeding score");
    if (input.intakePercent < 70) reasons.add("⚠️ Very low intake");
    if (input.dissolvedOxygen < 5) reasons.add("⚠️ Low dissolved oxygen");
    if (input.ammonia > 0.1) reasons.add("⚠️ High ammonia levels");

    double feed = baseFeed * adjustmentFactor;

    // 3. Tray adjustment
    final mode = FeedStateEngine.getMode(input.doc);
    final originalFeed = feed;
    feed = TrayEngine.apply(
      input.trayStatuses,
      feed,
      mode,
    );

    if ((feed - originalFeed).abs() > 0.01) {
      final adjustment = ((feed - originalFeed) / originalFeed * 100).toStringAsFixed(0);
      reasons.add("Tray adjustment: $adjustment%");
    }

    // 4. FCR correction
    final fcrFactor = FCREngine.correction(input.lastFcr);
    if ((fcrFactor - 1.0).abs() > 0.001) {
      if (input.lastFcr != null && input.lastFcr! <= 1.2) {
        reasons.add("✅ Good FCR: Reward with more feed");
      } else if (input.lastFcr != null && input.lastFcr! > 1.4) {
        reasons.add("⚠️ Poor FCR: Reduce feed");
      }
    }
    feed = feed * fcrFactor;

    // 5. Enforcement
    feed = EnforcementEngine.apply(
      recommendedFeed: feed,
      actualFeedYesterday: input.actualFeedYesterday,
    );

    // 🔒 6. SAFETY CLAMP: Prevent extreme stacking of multipliers
    final minFeed = baseFeed * 0.6;
    final maxFeed = baseFeed * 1.3;
    final clampedFeed = feed.clamp(minFeed, maxFeed);
    
    if ((clampedFeed - feed).abs() > 0.01) {
      reasons.add("Safety clamp applied");
    }
    feed = clampedFeed;

    // 7. Alerts
    final alerts = _generateAlerts(input);

    return FeedOutput(
      recommendedFeed: feed,
      baseFeed: baseFeed,
      finalFactor: adjustmentFactor,
      alerts: alerts,
      reasons: reasons,
    );
  }

    return FeedOutput(
      recommendedFeed: feed,
      baseFeed: baseFeed,
      finalFactor: adjustmentFactor,
      alerts: alerts,
    );
  }

  static List<String> _generateAlerts(FeedInput input) {
    List<String> alerts = [];

    if (input.dissolvedOxygen < 4) {
      alerts.add("🚨 Critical DO - Stop feeding");
    }

    if (input.intakePercent < 80) {
      alerts.add("⚠️ Overfeeding risk");
    }

    if (input.feedingScore <= 2) {
      alerts.add("⚠️ Appetite drop");
    }

    if (input.ammonia > 0.1) {
      alerts.add("⚠️ High ammonia");
    }

    return alerts;
  }
}