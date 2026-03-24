import 'package:flutter/foundation.dart';

class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      print('DEBUG: $message');
    }
  }

  static void info(String message) {
    print('INFO: $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('ERROR: $message');
    if (error != null) {
      print('Cause: $error');
    }
    if (stackTrace != null) {
      print('Stacktrace: $stackTrace');
    }
  }
}
