import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../features/feed/models/feed_explanation.dart';
import '../../features/pond/enums/seed_type.dart';
import '../../features/pond/enums/tray_requirement.dart';

class FeedBaseRate {
  final SeedType seedType;
  final int doc;
  final double baseFeedKgPerLakh;
  final int feedsPerDay;
  final TrayRequirement trayRequirement;
  final bool isBlindFeed;

  const FeedBaseRate({
    required this.seedType,
    required this.doc,
    required this.baseFeedKgPerLakh,
    required this.feedsPerDay,
    required this.trayRequirement,
    required this.isBlindFeed,
  });

  factory FeedBaseRate.fromJson(Map<String, dynamic> json) {
    final seedTypeValue = json['seed_type'] as String? ?? 'nursery';
    final seedType = SeedTypeX.fromDb(seedTypeValue);
    final doc = (json['doc'] as num?)?.toInt() ?? 1;
    final baseFeedKgPerLakh = (json['base_feed_kg'] as num?)?.toDouble() ??
        (json['feed_kg_per_100k'] as num?)?.toDouble() ??
        _legacyRateFor(seedType, doc);
    final feedsPerDay = (json['feeds_per_day'] as num?)?.toInt() ??
        _defaultFeedsPerDay(seedType, doc);
    final trayRequirement = TrayRequirementX.fromDb(
        json['tray_requirement'] as String? ?? _defaultTrayRequirement(seedType, doc).dbValue);
    final isBlindFeed = (json['is_blind_feed'] as bool?) ?? _isBlindDoc(doc);

    return FeedBaseRate(
      seedType: seedType,
      doc: doc,
      baseFeedKgPerLakh: baseFeedKgPerLakh,
      feedsPerDay: feedsPerDay,
      trayRequirement: trayRequirement,
      isBlindFeed: isBlindFeed,
    );
  }

  static double _legacyRateFor(SeedType seedType, int doc) {
    if (seedType == SeedType.nurseryBig) {
      if (doc <= 1) return 4.0;
      if (doc == 2) return 5.0;
      if (doc == 3) return 6.0;
      if (doc == 4) return 7.0;
      if (doc == 5) return 8.0;
      if (doc == 6) return 9.0;
      if (doc == 7) return 10.0;
      if (doc == 8) return 11.0;
      if (doc == 9) return 12.0;
      return 13.0;
    }

    if (doc <= 1) return 1.5;
    if (doc <= 7) return 1.5 + (doc - 1) * 0.2;
    if (doc <= 14) return 2.9 + (doc - 7) * 0.3;
    if (doc <= 21) return 5.8 + (doc - 14) * 0.4;
    return 8.6 + (doc - 21) * 0.5;
  }

  static int _defaultFeedsPerDay(SeedType seedType, int doc) {
    if (seedType == SeedType.nurseryBig) {
      return doc == 1 ? 2 : 4;
    }
    return doc == 1 ? 2 : 4;
  }

  static TrayRequirement _defaultTrayRequirement(SeedType seedType, int doc) {
    if (seedType == SeedType.nurseryBig) {
      return doc <= 10 ? TrayRequirement.optional : TrayRequirement.mandatory;
    }

    if (doc <= 14) return TrayRequirement.notRequired;
    if (doc <= 24) return TrayRequirement.optional;
    return TrayRequirement.mandatory;
  }

  static bool _isBlindDoc(int doc) => doc <= 30;
}

class BlindFeedResult {
  final double totalFeedKg;
  final int feedsPerDay;
  final TrayRequirement trayRequirement;
  final bool isBlindFeed;
  final double baseFeedKgPerLakh;

  const BlindFeedResult({
    required this.totalFeedKg,
    required this.feedsPerDay,
    required this.trayRequirement,
    required this.isBlindFeed,
    required this.baseFeedKgPerLakh,
  });
}

class FeedEngineV2 {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Map<String, FeedBaseRate> _cache = <String, FeedBaseRate>{};

  static String _cacheKey(SeedType seedType, int doc) =>
      '${seedType.dbValue}_$doc';

