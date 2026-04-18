import 'dart:math' as math;
import '../enums/stocking_type.dart';
import '../dto/feed_config_dto.dart';

/// Configuration for feed calculation based on DOC and stocking type.
/// Now supports remote configuration for scalability and A/B testing.
class FeedConfig {
  static FeedConfigDto _config = const FeedConfigDto(
    hatcheryStart: 2.0,
    hatcheryIncrement: 0.15,
    nurseryStart: 4.0,
    nurseryIncrement: 0.25,
    maxDoc: 200,
  );

  /// Load remote configuration. Call this on app startup or config updates.
  static void load(FeedConfigDto config) {
    _config = config;
  }

  /// Get current configuration (for debugging/monitoring).
  static FeedConfigDto get current => _config;

  // Controlled growth rate for DOC > 30 (slower than the blind-phase ramp).
  static const double _kExtendedIncrementPer100k = 0.08;
  // Max additional feed above the DOC-30 baseline (caps unbounded growth at late DOC).
  static const double _kMaxExtensionPer100k = 5.0;

  static double baseFeedPer100k(int doc, StockingType type) {
    if (doc > 30) {
      // Post-DOC-30: start from DOC-30 baseline, grow 0.08 kg/100K per day,
      // capped at +5.0 kg/100K to prevent overshoot at very late DOC.
      final baseAt30 = _baseAt30(type);
      final extension = math.min((doc - 30) * _kExtendedIncrementPer100k, _kMaxExtensionPer100k);
      return baseAt30 + extension;
    }
    switch (type) {
      case StockingType.hatchery:
        return _config.hatcheryStart + (doc - 1) * _config.hatcheryIncrement;
      case StockingType.nursery:
        return _config.nurseryStart + (doc - 1) * _config.nurseryIncrement;
    }
  }

  static double _baseAt30(StockingType type) {
    switch (type) {
      case StockingType.hatchery:
        return _config.hatcheryStart + 29 * _config.hatcheryIncrement;
      case StockingType.nursery:
        return _config.nurseryStart + 29 * _config.nurseryIncrement;
    }
  }

  static int get maxDoc => _config.maxDoc;
}