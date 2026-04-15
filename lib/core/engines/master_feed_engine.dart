import 'models/feed_input.dart';
import 'models/feed_output.dart';
import 'feeding_engine_v1.dart';
import 'feed_factor_engine.dart';
import 'enforcement_engine.dart';
import '../validators/feed_input_validator.dart';

class MasterFeedEngine {
  static const String version = 'v1.0.0';

  static FeedOutput run(FeedInput input) {
    // 🔐 STEP 0: Validate all inputs
    try {
      FeedInputValidator.validate(input);
    } catch (e) {
      return FeedOutput(
        recommendedFeed: 0,
        baseFeed: 0,
        finalFactor: 0,
        fcrFactor: 1.0,
        factorBreakdown: {
          'tray': 1.0,
          'growth': 1.0,
          'sampling': 1.0,
          'environment': 1.0,
          'fcr': 1.0,
        },
        factors: {
          'tray': 1.0,
          'growth': 1.0,
          'sampling': 1.0,
          'environment': 1.0,
          'fcr': 1.0,
        },
        engineVersion: version,
        alerts: ["🚨 INVALID INPUT: ${e.toString()}"],
        reasons: ["Cannot process feed calculation due to data error"],
      );
    }

    final reasons = <String>[];

    // 1. Base feed (using FeedingEngineV1 as single source of truth)
    final baseFeed = FeedingEngineV1.calculateFeed(
      doc: input.doc,
      stockingType: input.stockingType,
      density: input.seedCount,
      leftoverPercent: null,
    );

    final trayFactor = FeedFactorEngine.calculateTrayFactor(
      doc: input.doc,
      trayStatuses: input.trayStatuses,
      recentTrayLeftoverPct: input.recentTrayLeftoverPct,
    );
    final growthFactor = FeedFactorEngine.calculateGrowthFactor(input.abw, input.doc);
    final samplingFactor = FeedFactorEngine.calculateSamplingFactor(
      input.abw,
      input.doc,
      sampleAgeDays: input.sampleAgeDays,
    );
    final environmentFactor = FeedFactorEngine.calculateEnvironmentFactor(
      dissolvedOxygen: input.dissolvedOxygen,
      ammonia: input.ammonia,
    );
    final fcrFactor = FeedFactorEngine.calculateFcrFactor(input.lastFcr);

    final factorBreakdown = {
      'tray': trayFactor,
      'growth': growthFactor,
      'sampling': samplingFactor,
      'environment': environmentFactor,
      'fcr': fcrFactor,
    };
    final factors = Map<String, double>.from(factorBreakdown);

    if (trayFactor != 1.0) {
      reasons.add("Tray signal: ${(trayFactor * 100).toStringAsFixed(0)}% factor");
    }
    if (growthFactor != 1.0) {
      reasons.add("Growth signal: ${(growthFactor * 100).toStringAsFixed(0)}% factor");
    }
    if (samplingFactor != 1.0) {
      reasons.add("Sampling confidence: ${(samplingFactor * 100).toStringAsFixed(0)}% factor");
    }
    if (environmentFactor != 1.0) {
      reasons.add("Environment adjustment: ${(environmentFactor * 100).toStringAsFixed(0)}% factor");
    }
    if (fcrFactor != 1.0) {
      reasons.add("FCR adjustment: ${(fcrFactor * 100).toStringAsFixed(0)}% factor");
    }

    if (input.feedingScore >= 4) reasons.add("✅ Good feeding response");
    if (input.feedingScore <= 2) reasons.add("⚠️ Low feeding score");
    if (input.intakePercent < 70) reasons.add("⚠️ Very low intake");
    if (input.dissolvedOxygen < 5) reasons.add("⚠️ Low dissolved oxygen");
    if (input.ammonia > 0.1) reasons.add("⚠️ High ammonia levels");

    if (environmentFactor == 0.0) {
      return FeedOutput(
        recommendedFeed: 0,
        baseFeed: baseFeed,
        finalFactor: 0,
        fcrFactor: fcrFactor,
        factorBreakdown: factorBreakdown,
        factors: factors,
        engineVersion: version,
        alerts: ["🚨 Critical environment: stop feeding"],
        reasons: reasons.isEmpty
            ? ["Critical: Dissolved oxygen or ammonia level requires no feeding"]
            : reasons,
      );
    }

    final rawFactor = FeedFactorEngine.combineFactors(
      trayFactor: trayFactor,
      growthFactor: growthFactor,
      samplingFactor: samplingFactor,
      environmentFactor: environmentFactor,
    );

    final guardedFactor = FeedFactorEngine.applyFactorGuards(rawFactor * fcrFactor);
    double recommendedFeed = baseFeed * guardedFactor;

    final enforcementReason = EnforcementEngine.getEnforcementReason(
      input.actualFeedYesterday,
      recommendedFeed,
    );
    final enforcedFeed = EnforcementEngine.apply(
      recommendedFeed: recommendedFeed,
      actualFeedYesterday: input.actualFeedYesterday,
    );
    if (enforcementReason.isNotEmpty) {
      reasons.add(enforcementReason);
    }
    recommendedFeed = enforcedFeed;

    final finalFactor = baseFeed > 0 ? recommendedFeed / baseFeed : 0.0;

    final alerts = _generateAlerts(input);
    try {
      FeedInputValidator.validateOutput(recommendedFeed, baseFeed);
    } catch (e) {
      reasons.add("🚨 CRITICAL CALCULATION ANOMALY: ${e.toString()}");
      alerts.add("🚨 System warning: Feed calculation anomaly - using safety base feed");
      recommendedFeed = baseFeed;
    }

    return FeedOutput(
      recommendedFeed: recommendedFeed,
      baseFeed: baseFeed,
      finalFactor: finalFactor,
      fcrFactor: fcrFactor,
      factorBreakdown: factorBreakdown,
      factors: factors,
      engineVersion: version,
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
