import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Service to manage configurable feed-related constants
/// Previously hardcoded values in engine_constants.dart are now configurable
class FeedConfigService {
  final SupabaseClient _supabase;

  FeedConfigService(this._supabase);

  // Default values for fallback
  static const double _defaultFeedCostPerKg = 70.0;
  static const double _defaultHarvestPricePerKg = 150.0;
  static const double _defaultFirstMealFactor = 0.8;
  static const double _defaultLastMealFactor = 1.2;
  static const double _defaultMinFeedFactor = 0.70;
  static const double _defaultMaxFeedFactor = 1.30;
  static const int _defaultSmartModeMinDoc = 30;
  static const double _defaultIntelligenceHighThreshold = 15.0;
  static const double _defaultIntelligenceLowThreshold = 5.0;
  static const double _defaultIntelligenceHighFactor = 1.10;
  static const double _defaultIntelligenceMediumFactor = 1.05;
  static const double _defaultIntelligenceLowFactor = 0.95;
  static const double _defaultIntelligenceVeryLowFactor = 0.90;

  /// Get feed cost per kg from config or return default
  Future<double> getFeedCostPerKg({String? farmId}) async {
    try {
      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        final value = farmConfig['feed_cost_per_kg'];
        if (value != null && value is num) {
          return value.toDouble();
        }
      }

      // Fallback to global config
      final globalConfig = await _getGlobalConfig();
      final value = globalConfig['feed_cost_per_kg'];
      if (value != null && value is num) {
        return value.toDouble();
      }

      return _defaultFeedCostPerKg;
    } catch (e) {
      AppLogger.error('Failed to get feed cost per kg, using default', e);
      return _defaultFeedCostPerKg;
    }
  }

  /// Get harvest price per kg from config or return default
  Future<double> getHarvestPricePerKg({String? farmId}) async {
    try {
      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        final value = farmConfig['harvest_price_per_kg'];
        if (value != null && value is num) {
          return value.toDouble();
        }
      }

      // Fallback to global config
      final globalConfig = await _getGlobalConfig();
      final value = globalConfig['harvest_price_per_kg'];
      if (value != null && value is num) {
        return value.toDouble();
      }

      return _defaultHarvestPricePerKg;
    } catch (e) {
      AppLogger.error('Failed to get harvest price per kg, using default', e);
      return _defaultHarvestPricePerKg;
    }
  }

  /// Get meal distribution factors from config or return defaults
  Future<Map<String, double>> getMealFactors({String? farmId}) async {
    try {
      Map<String, double> factors = {
        'first': _defaultFirstMealFactor,
        'last': _defaultLastMealFactor,
      };

      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        final firstFactor = farmConfig['first_meal_factor'];
        final lastFactor = farmConfig['last_meal_factor'];
        
        if (firstFactor != null && firstFactor is num) {
          factors['first'] = firstFactor.toDouble();
        }
        if (lastFactor != null && lastFactor is num) {
          factors['last'] = lastFactor.toDouble();
        }
      }

      return factors;
    } catch (e) {
      AppLogger.error('Failed to get meal factors, using defaults', e);
      return {
        'first': _defaultFirstMealFactor,
        'last': _defaultLastMealFactor,
      };
    }
  }

  /// Get feed factor bounds from config or return defaults
  Future<Map<String, double>> getFeedFactorBounds({String? farmId}) async {
    try {
      Map<String, double> bounds = {
        'min': _defaultMinFeedFactor,
        'max': _defaultMaxFeedFactor,
      };

      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        final minFactor = farmConfig['min_feed_factor'];
        final maxFactor = farmConfig['max_feed_factor'];
        
        if (minFactor != null && minFactor is num) {
          bounds['min'] = minFactor.toDouble();
        }
        if (maxFactor != null && maxFactor is num) {
          bounds['max'] = maxFactor.toDouble();
        }
      }

      return bounds;
    } catch (e) {
      AppLogger.error('Failed to get feed factor bounds, using defaults', e);
      return {
        'min': _defaultMinFeedFactor,
        'max': _defaultMaxFeedFactor,
      };
    }
  }

  /// Get intelligence thresholds from config or return defaults
  Future<Map<String, double>> getIntelligenceThresholds({String? farmId}) async {
    try {
      Map<String, double> thresholds = {
        'high': _defaultIntelligenceHighThreshold,
        'low': _defaultIntelligenceLowThreshold,
      };

      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        final highThreshold = farmConfig['intelligence_high_threshold'];
        final lowThreshold = farmConfig['intelligence_low_threshold'];
        
        if (highThreshold != null && highThreshold is num) {
          thresholds['high'] = highThreshold.toDouble();
        }
        if (lowThreshold != null && lowThreshold is num) {
          thresholds['low'] = lowThreshold.toDouble();
        }
      }

      return thresholds;
    } catch (e) {
      AppLogger.error('Failed to get intelligence thresholds, using defaults', e);
      return {
        'high': _defaultIntelligenceHighThreshold,
        'low': _defaultIntelligenceLowThreshold,
      };
    }
  }

  /// Get intelligence factors from config or return defaults
  Future<Map<String, double>> getIntelligenceFactors({String? farmId}) async {
    try {
      Map<String, double> factors = {
        'high': _defaultIntelligenceHighFactor,
        'medium': _defaultIntelligenceMediumFactor,
        'low': _defaultIntelligenceLowFactor,
        'very_low': _defaultIntelligenceVeryLowFactor,
      };

      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        
        final highFactor = farmConfig['intelligence_high_factor'];
        final mediumFactor = farmConfig['intelligence_medium_factor'];
        final lowFactor = farmConfig['intelligence_low_factor'];
        final veryLowFactor = farmConfig['intelligence_very_low_factor'];
        
        if (highFactor != null && highFactor is num) {
          factors['high'] = highFactor.toDouble();
        }
        if (mediumFactor != null && mediumFactor is num) {
          factors['medium'] = mediumFactor.toDouble();
        }
        if (lowFactor != null && lowFactor is num) {
          factors['low'] = lowFactor.toDouble();
        }
        if (veryLowFactor != null && veryLowFactor is num) {
          factors['very_low'] = veryLowFactor.toDouble();
        }
      }

      return factors;
    } catch (e) {
      AppLogger.error('Failed to get intelligence factors, using defaults', e);
      return {
        'high': _defaultIntelligenceHighFactor,
        'medium': _defaultIntelligenceMediumFactor,
        'low': _defaultIntelligenceLowFactor,
        'very_low': _defaultIntelligenceVeryLowFactor,
      };
    }
  }

  /// Get smart mode minimum DOC from config or return default
  Future<int> getSmartModeMinDoc({String? farmId}) async {
    try {
      if (farmId != null) {
        final farmConfig = await _getFarmConfig(farmId);
        final value = farmConfig['smart_mode_min_doc'];
        if (value != null && value is num) {
          return value.toInt();
        }
      }

      // Fallback to global config
      final globalConfig = await _getGlobalConfig();
      final value = globalConfig['smart_mode_min_doc'];
      if (value != null && value is num) {
        return value.toInt();
      }

      return _defaultSmartModeMinDoc;
    } catch (e) {
      AppLogger.error('Failed to get smart mode min DOC, using default', e);
      return _defaultSmartModeMinDoc;
    }
  }

  /// Update farm-specific configuration
  Future<void> updateFarmConfig(String farmId, Map<String, dynamic> config) async {
    try {
      await _supabase
          .from('farm_configs')
          .upsert({
            'farm_id': farmId,
            'config': config,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'farm_id');
      
      AppLogger.info('Updated farm config for farm: $farmId');
    } catch (e) {
      AppLogger.error('Failed to update farm config for farm: $farmId', e);
      rethrow;
    }
  }

  /// Update global configuration
  Future<void> updateGlobalConfig(Map<String, dynamic> config) async {
    try {
      await _supabase
          .from('global_configs')
          .upsert({
            'id': 'feed_config',
            'config': config,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id');
      
      AppLogger.info('Updated global feed config');
    } catch (e) {
      AppLogger.error('Failed to update global feed config', e);
      rethrow;
    }
  }

  // Private helper methods

  Future<Map<String, dynamic>> _getFarmConfig(String farmId) async {
    final result = await _supabase
        .from('farm_configs')
        .select('config')
        .eq('farm_id', farmId)
        .maybeSingle();
    
    return result?['config'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> _getGlobalConfig() async {
    final result = await _supabase
        .from('global_configs')
        .select('config')
        .eq('id', 'feed_config')
        .maybeSingle();
    
    return result?['config'] as Map<String, dynamic>? ?? {};
  }
}