  static Future<FeedBaseRate> getFeedBaseRate({
    required SeedType seedType,
    required int doc,
  }) async {
    final key = _cacheKey(seedType, doc);
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final row = await _client
          .from('feed_base_rates')
          .select('*')
          .eq('seed_type', seedType.dbValue)
          .eq('doc', doc)
          .maybeSingle();

      final rate = row != null
          ? FeedBaseRate.fromJson(Map<String, dynamic>.from(row))
          : FeedBaseRate(
              seedType: seedType,
              doc: doc,
              baseFeedKgPerLakh: FeedBaseRate._legacyRateFor(seedType, doc),
              feedsPerDay: FeedBaseRate._defaultFeedsPerDay(seedType, doc),
              trayRequirement: FeedBaseRate._defaultTrayRequirement(seedType, doc),
              isBlindFeed: FeedBaseRate._isBlindDoc(doc),
            );

      _cache[key] = rate;
      return rate;
    } catch (e) {
      AppLogger.error(
        'FeedEngineV2 failed to load feed config for ${seedType.dbValue} DOC $doc',
        e,
      );
      final fallback = FeedBaseRate(
        seedType: seedType,
        doc: doc,
        baseFeedKgPerLakh: FeedBaseRate._legacyRateFor(seedType, doc),
        feedsPerDay: FeedBaseRate._defaultFeedsPerDay(seedType, doc),
        trayRequirement: FeedBaseRate._defaultTrayRequirement(seedType, doc),
        isBlindFeed: FeedBaseRate._isBlindDoc(doc),
      );
      _cache[key] = fallback;
      return fallback;
    }
  }

  static Future<BlindFeedResult> getBlindFeed({
    required SeedType seedType,
    required int doc,
    required double seedCountLakhs,
  }) async {
    final rate = await getFeedBaseRate(seedType: seedType, doc: doc);
    return BlindFeedResult(
      totalFeedKg: _scaleFeed(rate.baseFeedKgPerLakh, seedCountLakhs),
      feedsPerDay: rate.feedsPerDay,
      trayRequirement: rate.trayRequirement,
      isBlindFeed: rate.isBlindFeed,
      baseFeedKgPerLakh: rate.baseFeedKgPerLakh,
    );
  }

  static BlindFeedResult getBlindFeedSync({
    required SeedType seedType,
    required int doc,
    required double seedCountLakhs,
  }) {
    final key = _cacheKey(seedType, doc);
    final rate = _cache[key] ?? FeedBaseRate(
      seedType: seedType,
      doc: doc,
      baseFeedKgPerLakh: FeedBaseRate._legacyRateFor(seedType, doc),
      feedsPerDay: FeedBaseRate._defaultFeedsPerDay(seedType, doc),
      trayRequirement: FeedBaseRate._defaultTrayRequirement(seedType, doc),
      isBlindFeed: FeedBaseRate._isBlindDoc(doc),
    );

    return BlindFeedResult(
      totalFeedKg: _scaleFeed(rate.baseFeedKgPerLakh, seedCountLakhs),
      feedsPerDay: rate.feedsPerDay,
      trayRequirement: rate.trayRequirement,
      isBlindFeed: rate.isBlindFeed,
      baseFeedKgPerLakh: rate.baseFeedKgPerLakh,
    );
  }

  static FeedExplanation buildExplanationSync({
    required SeedType seedType,
    required int doc,
    required int seedCount,
    double leftoverPercent = -1,
    bool emptiedFast = false,
  }) {
    final seedCountLakhs = seedCount / 100000;
    final feedResult = getBlindFeedSync(
      seedType: seedType,
      doc: doc,
      seedCountLakhs: seedCountLakhs,
    );

    final trayFactor = _getTrayFactor(
      leftoverPercent: leftoverPercent,
      emptiedFast: emptiedFast,
    );
    final smartFactor = _getSmartFactor(seedType: seedType, doc: doc);
    final finalFeed = calculateFinalFeed(
      baseFeed: feedResult.totalFeedKg,
      trayFactor: trayFactor,
      smartFactor: smartFactor,
    );

    final savings = trayFactor < 0
        ? ((feedResult.totalFeedKg - finalFeed) * 60).clamp(0.0, double.infinity)
        : null;

    return FeedExplanation(
      baseFeed: double.parse(feedResult.totalFeedKg.toStringAsFixed(2)),
      trayImpact: trayFactor,
      smartImpact: smartFactor,
      finalFeed: double.parse(finalFeed.toStringAsFixed(2)),
      message: _buildMessage(trayFactor, smartFactor, savings),
      seedType: seedType,
      doc: doc,
      isSeedTablePhase: doc <= 30,
      savingsRupees: savings != null ? double.parse(savings.toStringAsFixed(0)) : null,
    );
  }

  static double _scaleFeed(double baseFeedKgPerLakh, double seedCountLakhs) {
    return baseFeedKgPerLakh * seedCountLakhs;
  }

  static double _getTrayFactor({
    required double leftoverPercent,
    required bool emptiedFast,
  }) {
    if (leftoverPercent < 0) return 0.0;
    if (leftoverPercent > 20) return -0.10;
    if (emptiedFast) return 0.08;
    return 0.0;
  }

  static double _getSmartFactor({
    required SeedType seedType,
    required int doc,
  }) {
    if (seedType == SeedType.hatcherySmall && doc < 15) return -0.05;
    if (seedType == SeedType.nurseryBig && doc < 10) return 0.05;
    return 0.0;
  }

  static double calculateFinalFeed({
    required double baseFeed,
    required double trayFactor,
    required double smartFactor,
  }) {
    final rawFactor = (1.0 + trayFactor) * (1.0 + smartFactor);
    final clampedFactor = rawFactor.clamp(0.80, 1.20);
    return baseFeed * clampedFactor;
  }

  static String _buildMessage(double trayFactor, double smartFactor, double? savings) {
    final parts = <String>[];

    if (trayFactor < 0) {
      parts.add('Tray leftover detected → reduced by ${(-trayFactor * 100).round()}%');
    } else if (trayFactor > 0) {
      parts.add('Tray emptied fast → increased by ${(trayFactor * 100).round()}%');
    }

    if (smartFactor < 0) {
      parts.add('Conservative early phase → reduced by ${(-smartFactor * 100).round()}%');
    } else if (smartFactor > 0) {
      parts.add('Growth push phase → increased by ${(smartFactor * 100).round()}%');
    }

    if (savings != null && savings > 0) {
      parts.add('Saved ₹${savings.round()} by avoiding overfeeding');
    }

    if (parts.isEmpty) {
      return 'Feed on track — no adjustments needed';
    }

    return parts.join(' · ');
  }
}
