import 'models/feed_input.dart';
import 'models/feed_output.dart';
import 'feed_calculation_engine.dart';
import 'adjustment_engine.dart';
import 'tray_engine.dart';
import 'fcr_engine.dart';
import 'enforcement_engine.dart';
import 'feed_state_engine.dart';
import '../validators/feed_input_validator.dart';

class MasterFeedEngine {
  static FeedOutput run(FeedInput input) {
    // 🔐 STEP 0: Validate all inputs
    try {
      FeedInputValidator.validate(input);
    } catch (e) {
      return FeedOutput(
        recommendedFeed: 0,
        baseFeed: 0,
        finalFactor: 0,
        alerts: ["🚨 INVALID INPUT: ${e.toString()}"],
        reasons: ["Cannot process feed calculation due to data error"],
      );
    }

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
    final mode = FeedStateEngine.getMode(input.doc, abwSampled: input.abw);
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

    // 5. Enforcement (improved proportional model)
    final enforcementReason = EnforcementEngine.getEnforcementReason(
      input.actualFeedYesterday,
      feed,
    );
    feed = EnforcementEngine.apply(
      recommendedFeed: feed,
      actualFeedYesterday: input.actualFeedYesterday,
    );
    if (enforcementReason.isNotEmpty) {
      reasons.add(enforcementReason);
    }

    // 🔒 6. IMPROVED SAFETY CLAMP: Smart bounds based on conditions
    // If critical conditions detected, DON'T hide them with clamps
    bool hasCriticalCondition = false;
    if (input.dissolvedOxygen < 5) hasCriticalCondition = true;
    if (input.ammonia > 0.2) hasCriticalCondition = true;
    if (input.feedingScore <= 2) hasCriticalCondition = true;
    if (input.intakePercent < 70) hasCriticalCondition = true;
    if (input.mortality > input.seedCount * 0.05) hasCriticalCondition = true;

    // Smart clamping: Allow stricter bounds when problems detected
    double minFeed, maxFeed;
    if (hasCriticalCondition) {
      // In crisis: narrow the range to prevent masking issues
      minFeed = baseFeed * 0.5;    // Hard minimum (50%)
      maxFeed = baseFeed * 1.1;    // Tight maximum (110%)
    } else {
      // Normal conditions: standard safety margins
      minFeed = baseFeed * 0.6;
      maxFeed = baseFeed * 1.3;
    }

    final originalFeedBeforeClamp = feed;
    final clampedFeed = feed.clamp(minFeed, maxFeed);
    
    if ((clampedFeed - originalFeedBeforeClamp).abs() > 0.01) {
      final clampPercent = ((clampedFeed - originalFeedBeforeClamp) / originalFeedBeforeClamp * 100).toStringAsFixed(0);
      if (hasCriticalCondition) {
        reasons.add("⚠️ Critical condition clamp ($clampPercent%) - Review water quality immediately");
      } else {
        reasons.add("Safety clamp applied ($clampPercent%)");
      }
    }
    feed = clampedFeed;

    // 7. Final validation
    try {
      FeedInputValidator.validateOutput(feed, baseFeed);
    } catch (e) {
      reasons.add("⚠️ Output validation: ${e.toString()}");
    }

    // 8. Alerts
    final alerts = _generateAlerts(input);

    return FeedOutput(
      recommendedFeed: feed,
      baseFeed: baseFeed,
      finalFactor: adjustmentFactor,
      alerts: alerts,
      reasons: reasons,
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