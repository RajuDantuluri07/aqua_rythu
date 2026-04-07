/// App-wide configuration loaded from --dart-define build arguments.
///
/// Pass at build time:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://... \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Fails fast at startup if keys are missing — better than a silent
  /// network error deep in the app.
  static void validate() {
    assert(supabaseUrl.isNotEmpty,
        'SUPABASE_URL is not set. Pass --dart-define=SUPABASE_URL=...');
    assert(supabaseAnonKey.isNotEmpty,
        'SUPABASE_ANON_KEY is not set. Pass --dart-define=SUPABASE_ANON_KEY=...');
  }
}
