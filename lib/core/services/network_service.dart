import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Network service wrapper with timeout configuration and retry logic
class NetworkService {
  final SupabaseClient _supabase;

  // Default timeout durations
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _longTimeout = Duration(seconds: 60);
  static const Duration _shortTimeout = Duration(seconds: 10);

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);

  NetworkService(this._supabase);

  /// Execute a database operation with timeout and retry logic
  Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    Duration? timeout,
    int? maxRetries,
    String? operationName,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final effectiveMaxRetries = maxRetries ?? _maxRetries;
    final opName = operationName ?? 'database operation';

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

        // Wait before retry
        await Future.delayed(
            _retryDelay * (attempt + 1)); // Exponential backoff
      }
    }

    throw Exception('Unexpected error in executeWithTimeout');
  }

  /// Safe table query with timeout - returns raw SupabaseQueryBuilder
  SupabaseQueryBuilder from(String table) {
    return _supabase.from(table);
  }

  /// Safe RPC call with timeout
  Future<List<Map<String, dynamic>>> rpc(
    String function, {
    Map<String, dynamic>? params,
    Duration? timeout,
  }) async {
    return executeWithTimeout(
      () => _supabase.rpc(function, params: params),
      timeout: timeout ?? _defaultTimeout,
      operationName: 'RPC call: $function',
    );
  }

  /// Safe storage operations with timeout
  Future<void> storageUpload(
    String path,
    dynamic file, {
    Map<String, String>? metadata,
    Duration? timeout,
  }) async {
    return executeWithTimeout(
      () => _supabase.storage.from('uploads').uploadBinary(path, file,
          fileOptions: FileOptions(
            metadata: metadata,
          )),
      timeout: timeout ?? _longTimeout,
      operationName: 'Storage upload: $path',
    );
  }

  /// Safe storage download with timeout
  Future<String> storageGetPublicUrl(String path) async {
    return executeWithTimeout<String>(
      () async => _supabase.storage.from('uploads').getPublicUrl(path),
      operationName: 'Storage get public URL: $path',
    );
  }
}
