import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Simple timeout wrapper for network operations
class NetworkTimeoutService {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _longTimeout = Duration(seconds: 60);
  static const Duration _shortTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  /// Execute any operation with timeout and retry logic
  static Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    Duration? timeout,
    int? maxRetries,
    String? operationName,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final effectiveMaxRetries = maxRetries ?? _maxRetries;
    final opName = operationName ?? 'network operation';

    for (int attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
      try {
        AppLogger.debug(
            'Executing $opName (attempt ${attempt + 1}/${effectiveMaxRetries + 1})');

        final result = await operation().timeout(
          effectiveTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Operation $opName timed out after ${effectiveTimeout.inSeconds} seconds',
              effectiveTimeout,
            );
          },
        );

        if (attempt > 0) {
          AppLogger.info('$opName succeeded after ${attempt + 1} attempts');
        }

        return result;
      } catch (e) {
        if (attempt == effectiveMaxRetries) {
          AppLogger.error(
              '$opName failed after ${effectiveMaxRetries + 1} attempts: $e');
          rethrow;
        }

        if (e is TimeoutException) {
          AppLogger.warn(
              '$opName timed out, retrying in ${_retryDelay.inSeconds}s...');
        } else {
          AppLogger.warn(
              '$opName failed, retrying in ${_retryDelay.inSeconds}s: $e');
        }

        // Wait before retry with exponential backoff
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }

    throw Exception('Unexpected error in executeWithTimeout');
  }

  /// Extension methods for Supabase operations
  static Future<List<Map<String, dynamic>>> safeQuery(
    SupabaseQueryBuilder query, {
    Duration? timeout,
    String? operationName,
  }) {
    return executeWithTimeout<List<Map<String, dynamic>>>(
      () async => await query,
      timeout: timeout ?? _defaultTimeout,
      operationName: operationName ?? 'database query',
    );
  }

  static Future<Map<String, dynamic>?> safeMaybeSingle(
    SupabaseQueryBuilder query, {
    Duration? timeout,
    String? operationName,
  }) {
    return executeWithTimeout<Map<String, dynamic>?>(
      () async {
        // For now, just return the first result or null
        // This is a simplified implementation
        try {
          final results = await query;
          return results.isNotEmpty ? results.first : null;
        } catch (e) {
          return null;
        }
      },
      timeout: timeout ?? _defaultTimeout,
      operationName: operationName ?? 'database single query',
    );
  }

  static Future<Map<String, dynamic>> safeSingle(
    SupabaseQueryBuilder query, {
    Duration? timeout,
    String? operationName,
  }) {
    return executeWithTimeout<Map<String, dynamic>>(
      () async {
        final results = await query;
        if (results.isEmpty) throw Exception('No results found');
        return results.first;
      },
      timeout: timeout ?? _defaultTimeout,
      operationName: operationName ?? 'database single query',
    );
  }

  static Future<void> safeExecute(
    SupabaseQueryBuilder query, {
    Duration? timeout,
    String? operationName,
  }) {
    return executeWithTimeout(
      () => query,
      timeout: timeout ?? _defaultTimeout,
      operationName: operationName ?? 'database execute',
    );
  }

  static Future<List<Map<String, dynamic>>> safeRpc(
    SupabaseClient client,
    String function, {
    Map<String, dynamic>? params,
    Duration? timeout,
    String? operationName,
  }) {
    return executeWithTimeout(
      () => client.rpc(function, params: params),
      timeout: timeout ?? _defaultTimeout,
      operationName: operationName ?? 'RPC call: $function',
    );
  }
}

/// Extension methods for easy timeout application
extension SupabaseTimeoutExtensions on SupabaseQueryBuilder {
  Future<List<Map<String, dynamic>>> withTimeout([
    Duration? timeout,
    String? operationName,
  ]) {
    return NetworkTimeoutService.safeQuery(this,
        timeout: timeout, operationName: operationName);
  }

  Future<Map<String, dynamic>?> withTimeoutMaybeSingle([
    Duration? timeout,
    String? operationName,
  ]) {
    return NetworkTimeoutService.safeMaybeSingle(this,
        timeout: timeout, operationName: operationName);
  }

  Future<Map<String, dynamic>> withTimeoutSingle([
    Duration? timeout,
    String? operationName,
  ]) {
    return NetworkTimeoutService.safeSingle(this,
        timeout: timeout, operationName: operationName);
  }
}

extension SupabaseClientTimeoutExtensions on SupabaseClient {
  Future<List<Map<String, dynamic>>> rpcWithTimeout(
    String function, {
    Map<String, dynamic>? params,
    Duration? timeout,
    String? operationName,
  }) {
    return NetworkTimeoutService.safeRpc(this, function,
        params: params, timeout: timeout, operationName: operationName);
  }
}
