import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/shrimp_pricing.dart';

// =============================================================================
// WARNING: STRICT READ-ONLY ACCESS TO app_config TABLE
// =============================================================================
//
// This service is READ-ONLY for the app_config table.
//
// DO NOT WRITE DIRECTLY TO app_config TABLE
// All writes must go through Edge Function: update-app-config
//
// Allowed operations:
//   - .select()  -> YES (read-only)
//
// Forbidden operations:
//   - .insert() -> NO (use Edge Function)
//   - .update() -> NO (use Edge Function)
//   - .upsert() -> NO (use Edge Function)
//   - .delete() -> NO (use Edge Function)
//
// This ensures:
// - All config changes go through security validation
// - Audit logging is guaranteed
// - Rate limiting is enforced
// - Input validation is applied
//
// If you need to update config, use:
// await supabase.functions.invoke('update-app-config', body: {...});
// =============================================================================

// Models for configuration
class FeedEngineConfig {
  final bool smartFeedEnabled;
  final int blindFeedDocLimit;
  final double globalFeedMultiplier;
  final bool feedKillSwitch;

  const FeedEngineConfig({
    required this.smartFeedEnabled,
    required this.blindFeedDocLimit,
    required this.globalFeedMultiplier,
    required this.feedKillSwitch,
  });

  factory FeedEngineConfig.fromJson(Map<String, dynamic> json) {
    return FeedEngineConfig(
      smartFeedEnabled: json['smart_feed_enabled'] as bool? ?? true,
      blindFeedDocLimit: json['blind_feed_doc_limit'] as int? ?? 30,
      globalFeedMultiplier:
          (json['global_feed_multiplier'] as num?)?.toDouble() ?? 1.0,
      feedKillSwitch: json['feed_kill_switch'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smart_feed_enabled': smartFeedEnabled,
      'blind_feed_doc_limit': blindFeedDocLimit,
      'global_feed_multiplier': globalFeedMultiplier,
      'feed_kill_switch': feedKillSwitch,
    };
  }

  FeedEngineConfig copyWith({
    bool? smartFeedEnabled,
    int? blindFeedDocLimit,
    double? globalFeedMultiplier,
    bool? feedKillSwitch,
  }) {
    return FeedEngineConfig(
      smartFeedEnabled: smartFeedEnabled ?? this.smartFeedEnabled,
      blindFeedDocLimit: blindFeedDocLimit ?? this.blindFeedDocLimit,
      globalFeedMultiplier: globalFeedMultiplier ?? this.globalFeedMultiplier,
      feedKillSwitch: feedKillSwitch ?? this.feedKillSwitch,
    );
  }
}

class PricingConfig {
  final double feedPricePerKg;
  final DateTime lastUpdatedAt;

