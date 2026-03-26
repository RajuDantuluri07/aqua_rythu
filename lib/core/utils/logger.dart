import 'package:flutter/foundation.dart';

class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
    }
  }

  static void info(String message) {
    debugPrint('INFO: $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('ERROR: $message');
    if (error != null) {
      debugPrint('Cause: $error');
    }
    if (stackTrace != null) {
      debugPrint('Stacktrace: $stackTrace');
    }
  }
}
