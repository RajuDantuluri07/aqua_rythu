import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_config_service.dart';

// Provider for AppConfigService
final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService(Supabase.instance.client);
});
