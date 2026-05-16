import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed_pending_operation.dart';
import '../utils/logger.dart';

/// Thin interface so FeedSyncQueue can call back into FeedService without
/// a circular import. FeedService implements this.
abstract class FeedCompletionSink {
  Future<void> completeFeedRoundIdempotent({
    required String pondId,
    required int doc,
    required int round,
    required double amount,
    required double baseFeed,
    required DateTime createdAt,
    required String operationId,
  });
}

/// Persistent offline queue for feed completion operations.
///
/// Operations are stored in SharedPreferences and survive app restarts.
/// The queue is processed with exponential backoff — retries use the same
/// [FeedPendingOperation.operationId] so the DB deduplicates them.
///
/// Usage:
///   1. Before calling the DB, generate an operationId.
///   2. If the DB call succeeds, done.
///   3. If the DB call fails, call [enqueue()] with the same operationId.
///   4. On app start and network reconnect, call [processQueue()].
class FeedSyncQueue {
  static const _storageKey = 'feed_pending_operations_v1';
  static const _maxAttempts = 5;
  static const _baseDelaySeconds = 5;
  static const _maxDelaySeconds = 300; // 5 min cap

  static final FeedSyncQueue _instance = FeedSyncQueue._internal();
  factory FeedSyncQueue() => _instance;
  FeedSyncQueue._internal();

  bool _isProcessing = false;
  DateTime? _processStartedAt;
  // If a process run is older than this, consider it stale (e.g. process
  // resumed after being suspended mid-run without hitting the finally block).
  static const _processTimeoutSeconds = 120;
  final _rng = Random.secure();

  // ── Public API ────────────────────────────────────────────────────────────

  /// Enqueue a failed/pending feed operation for later sync.
  /// Deduplicates by operationId — enqueueing the same op twice is safe.
  Future<void> enqueue(FeedPendingOperation op) async {
    final prefs = await SharedPreferences.getInstance();
    final ops = await _loadAll(prefs);
    ops.removeWhere((o) => o.operationId == op.operationId);
    ops.add(op);
    await _saveAll(prefs, ops);
    AppLogger.info(
        'FeedSyncQueue: enqueued ${op.operationId} '
        '(pond=${op.pondId} doc=${op.doc} r=${op.round} '
        '${op.feedKg.toStringAsFixed(2)}kg)');
  }

  /// Process all pending operations using [sink] (typically FeedService).
  /// Re-entrant safe: concurrent calls are no-ops until the first completes.
  Future<void> processQueue(FeedCompletionSink sink) async {
    // Reset stale lock: if a previous run started more than _processTimeoutSeconds
    // ago and never hit the finally block (e.g. process resumed after OOM suspend),
    // clear the flag so the queue isn't permanently stuck.
    if (_isProcessing) {
      final started = _processStartedAt;
      final stale = started != null &&
          DateTime.now().difference(started).inSeconds > _processTimeoutSeconds;
      if (!stale) return;
      AppLogger.warn('FeedSyncQueue: clearing stale _isProcessing lock');
    }
    _isProcessing = true;
    _processStartedAt = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      final ops = await _loadAll(prefs);
      if (ops.isEmpty) return;

      final now = DateTime.now();
      bool changed = false;

      for (final op in ops) {
        if (op.status == FeedOpStatus.synced) continue;
        if (op.status == FeedOpStatus.failed) continue;
        if (op.nextRetryAt != null && op.nextRetryAt!.isAfter(now)) continue;

        try {
          await sink.completeFeedRoundIdempotent(
            pondId: op.pondId,
            doc: op.doc,
            round: op.round,
            amount: op.feedKg,
            baseFeed: op.baseFeed,
            createdAt: op.createdAt,
            operationId: op.operationId,
          );
          op.status = FeedOpStatus.synced;
          AppLogger.info('FeedSyncQueue: synced ${op.operationId}');
          changed = true;
        } catch (e) {
          op.attemptCount++;
          op.lastError = e.toString();
          if (op.attemptCount >= _maxAttempts) {
            op.status = FeedOpStatus.failed;
            AppLogger.error(
                'FeedSyncQueue: exhausted retries for ${op.operationId} '
                'after $_maxAttempts attempts: $e');
          } else {
            final delay = _backoffDelay(op.attemptCount);
            op.nextRetryAt = now.add(delay);
            AppLogger.warn(
                'FeedSyncQueue: attempt ${op.attemptCount} failed for '
                '${op.operationId}, retry in ${delay.inSeconds}s: $e');
          }
          changed = true;
        }
      }

      if (changed) {
        // Prune synced ops older than 24 h. Keep failed for audit.
        ops.removeWhere((o) =>
            o.status == FeedOpStatus.synced &&
            now.difference(o.queuedAt).inHours > 24);
        await _saveAll(prefs, ops);
      }
    } catch (e) {
      AppLogger.error('FeedSyncQueue.processQueue unexpected error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// How many operations are currently pending (not synced/failed).
  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final ops = await _loadAll(prefs);
    return ops.where((o) => o.status == FeedOpStatus.pending).length;
  }

  /// True if any operations exhausted all retries and need manual attention.
  Future<bool> hasPermanentlyFailedOps() async {
    final prefs = await SharedPreferences.getInstance();
    final ops = await _loadAll(prefs);
    return ops.any((o) => o.status == FeedOpStatus.failed);
  }

  /// Returns all operations for inspection (e.g., admin/debug screen).
  Future<List<FeedPendingOperation>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadAll(prefs);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Exponential backoff: base * 2^(attempt-1), capped, ±20% jitter.
  Duration _backoffDelay(int attempt) {
    final base = _baseDelaySeconds * pow(2, attempt - 1).toInt();
    final capped = base.clamp(1, _maxDelaySeconds);
    final jitterRange = (capped * 0.2).round();
    final jitter = jitterRange > 0
        ? _rng.nextInt(jitterRange * 2 + 1) - jitterRange
        : 0;
    return Duration(seconds: (capped + jitter).clamp(1, _maxDelaySeconds));
  }

  Future<List<FeedPendingOperation>> _loadAll(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_storageKey) ?? [];
    final result = <FeedPendingOperation>[];
    for (final s in raw) {
      try {
        result.add(FeedPendingOperation.fromJsonString(s));
      } catch (e) {
        AppLogger.error('FeedSyncQueue: corrupt entry skipped: $e');
      }
    }
    return result;
  }

  Future<void> _saveAll(
      SharedPreferences prefs, List<FeedPendingOperation> ops) async {
    await prefs.setStringList(
        _storageKey, ops.map((o) => o.toJsonString()).toList());
  }
}
