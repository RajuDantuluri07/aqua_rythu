import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static const _kMaxBytes = 512 * 1024; // 512 KB rolling cap
  static const _kFileName = 'app_logs.txt';

  static Future<File?> getLogFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_kFileName');
    } catch (_) {
      return null;
    }
  }

  // Fire-and-forget — never throws, never blocks.
  static void _write(String level, String message) {
    getLogFile().then((file) async {
      if (file == null) return;
      final ts = DateTime.now().toIso8601String();
      final entry = '$ts [$level] $message\n';
      if (await file.exists() && (await file.length()) > _kMaxBytes) {
        await file.writeAsString(entry); // rotate: start fresh
      } else {
        await file.writeAsString(entry, mode: FileMode.append);
      }
    }).catchError((_) {});
  }

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('DEBUG: $message');
      _write('DEBUG', message);
    }
  }

  static void info(String message, [Object? payload]) {
    if (kDebugMode) {
      debugPrint('INFO: $message');
      if (payload != null) debugPrint('PAYLOAD: $payload');
    } else {
      FirebaseCrashlytics.instance.log('INFO: $message');
    }
    _write('INFO', message);
  }

  static void warn(String message, [Object? payload]) {
    if (kDebugMode) {
      debugPrint('WARN: $message');
      if (payload != null) debugPrint('PAYLOAD: $payload');
    } else {
      FirebaseCrashlytics.instance.log('WARN: $message');
    }
    _write('WARN', message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('ERROR: $message');
      if (error != null) debugPrint('Cause: $error');
      if (stackTrace != null) debugPrint('Stacktrace: $stackTrace');
    } else {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: message,
        fatal: false,
      );
    }
    _write('ERROR', '$message${error != null ? ' | $error' : ''}');
  }
}
