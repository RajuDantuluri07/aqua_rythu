import 'package:flutter/foundation.dart';

class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }

  static void info(String message, [Object? payload]) {
    if (!kDebugMode) return;
    debugPrint('INFO: $message');
    if (payload != null) debugPrint('PAYLOAD: $payload');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('ERROR: $message');
    if (error != null) debugPrint('Cause: $error');
    if (stackTrace != null) debugPrint('Stacktrace: $stackTrace');
  }
}
