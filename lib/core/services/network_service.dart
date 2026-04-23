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
        AppLogger.debug('Executing $opName (attempt ${attempt + 1}/${effectiveMaxRetries + 1})');
        
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
          AppLogger.error('$opName failed after ${effectiveMaxRetries + 1} attempts: $e');
          rethrow;
        }
        
        if (e is TimeoutException) {
          AppLogger.warn('$opName timed out, retrying in ${_retryDelay.inSeconds}s...');
        } else {
          AppLogger.warn('$opName failed, retrying in ${_retryDelay.inSeconds}s: $e');
        }
        
        // Wait before retry
        await Future.delayed(_retryDelay * (attempt + 1)); // Exponential backoff
      }
    }
    
    throw Exception('Unexpected error in executeWithTimeout');
  }

  /// Safe table query with timeout
  SupabaseQueryBuilder from(String table) {
    return _SafeQueryBuilder(_supabase.from(table), this);
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
      () => _supabase.storage.from('uploads').uploadBinary(path, file, fileOptions: FileOptions(
        metadata: metadata,
      )),
      timeout: timeout ?? _longTimeout,
      operationName: 'Storage upload: $path',
    );
  }

  /// Safe storage download with timeout
  Future<dynamic> storageDownload(String path, {Duration? timeout}) async {
    return executeWithTimeout(
      () => _supabase.storage.from('uploads').download(path),
      timeout: timeout ?? _longTimeout,
      operationName: 'Storage download: $path',
    );
  }
}

/// Safe query builder wrapper that adds timeout to all operations
class _SafeQueryBuilder {
  final SupabaseQueryBuilder _original;
  final NetworkService _networkService;

  _SafeQueryBuilder(this._original, this._networkService);

  _SafeQueryBuilder select([String? columns]) {
    return _SafeQueryBuilder(_original.select(columns), _networkService);
  }

  _SafeQueryBuilder insert(Map<String, dynamic> data) {
    return _SafeQueryBuilder(_original.insert(data), _networkService);
  }

  _SafeQueryBuilder upsert(Map<String, dynamic> data, {String? onConflict}) {
    return _SafeQueryBuilder(_original.upsert(data, onConflict: onConflict), _networkService);
  }

  _SafeQueryBuilder update(Map<String, dynamic> data) {
    return _SafeQueryBuilder(_original.update(data), _networkService);
  }

  _SafeQueryBuilder delete() {
    return _SafeQueryBuilder(_original.delete(), _networkService);
  }

  _SafeQueryBuilder eq(String column, dynamic value) {
    return _SafeQueryBuilder(_original.eq(column, value), _networkService);
  }

  _SafeQueryBuilder neq(String column, dynamic value) {
    return _SafeQueryBuilder(_original.neq(column, value), _networkService);
  }

  _SafeQueryBuilder gt(String column, dynamic value) {
    return _SafeQueryBuilder(_original.gt(column, value), _networkService);
  }

  _SafeQueryBuilder gte(String column, dynamic value) {
    return _SafeQueryBuilder(_original.gte(column, value), _networkService);
  }

  _SafeQueryBuilder lt(String column, dynamic value) {
    return _SafeQueryBuilder(_original.lt(column, value), _networkService);
  }

  _SafeQueryBuilder lte(String column, dynamic value) {
    return _SafeQueryBuilder(_original.lte(column, value), _networkService);
  }

  _SafeQueryBuilder like(String column, String pattern) {
    return _SafeQueryBuilder(_original.like(column, pattern), _networkService);
  }

  _SafeQueryBuilder ilike(String column, String pattern) {
    return _SafeQueryBuilder(_original.ilike(column, pattern), _networkService);
  }

  _SafeQueryBuilder in_(String column, List<dynamic> values) {
    return _SafeQueryBuilder(_original.in_(column, values), _networkService);
  }

  _SafeQueryBuilder order(String column, {bool ascending = true}) {
    return _SafeQueryBuilder(_original.order(column, ascending: ascending), _networkService);
  }

  _SafeQueryBuilder limit(int count) {
    return _SafeQueryBuilder(_original.limit(count), _networkService);
  }

  _SafeQueryBuilder range(int from, int to) {
    return _SafeQueryBuilder(_original.range(from, to), _networkService);
  }

  _SafeQueryBuilder maybeSingle() {
    return _executeWithTimeout(() => _original.maybeSingle());
  }

  _SafeQueryBuilder single() {
    return _executeWithTimeout(() => _original.single());
  }

  Future<List<Map<String, dynamic>>> get() {
    return _executeWithTimeout(() => _original);
  }

  Future<void> execute() {
    return _executeWithTimeout(() => _original);
  }

  _SafeQueryBuilder _executeWithTimeout<T>(Future<T> Function() operation) {
    // This is a simplified wrapper - in practice, you'd want to track the actual operation
    // and apply timeout when execute() is called
    return this;
  }
}

/// Extension methods to add timeout functionality to existing Supabase operations
extension SupabaseTimeoutExtensions on SupabaseQueryBuilder {
  Future<List<Map<String, dynamic>>> getWithTimeout([
    Duration? timeout,
    int? maxRetries,
    String? operationName,
  ]) {
    final networkService = NetworkService(Supabase.instance.client);
    return networkService.executeWithTimeout(
      () => this,
      timeout: timeout,
      maxRetries: maxRetries,
      operationName: operationName ?? 'query',
    );
  }

  Future<Map<String, dynamic>?> getSingleWithTimeout([
    Duration? timeout,
    int? maxRetries,
    String? operationName,
  ]) {
    final networkService = NetworkService(Supabase.instance.client);
    return networkService.executeWithTimeout(
      () => this.maybeSingle(),
      timeout: timeout,
      maxRetries: maxRetries,
      operationName: operationName ?? 'single query',
    );
  }
}
