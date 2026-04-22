import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/secure_admin_config_service.dart';
import '../../core/models/shrimp_pricing.dart';
import '../../core/utils/logger.dart';

class AdminViewModel {
  final AppConfigService _appConfigService;

  FeedEngineConfig _feedEngineConfig = const FeedEngineConfig(
    smartFeedEnabled: true,
    blindFeedDocLimit: 30,
    globalFeedMultiplier: 1.0,
    feedKillSwitch: false,
  );

  PricingConfig _pricingConfig = PricingConfig(
    feedPricePerKg: 120.0,
    lastUpdatedAt: DateTime.now(),
  );

  FeaturesConfig _featuresConfig = const FeaturesConfig(
    featureSmartFeed: true,
    featureSampling: true,
    featureGrowth: false,
    featureProfit: false,
  );

  AnnouncementConfig _announcementConfig = const AnnouncementConfig(
    bannerEnabled: false,
    bannerMessage: '',
  );

  DebugConfig _debugConfig = const DebugConfig(
    debugModeEnabled: false,
  );

  AdminViewModel(this._appConfigService);

  // Getters for current config state
  FeedEngineConfig get feedEngine => _feedEngineConfig;
  PricingConfig get pricing => _pricingConfig;
  FeaturesConfig get features => _featuresConfig;
  AnnouncementConfig get announcement => _announcementConfig;
  DebugConfig get debug => _debugConfig;

  Future<void> loadConfigs() async {
    try {
      AppLogger.info('Loading admin configurations...');

      // Load all configs in parallel for better performance
      final results = await Future.wait([
        _appConfigService.getFeedEngineConfig(),
        _appConfigService.getPricingConfig(),
        _appConfigService.getFeaturesConfig(),
        _appConfigService.getAnnouncementConfig(),
        _appConfigService.getDebugConfig(),
      ]);

      _feedEngineConfig = results[0] as FeedEngineConfig;
      _pricingConfig = results[1] as PricingConfig;
      _featuresConfig = results[2] as FeaturesConfig;
      _announcementConfig = results[3] as AnnouncementConfig;
      _debugConfig = results[4] as DebugConfig;

      AppLogger.info('Admin configurations loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load admin configurations', e);
      // Keep existing configs as fallback
    }
  }

  Future<bool> saveAllConfigs() async {
    try {
      final secureConfigService = SecureAdminConfigService();

      // Save each config type
      final results = await Future.wait([
        secureConfigService.updateConfig(
            key: 'feed_engine', value: _feedEngineConfig.toJson()),
        secureConfigService.updateConfig(
            key: 'pricing', value: _pricingConfig.toJson()),
        secureConfigService.updateConfig(
            key: 'features', value: _featuresConfig.toJson()),
        secureConfigService.updateConfig(
            key: 'announcement', value: _announcementConfig.toJson()),
        secureConfigService.updateConfig(
            key: 'debug', value: _debugConfig.toJson()),
      ]);

      // Check if all updates succeeded
      final allSuccess = results.every((result) => result['success'] == true);

      if (allSuccess) {
        AppLogger.info('All admin configurations saved successfully');
      } else {
        AppLogger.warn('Some admin configurations failed to save');
      }

      return allSuccess;
    } catch (e) {
      AppLogger.error('Failed to save admin configurations: $e');
      return false;
    }
  }

  Future<bool> updateShrimpPricing(ShrimpPricingConfig config) async {
    try {
      final secureConfigService = SecureAdminConfigService();
      final result = await secureConfigService.updateConfig(
          key: 'shrimp_pricing', value: config.toJson());

      final success = result['success'] == true;

      if (success) {
        AppLogger.info('Shrimp pricing configuration updated successfully');
      } else {
        AppLogger.warn(
            'Failed to update shrimp pricing configuration: ${result['message']}');
      }

      return success;
    } catch (e) {
      AppLogger.error('Failed to update shrimp pricing: $e');
      return false;
    }
  }

  // Update methods for individual configs
  void updateFeedEngineConfig(FeedEngineConfig config) {
    _feedEngineConfig = config;
    AppLogger.debug('Feed engine config updated: ${config.toJson()}');
  }

  void updatePricingConfig(PricingConfig config) {
    _pricingConfig = config.copyWith(lastUpdatedAt: DateTime.now());
    AppLogger.debug('Pricing config updated: ${config.toJson()}');
  }

  void updateFeaturesConfig(FeaturesConfig config) {
    _featuresConfig = config;
    AppLogger.debug('Features config updated: ${config.toJson()}');
  }

  void updateAnnouncementConfig(AnnouncementConfig config) {
    _announcementConfig = config;
    AppLogger.debug('Announcement config updated: ${config.toJson()}');
  }

  void updateDebugConfig(DebugConfig config) {
    _debugConfig = config;
    AppLogger.debug('Debug config updated: ${config.toJson()}');
  }

  // Emergency controls
  void activateKillSwitch() {
    updateFeedEngineConfig(_feedEngineConfig.copyWith(feedKillSwitch: true));
    AppLogger.warn('🚨 EMERGENCY: Feed kill switch ACTIVATED');
  }

  void deactivateKillSwitch() {
    updateFeedEngineConfig(_feedEngineConfig.copyWith(feedKillSwitch: false));
    AppLogger.info('✅ Feed kill switch DEACTIVATED');
  }
}

// Provider for admin view model
final adminViewModelProvider = Provider((ref) {
  final appConfigService = ref.read(appConfigServiceProvider);
  return AdminViewModel(appConfigService);
});
