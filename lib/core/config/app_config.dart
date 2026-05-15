import 'package:flutter/foundation.dart';

/// App-wide configuration loaded from --dart-define build arguments.
///
/// Pass at build time:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://... \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');
  static const bool isDebugMode = kDebugMode;
}
