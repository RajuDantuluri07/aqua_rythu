import '../../core/services/feed_config_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedEngineConstants {
  static final FeedConfigService _configService =
      FeedConfigService(Supabase.instance.client);

  /// Survival rate estimation (PRD 13.2) - These are biological constants, not configurable
  static const Map<int, double> survivalRates = {
    1: 0.98,
    15: 0.96,
    30: 0.93,
    60: 0.88,
    90: 0.83,
    120: 0.80,
  };

  /// Average Body Weight (ABW) targets in grams - Biological constants, not configurable
  static const Map<int, double> abwTargets = {
    1: 0.01,
    15: 0.08,
    30: 0.5,
    45: 2.0,
    60: 5.0,
    75: 10.0,
    90: 18.0,
    105: 25.0,
    120: 32.0,
  };

  /// Feeding Rate (% body weight) - Biological constants, not configurable
  static const Map<int, double> feedingRates = {
    1: 0.15,
    15: 0.12,
    30: 0.08,
    60: 0.05,
    90: 0.035,
    120: 0.025,
  };

  // ── Configurable Constants (now loaded from FeedConfigService) ─────────────────

  /// Get meal distribution factors from config
  static Future<Map<String, double>> getMealFactors({String? farmId}) async {
    return await _configService.getMealFactors(farmId: farmId);
  }

  /// Get feed cost per kg from config
  static Future<double> getFeedCostPerKg({String? farmId}) async {
    return await _configService.getFeedCostPerKg(farmId: farmId);
  }

  /// Get harvest price per kg from config
  static Future<double> getHarvestPricePerKg({String? farmId}) async {
    return await _configService.getHarvestPricePerKg(farmId: farmId);
  }

  /// Get feed factor bounds from config
  static Future<Map<String, double>> getFeedFactorBounds(
      {String? farmId}) async {
    return await _configService.getFeedFactorBounds(farmId: farmId);
  }

  /// Get smart mode minimum DOC from config
  static Future<int> getSmartModeMinDoc({String? farmId}) async {
    return await _configService.getSmartModeMinDoc(farmId: farmId);
  }

  /// Get intelligence thresholds from config
  static Future<Map<String, double>> getIntelligenceThresholds(
      {String? farmId}) async {
    return await _configService.getIntelligenceThresholds(farmId: farmId);
  }

  /// Get intelligence factors from config
  static Future<Map<String, double>> getIntelligenceFactors(
      {String? farmId}) async {
    return await _configService.getIntelligenceFactors(farmId: farmId);
  }

  // ── Legacy Static Methods (for backward compatibility) ─────────────────────────

  /// Legacy method - use getFeedCostPerKg() instead
  @deprecated
  static double get feedCostPerKg => 70.0; // Default fallback

  /// Legacy method - use getHarvestPricePerKg() instead
  @deprecated
  static double get harvestPricePerKg => 150.0; // Default fallback

  /// Legacy method - use getMealFactors() instead
  @deprecated
  static double get firstMealFactor => 0.8; // Default fallback

  /// Legacy method - use getMealFactors() instead
  @deprecated
  static double get lastMealFactor => 1.2; // Default fallback

  /// Legacy method - use getFeedFactorBounds() instead
  @deprecated
  static double get minFeedFactor => 0.70; // Default fallback

  /// Legacy method - use getFeedFactorBounds() instead
  @deprecated
  static double get maxFeedFactor => 1.30; // Default fallback

  /// Legacy method - use getSmartModeMinDoc() instead
  @deprecated
  static int get smartModeMinDoc => 30; // Default fallback

  /// Legacy method - use getIntelligenceThresholds() instead
  @deprecated
  static double get intelligenceHighThreshold => 15.0; // Default fallback

  /// Legacy method - use getIntelligenceThresholds() instead
  @deprecated
  static double get intelligenceLowThreshold => 5.0; // Default fallback

  /// Legacy method - use getIntelligenceFactors() instead
  @deprecated
  static double get intelligenceHighFactor => 1.10; // Default fallback

  /// Legacy method - use getIntelligenceFactors() instead
  @deprecated
  static double get intelligenceMediumFactor => 1.05; // Default fallback

  /// Legacy method - use getIntelligenceFactors() instead
  @deprecated
  static double get intelligenceLowFactor => 0.95; // Default fallback

  /// Legacy method - use getIntelligenceFactors() instead
  @deprecated
  static double get intelligenceVeryLowFactor => 0.90; // Default fallback
}
