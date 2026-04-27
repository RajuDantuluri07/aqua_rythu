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

import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class ResilientConfigService {
  static final ResilientConfigService _instance =
      ResilientConfigService._internal();
  factory ResilientConfigService() => _instance;
  ResilientConfigService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Duration _cacheTimeout = const Duration(hours: 1);

  DateTime? _lastFetch;
  Map<String, dynamic>? _cachedConfig;
  bool _isInitialized = false;

  // Safe default configurations
  static const Map<String, dynamic> _safeDefaults = {
    'feed_engine': {
      'smart_feed_enabled': true,
      'blind_feed_doc_limit': 30,
      'global_feed_multiplier': 1.0,
      'feed_kill_switch': false,
    },
    'pricing': {
      'feed_price_per_kg': 120.0,
      'last_updated_at': '2024-01-01T00:00:00.000Z',
    },
    'features': {
      'feature_smart_feed': true,
      'feature_sampling': true,
      'feature_growth': false,
      'feature_profit': false,
    },
    'announcement': {
      'banner_enabled': false,
      'banner_message': '',
    },
    'debug': {
      'debug_mode_enabled': false,
    },
    'admin_security': {
      'admin_passcode': 'SET_IN_PRODUCTION', // Must be overridden in production
      'admin_user_id': 'SET_IN_PRODUCTION', // Must be overridden in production
    },
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to load from local cache first
      await _loadFromLocalCache();

      // Then refresh from remote if needed
      await _refreshFromRemote();

      _isInitialized = true;
      AppLogger.info('ResilientConfigService initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize ResilientConfigService', e);
      // Still mark as initialized to prevent repeated attempts
      _isInitialized = true;
    }
  }

  Future<Map<String, dynamic>> getConfig(String key) async {
    await initialize();

    // Try cache first
    if (_cachedConfig != null && _cachedConfig!.containsKey(key)) {
      return _cachedConfig![key] ?? _safeDefaults[key] ?? {};
    }

    // Try local file cache
    final localConfig = await _loadFromLocalCache();
    if (localConfig != null && localConfig.containsKey(key)) {
      return localConfig[key] ?? _safeDefaults[key] ?? {};
    }

    // Try remote fetch
    try {
      await _refreshFromRemote();
      if (_cachedConfig != null && _cachedConfig!.containsKey(key)) {
        return _cachedConfig![key] ?? _safeDefaults[key] ?? {};
      }
    } catch (e) {
      AppLogger.warn('Failed to refresh config from remote, using defaults', e);
    }

    // Return safe defaults as last resort
    AppLogger.warn('Using safe defaults for config key: $key');
    return _safeDefaults[key] ?? {};
  }

  Future<void> _refreshFromRemote() async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('key, value, updated_at')
          .order('updated_at', ascending: false);

      if (response.isNotEmpty) {
        final config = <String, dynamic>{};
        for (final item in response) {
          config[item['key']] = item['value'];
        }

        _cachedConfig = config;
        _lastFetch = DateTime.now();

        // Save to local cache
        await _saveToLocalCache(config);

        AppLogger.info('Config refreshed from remote successfully');
      }
    } catch (e) {
      AppLogger.error('Failed to refresh config from remote', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadFromLocalCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/config_cache.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        // Check if cache is still valid
        final cacheTime = DateTime.parse(data['cached_at'] as String);
        if (DateTime.now().difference(cacheTime) < _cacheTimeout) {
          _cachedConfig = data['config'] as Map<String, dynamic>;
          _lastFetch = cacheTime;
          return _cachedConfig;
        }
      }
    } catch (e) {
      AppLogger.warn('Failed to load from local cache', e);
    }
    return null;
  }

  Future<void> _saveToLocalCache(Map<String, dynamic> config) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/config_cache.json');

      final cacheData = {
        'cached_at': DateTime.now().toIso8601String(),
        'config': config,
      };

      await file.writeAsString(jsonEncode(cacheData));
      AppLogger.debug('Config saved to local cache');
    } catch (e) {
      AppLogger.warn('Failed to save to local cache', e);
    }
  }

  Future<void> clearCache() async {
    _cachedConfig = null;
    _lastFetch = null;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/config_cache.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.warn('Failed to clear local cache', e);
    }
  }

  Future<bool> isConfigFresh() async {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < _cacheTimeout;
  }

  // Convenience methods for specific config types
  Future<Map<String, dynamic>> getFeedEngineConfig() async {
    return await getConfig('feed_engine');
  }

  Future<Map<String, dynamic>> getPricingConfig() async {
    return await getConfig('pricing');
  }

  Future<Map<String, dynamic>> getFeaturesConfig() async {
    return await getConfig('features');
  }

  Future<Map<String, dynamic>> getAnnouncementConfig() async {
    return await getConfig('announcement');
  }

  Future<Map<String, dynamic>> getDebugConfig() async {
    return await getConfig('debug');
  }

  Future<Map<String, dynamic>> getAdminSecurityConfig() async {
    return await getConfig('admin_security');
  }

  // Health check method
  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'is_initialized': _isInitialized,
      'last_fetch': _lastFetch?.toIso8601String(),
      'cache_size': _cachedConfig?.length ?? 0,
      'is_cache_fresh': await isConfigFresh(),
      'has_local_cache': await _hasLocalCache(),
    };
  }

  Future<bool> _hasLocalCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/config_cache.json');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
