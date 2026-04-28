import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

/// Comprehensive feed debugging utility for pre-launch validation
class FeedDebugLogger {
  static bool _debugMode = false;
  static const String _logFileName = 'feed_debug.log';
  static final File _logFile = File(_logFileName);

  /// Enable/disable debug mode (hidden feature)
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
    AppLogger.info('Feed debug mode: ${enabled ? "ENABLED" : "DISABLED"}');
  }

  /// Check if debug mode is enabled
  static bool get isDebugMode => _debugMode;

  /// Log feed action with standardized format
  static void logFeedAction({
    required String pondId,
    required int doc,
    required int round,
    required String status,
    required String source,
    double? feedEntered,
    double? feedSaved,
    double? calculatedFeed,
    double? difference,
    String? reason,
    String? error,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    final logEntry = '''
[FEED_LOG]
timestamp: $timestamp
pond_id: $pondId
doc: $doc
round: $round
status: $status
source: $source
${feedEntered != null ? 'feed_entered: ${feedEntered.toStringAsFixed(2)}' : ''}
${feedSaved != null ? 'feed_saved: ${feedSaved.toStringAsFixed(2)}' : ''}
${calculatedFeed != null ? 'calculated_feed: ${calculatedFeed.toStringAsFixed(2)}' : ''}
${difference != null ? 'difference: ${difference.toStringAsFixed(2)}%' : ''}
${reason != null ? 'reason: $reason' : ''}
${error != null ? 'error: $error' : ''}
''';

    // Always log to AppLogger
    if (status == 'failed' || error != null) {
      AppLogger.error('FEED_ACTION: $logEntry');
    } else {
      AppLogger.info('FEED_ACTION: $logEntry');
    }

    // Write to debug file if debug mode is enabled
    if (_debugMode) {
      _writeToLogFile(logEntry);
    }
  }

  /// Log feed error with full context
  static void logFeedError({
    required String pondId,
    required int doc,
    required int round,
    required String operation,
    required dynamic error,
    Map<String, dynamic>? context,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    final logEntry = '''
[FEED_ERROR]
timestamp: $timestamp
pond_id: $pondId
doc: $doc
round: $round
operation: $operation
error: $error
${context != null ? 'context: ${context.toString()}' : ''}
''';

    AppLogger.error('FEED_ERROR: $logEntry');
    
    if (_debugMode) {
      _writeToLogFile(logEntry);
    }
  }

  /// Log duplicate prevention
  static void logDuplicatePrevention({
    required String pondId,
    required int doc,
    required int round,
    required String reason,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    final logEntry = '''
[FEED_DUPLICATE_PREVENTED]
timestamp: $timestamp
pond_id: $pondId
doc: $doc
round: $round
reason: $reason
''';

    AppLogger.warn('FEED_DUPLICATE_PREVENTED: $logEntry');
    
    if (_debugMode) {
      _writeToLogFile(logEntry);
    }
  }

  /// Log transaction state
  static void logTransaction({
    required String pondId,
    required int doc,
    required int round,
    required String transactionType,
    required bool success,
    String? details,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    
    final logEntry = '''
[FEED_TRANSACTION]
timestamp: $timestamp
pond_id: $pondId
doc: $doc
round: $round
type: $transactionType
success: $success
${details != null ? 'details: $details' : ''}
''';

    if (success) {
      AppLogger.info('FEED_TRANSACTION: $logEntry');
    } else {
      AppLogger.error('FEED_TRANSACTION: $logEntry');
    }
    
    if (_debugMode) {
      _writeToLogFile(logEntry);
    }
  }

  /// Write to local log file
  static Future<void> _writeToLogFile(String content) async {
    try {
      await _logFile.writeAsString('$content\n', mode: FileMode.append);
    } catch (e) {
      AppLogger.error('Failed to write to debug log file: $e');
    }
  }

  /// Get recent log entries for testing
  static Future<List<String>> getRecentLogs({int count = 50}) async {
    if (!await _logFile.exists()) {
      return [];
    }

    try {
      final lines = await _logFile.readAsLines();
      return lines.reversed.take(count).toList();
    } catch (e) {
      AppLogger.error('Failed to read debug log file: $e');
      return [];
    }
  }

  /// Clear debug log file
  static Future<void> clearLogs() async {
    try {
      if (await _logFile.exists()) {
        await _logFile.delete();
      }
      AppLogger.info('Debug logs cleared');
    } catch (e) {
      AppLogger.error('Failed to clear debug log file: $e');
    }
  }

  /// Query database for feed logs (for testing)
  static Future<List<Map<String, dynamic>>> queryFeedLogs({
    required String pondId,
    int? doc,
    int? round,
  }) async {
    try {
      final query = Supabase.instance.client
          .from('feed_logs')
          .select('*')
          .eq('pond_id', pondId);

      if (doc != null) {
        query.eq('doc', doc);
      }

      if (round != null) {
        query.eq('round', round);
      }

      query.order('created_at', ascending: false);

      return await query;
    } catch (e) {
      AppLogger.error('Failed to query feed logs: $e');
      return [];
    }
  }

  /// Query database for feed rounds (for testing)
  static Future<List<Map<String, dynamic>>> queryFeedRounds({
    required String pondId,
    int? doc,
    int? round,
  }) async {
    try {
      final query = Supabase.instance.client
          .from('feed_rounds')
          .select('*')
          .eq('pond_id', pondId);

      if (doc != null) {
        query.eq('doc', doc);
      }

      if (round != null) {
        query.eq('round', round);
      }

      query.order('created_at', ascending: false);

      return await query;
    } catch (e) {
      AppLogger.error('Failed to query feed rounds: $e');
      return [];
    }
  }
}
