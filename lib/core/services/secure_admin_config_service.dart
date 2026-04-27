import 'package:supabase_flutter/supabase_flutter.dart';

class SecureAdminConfigService {
  static final SecureAdminConfigService _instance = SecureAdminConfigService._internal();
  factory SecureAdminConfigService() => _instance;
  SecureAdminConfigService._internal();

  Future<Map<String, dynamic>> updateConfig({
    required String key,
    required dynamic value,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'update-app-config',
        body: {
          'key': key,
          'value': value,
        },
      );

      final data = response.data;
      
      if (data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
        };
      } else {
        throw Exception(data['message'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> updateFeedEngineConfig(Map<String, dynamic> config) async {
    return updateConfig(key: 'feed_engine', value: config);
  }

  Future<Map<String, dynamic>> updatePricingConfig(Map<String, dynamic> config) async {
    return updateConfig(key: 'pricing', value: config);
  }

  Future<Map<String, dynamic>> updateFeaturesConfig(Map<String, dynamic> config) async {
    return updateConfig(key: 'features', value: config);
  }

  Future<Map<String, dynamic>> updateAnnouncementConfig(Map<String, dynamic> config) async {
    return updateConfig(key: 'announcement', value: config);
  }

  Future<Map<String, dynamic>> updateDebugConfig(Map<String, dynamic> config) async {
    return updateConfig(key: 'debug', value: config);
  }

  Future<Map<String, dynamic>> updateAdminSecurityConfig(Map<String, dynamic> config) async {
    return updateConfig(key: 'admin_security', value: config);
  }

  Future<Map<String, dynamic>> updateMultipleConfigs(Map<String, dynamic> configs) async {
    final results = <String, dynamic>{};
    
    for (final entry in configs.entries) {
      final result = await updateConfig(key: entry.key, value: entry.value);
      results[entry.key] = result;
      
      // Stop if any update fails
      if (result['success'] != true) {
        return {
          'success': false,
          'message': 'Failed to update ${entry.key}: ${result['message']}',
          'results': results,
        };
      }
    }
    
    return {
      'success': true,
      'message': 'All configs updated successfully',
      'results': results,
    };
  }
}
