import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_config.dart';

/// Validates required runtime configuration before the app starts.
///
/// Uses real checks (not assert) so failures surface in release builds.
class RuntimeValidator {
  static List<String> validate() {
    final errors = <String>[];

    if (AppConfig.supabaseUrl.isEmpty) {
      errors.add('SUPABASE_URL is not configured');
    } else if (!AppConfig.supabaseUrl.startsWith('https://')) {
      errors.add('SUPABASE_URL must start with https://');
    }

    if (AppConfig.supabaseAnonKey.isEmpty) {
      errors.add('SUPABASE_ANON_KEY is not configured');
    }

    if (AppConfig.razorpayKeyId.isEmpty) {
      errors.add('RAZORPAY_KEY_ID is not configured');
    }

    return errors;
  }
}

/// Shown instead of the app when required env vars are missing at startup.
/// In debug mode, lists the specific missing keys. In release, shows a
/// generic message to avoid leaking internal configuration names.
class FatalConfigErrorScreen extends StatelessWidget {
  final List<String> errors;

  const FatalConfigErrorScreen({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE53935),
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'App Configuration Error',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This build is missing required configuration and cannot start safely. '
                    'Please contact support.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB300)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Debug — missing keys:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...errors.map(
                            (e) => Text(
                              '• $e',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5D4037),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pass missing values via --dart-define at build time.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