  const PricingConfig({
    required this.feedPricePerKg,
    required this.lastUpdatedAt,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      feedPricePerKg: (json['feed_price_per_kg'] as num?)?.toDouble() ?? 120.0,
      lastUpdatedAt:
          DateTime.tryParse(json['last_updated_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feed_price_per_kg': feedPricePerKg,
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }

  PricingConfig copyWith({
    double? feedPricePerKg,
    DateTime? lastUpdatedAt,
  }) {
    return PricingConfig(
      feedPricePerKg: feedPricePerKg ?? this.feedPricePerKg,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

class FeaturesConfig {
  final bool featureSmartFeed;
  final bool featureSampling;
  final bool featureGrowth;
  final bool featureProfit;

  const FeaturesConfig({
    required this.featureSmartFeed,
    required this.featureSampling,
    required this.featureGrowth,
    required this.featureProfit,
  });

  factory FeaturesConfig.fromJson(Map<String, dynamic> json) {
    return FeaturesConfig(
      featureSmartFeed: json['feature_smart_feed'] as bool? ?? true,
      featureSampling: json['feature_sampling'] as bool? ?? true,
      featureGrowth: json['feature_growth'] as bool? ?? false,
      featureProfit: json['feature_profit'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feature_smart_feed': featureSmartFeed,
      'feature_sampling': featureSampling,
      'feature_growth': featureGrowth,
      'feature_profit': featureProfit,
    };
  }

  FeaturesConfig copyWith({
    bool? featureSmartFeed,
    bool? featureSampling,
    bool? featureGrowth,
    bool? featureProfit,
  }) {
    return FeaturesConfig(
      featureSmartFeed: featureSmartFeed ?? this.featureSmartFeed,
      featureSampling: featureSampling ?? this.featureSampling,
      featureGrowth: featureGrowth ?? this.featureGrowth,
      featureProfit: featureProfit ?? this.featureProfit,
    );
  }
}

class AnnouncementConfig {
  final bool bannerEnabled;
  final String bannerMessage;

  const AnnouncementConfig({
    required this.bannerEnabled,
    required this.bannerMessage,
  });

  factory AnnouncementConfig.fromJson(Map<String, dynamic> json) {
    return AnnouncementConfig(
      bannerEnabled: json['banner_enabled'] as bool? ?? false,
      bannerMessage: json['banner_message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'banner_enabled': bannerEnabled,
      'banner_message': bannerMessage,
    };
  }

  AnnouncementConfig copyWith({
    bool? bannerEnabled,
    String? bannerMessage,
  }) {
    return AnnouncementConfig(
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      bannerMessage: bannerMessage ?? this.bannerMessage,
    );
  }
}

class DebugConfig {
  final bool debugModeEnabled;

  const DebugConfig({
    required this.debugModeEnabled,
  });

  factory DebugConfig.fromJson(Map<String, dynamic> json) {
    return DebugConfig(
      debugModeEnabled: json['debug_mode_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'debug_mode_enabled': debugModeEnabled,
    };
  }

  DebugConfig copyWith({
    bool? debugModeEnabled,
  }) {
    return DebugConfig(
      debugModeEnabled: debugModeEnabled ?? this.debugModeEnabled,
    );
  }
}

class AppConfigService {
  final SupabaseClient _supabase;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  static DateTime? _lastFetch;
  static FeedEngineConfig? _cachedFeedEngineConfig;
  static PricingConfig? _cachedPricingConfig;
  static FeaturesConfig? _cachedFeaturesConfig;
  static AnnouncementConfig? _cachedAnnouncementConfig;
  static DebugConfig? _cachedDebugConfig;

  AppConfigService(this._supabase);

  bool get _isCacheValid {
    return _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTimeout;
  }

  void _invalidateCache() {
    _lastFetch = null;
    _cachedFeedEngineConfig = null;
    _cachedPricingConfig = null;
    _cachedFeaturesConfig = null;
    _cachedAnnouncementConfig = null;
    _cachedDebugConfig = null;
  }

  Future<Map<String, dynamic>?> _getConfig(String key) async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();

      return response?['value'] as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.error('Failed to fetch config for key: $key', e);
      return null;
    }
  }

  Future<void> _updateConfig(String key, Map<String, dynamic> value) async {
    try {
      // Use secure Edge Function instead of direct DB access
      final response = await _supabase.functions.invoke(
        'update-app-config',
        body: {
          'key': key,
          'value': value,
        },
      );

      final data = response.data;

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to update config');
      }

      _invalidateCache();
      AppLogger.info('Config updated for key: $key via Edge Function');
    } catch (e) {
      AppLogger.error('Failed to update config for key: $key', e);
      rethrow;
    }
  }

  Future<FeedEngineConfig> getFeedEngineConfig() async {
    if (_isCacheValid && _cachedFeedEngineConfig != null) {
      return _cachedFeedEngineConfig!;
    }

    final data = await _getConfig('feed_engine');
    _cachedFeedEngineConfig = data != null
        ? FeedEngineConfig.fromJson(data)
        : const FeedEngineConfig(
            smartFeedEnabled: true,
            blindFeedDocLimit: 30,
            globalFeedMultiplier: 1.0,
            feedKillSwitch: false,
          );

    _lastFetch = DateTime.now();
    return _cachedFeedEngineConfig!;
  }

  Future<PricingConfig> getPricingConfig() async {
    if (_isCacheValid && _cachedPricingConfig != null) {
      return _cachedPricingConfig!;
    }

    final data = await _getConfig('pricing');
    _cachedPricingConfig = data != null
        ? PricingConfig.fromJson(data)
        : PricingConfig(
            feedPricePerKg: 120.0,
            lastUpdatedAt: DateTime.now(),
          );

    _lastFetch = DateTime.now();
    return _cachedPricingConfig!;
  }

  Future<FeaturesConfig> getFeaturesConfig() async {
    if (_isCacheValid && _cachedFeaturesConfig != null) {
      return _cachedFeaturesConfig!;
    }

    final data = await _getConfig('features');
    _cachedFeaturesConfig = data != null
        ? FeaturesConfig.fromJson(data)
        : const FeaturesConfig(
            featureSmartFeed: true,
            featureSampling: true,
            featureGrowth: false,
            featureProfit: false,
          );

    _lastFetch = DateTime.now();
    return _cachedFeaturesConfig!;
  }

  Future<AnnouncementConfig> getAnnouncementConfig() async {
    if (_isCacheValid && _cachedAnnouncementConfig != null) {
      return _cachedAnnouncementConfig!;
    }

    final data = await _getConfig('announcement');
    _cachedAnnouncementConfig = data != null
        ? AnnouncementConfig.fromJson(data)
        : const AnnouncementConfig(
            bannerEnabled: false,
            bannerMessage: '',
          );

    _lastFetch = DateTime.now();
    return _cachedAnnouncementConfig!;
  }

  Future<DebugConfig> getDebugConfig() async {
    if (_isCacheValid && _cachedDebugConfig != null) {
      return _cachedDebugConfig!;
    }

    final data = await _getConfig('debug');
    _cachedDebugConfig = data != null
        ? DebugConfig.fromJson(data)
        : const DebugConfig(debugModeEnabled: false);

    _lastFetch = DateTime.now();
    return _cachedDebugConfig!;
  }

  /// Get admin security configuration
  Future<Map<String, dynamic>> getAdminSecurityConfig() async {
    final data = await _getConfig('admin_security');
    return data ?? <String, dynamic>{};
  }

  // Update methods for admin panel
  Future<void> updateFeedEngineConfig(FeedEngineConfig config) async {
    await _updateConfig('feed_engine', config.toJson());
  }

  Future<void> updatePricingConfig(PricingConfig config) async {
    await _updateConfig('pricing', config.toJson());
  }

  Future<void> updateFeaturesConfig(FeaturesConfig config) async {
    await _updateConfig('features', config.toJson());
  }

  Future<void> updateAnnouncementConfig(AnnouncementConfig config) async {
    await _updateConfig('announcement', config.toJson());
  }

  Future<void> updateDebugConfig(DebugConfig config) async {
    await _updateConfig('debug', config.toJson());
  }

  // Refresh all configs
  Future<void> refreshConfigs() async {
    _invalidateCache();
    await Future.wait([
      getFeedEngineConfig(),
      getPricingConfig(),
      getFeaturesConfig(),
      getAnnouncementConfig(),
      getDebugConfig(),
    ]);
  }
}

// Providers
final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService(Supabase.instance.client);
});

final feedEngineConfigProvider = FutureProvider<FeedEngineConfig>((ref) async {
  final service = ref.watch(appConfigServiceProvider);
  return service.getFeedEngineConfig();
});

final pricingConfigProvider = FutureProvider<PricingConfig>((ref) async {
  final service = ref.watch(appConfigServiceProvider);
  return service.getPricingConfig();
});

final featuresConfigProvider = FutureProvider<FeaturesConfig>((ref) async {
  final service = ref.watch(appConfigServiceProvider);
  return service.getFeaturesConfig();
});

final announcementConfigProvider =
    FutureProvider<AnnouncementConfig>((ref) async {
  final service = ref.watch(appConfigServiceProvider);
  return service.getAnnouncementConfig();
});

final debugConfigProvider = FutureProvider<DebugConfig>((ref) async {
  final service = ref.watch(appConfigServiceProvider);
  return service.getDebugConfig();
});
