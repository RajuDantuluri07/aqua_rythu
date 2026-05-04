import 'package:flutter/material.dart';
import '../../features/farm/farm_provider.dart';
import '../../systems/feed/seed_feed_engine.dart';

// ── Action types ──────────────────────────────────────────────────────────────

enum DailyActionType {
  partialHarvest, // Priority 1 — capacity stress
  smartFeed,      // Priority 2 — DOC>30, has sampling
  trayFeed,       // Priority 3 — DOC>30, no sampling
  trayStart,      // Priority 4 — DOC 15–30
  feed,           // Priority 5 — DOC <15 (default)
}

extension DailyActionTypeX on DailyActionType {
  int get priority => index + 1;

  String get label {
    switch (this) {
      case DailyActionType.partialHarvest: return 'Partial Harvest';
      case DailyActionType.smartFeed:      return 'Smart Feed Adjust';
      case DailyActionType.trayFeed:       return 'Tray Feed';
      case DailyActionType.trayStart:      return 'Start Tray Feeding';
      case DailyActionType.feed:           return 'Daily Feed';
    }
  }

  IconData get icon {
    switch (this) {
      case DailyActionType.partialHarvest: return Icons.moving_outlined;
      case DailyActionType.smartFeed:      return Icons.auto_fix_high_rounded;
      case DailyActionType.trayFeed:       return Icons.set_meal_rounded;
      case DailyActionType.trayStart:      return Icons.science_outlined;
      case DailyActionType.feed:           return Icons.set_meal_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DailyActionType.partialHarvest: return const Color(0xFFE65100);
      case DailyActionType.smartFeed:      return const Color(0xFF6A1B9A);
      case DailyActionType.trayFeed:       return const Color(0xFF0097A7);
      case DailyActionType.trayStart:      return const Color(0xFF1565C0);
      case DailyActionType.feed:           return const Color(0xFF14613B);
    }
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class DailyAction {
  final DailyActionType type;
  final Pond pond;
  final String title;
  final String message;

  const DailyAction({
    required this.type,
    required this.pond,
    required this.title,
    required this.message,
  });

  int get priority => type.priority;
}

class SamplingSuggestion {
  final Pond pond;
  final String message;

  const SamplingSuggestion({required this.pond, required this.message});
}

// ── Engine ────────────────────────────────────────────────────────────────────

class DailyActionEngine {
  static const double _baseCapacityPerAcre = 3000.0; // kg/acre
  static const double _stressThreshold = 0.7;
  static const double _partialHarvestMinAbw = 15.0; // grams
  static const int _samplingIntervalDays = 10;
  static const int _postHarvestSamplingDelay = 5;
  static const int _samplingStartDoc = 30;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the single most important action for [pond] today.
  static DailyAction getTodaysAction(Pond pond) {
    final doc = pond.doc;
    final abw = pond.currentAbw;
    final stockCount = pond.stockCount ?? pond.seedCount;

    // 1. Partial harvest — highest priority when pond is crowded
    if (abw != null && abw >= _partialHarvestMinAbw) {
      final stress = _calcStress(pond, stockCount, abw);
      if (stress >= _stressThreshold) {
        return DailyAction(
          type: DailyActionType.partialHarvest,
          pond: pond,
          title: 'Pond getting crowded',
          message: 'Reduce stock to improve growth',
        );
      }
    }

    // 2. DOC > 30
    if (doc > 30) {
      if (pond.hasSampling) {
        // 2A. Smart adjustment using tray score
        return DailyAction(
          type: DailyActionType.smartFeed,
          pond: pond,
          title: 'Adjust feed',
          message: _smartFeedMessage(pond.trayScore),
        );
      } else {
        // 2B. No sampling — tray-based feed
        return DailyAction(
          type: DailyActionType.trayFeed,
          pond: pond,
          title: 'Use tray for feeding',
          message: 'Adjust feed based on response',
        );
      }
    }

    // 3. DOC 15–30 — start using feed tray
    if (doc >= 15) {
      return DailyAction(
        type: DailyActionType.trayStart,
        pond: pond,
        title: 'Start using feed tray',
        message: 'Observe feed response daily',
      );
    }

    // 4. DOC < 15 — standard feed plan
    final feedKg = _getFinalFeed(pond);
    return DailyAction(
      type: DailyActionType.feed,
      pond: pond,
      title: 'Follow feed plan',
      message: 'Feed ${feedKg.toStringAsFixed(1)} kg today',
    );
  }

  /// Returns an optional sampling suggestion for [pond] (secondary UI only).
  /// Never blocks the main action.
  static SamplingSuggestion? getSamplingSuggestion(Pond pond) {
    final doc = pond.doc;

    // 1. First sampling — DOC >= 30 with no sampling yet
    if (doc >= _samplingStartDoc && !pond.hasSampling) {
      return SamplingSuggestion(
        pond: pond,
        message: 'Add sampling for better accuracy',
      );
    }

    // 2. Post-harvest check — 5+ days after a partial harvest
    if (pond.harvestStage == 'partial' && pond.lastHarvestDate != null) {
      final daysSince =
          DateTime.now().difference(pond.lastHarvestDate!).inDays;
      if (daysSince >= _postHarvestSamplingDelay) {
        return SamplingSuggestion(
          pond: pond,
          message: 'Check growth after harvest',
        );
      }
    }

    // 3. Regular interval — every 10 days
    if (pond.latestSampleDate != null) {
      final daysSince =
          DateTime.now().difference(pond.latestSampleDate!).inDays;
      if (daysSince >= _samplingIntervalDays) {
        return SamplingSuggestion(
          pond: pond,
          message: 'Check shrimp growth',
        );
      }
    }

    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static double _aerationFactor(String type) {
    switch (type) {
      case 'low':  return 1.0;
      case 'high': return 1.5;
      default:     return 1.2; // 'medium'
    }
  }

  static double _calcStress(Pond pond, int stockCount, double abw) {
    final biomass = (stockCount * abw) / 1000;
    final factor = _aerationFactor(pond.aerationType);
    final capacity = pond.area * _baseCapacityPerAcre * factor;
    if (capacity <= 0) return 0;
    return biomass / capacity;
  }

  static String _smartFeedMessage(String? trayScore) {
    switch (trayScore) {
      case 'good': return 'Shrimp growing well → increase feed by 5%';
      case 'poor': return 'Shrimp not responding → reduce feed by 8%';
      default:     return 'Feed plan on track — shrimp responding well';
    }
  }

  static double _getFinalFeed(Pond pond) {
    final stockCount = pond.stockCount ?? pond.seedCount;
    final baseFeed = SeedFeedEngine.getBaseFeed(
      seedType: pond.seedType,
      doc: pond.doc,
      seedCount: pond.seedCount,
    );
    final stockFactor =
        pond.seedCount > 0 ? stockCount / pond.seedCount : 1.0;
    return (baseFeed * stockFactor * 100).round() / 100;
  }
}
