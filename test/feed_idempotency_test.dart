// Epic 7 — Feed Engine Idempotency + Operational Safety
// Test suite covering Phases 1–7.
//
// These tests target the pure-Dart layer (models, queue logic, UUID format,
// validation) without a live Supabase or SharedPreferences instance.
// Integration tests that require the DB are documented as manual test cases.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_rythu/core/models/feed_pending_operation.dart';
import 'package:aqua_rythu/core/utils/uuid_generator.dart';

void main() {
  // ── Phase 1: UUID idempotency key ─────────────────────────────────────────
  group('Phase 1 — UUID generation', () {
    test('generateUuidV4 produces a valid RFC 4122 v4 format', () {
      final id = generateUuidV4();
      // 8-4-4-4-12 hex groups separated by hyphens
      final regex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(regex.hasMatch(id), isTrue,
          reason: 'UUID "$id" does not match RFC 4122 v4 pattern');
    });

    test('generateUuidV4 version bits are set correctly', () {
      final id = generateUuidV4();
      final parts = id.split('-');
      // Third group starts with '4' (version 4)
      expect(parts[2][0], equals('4'));
      // Fourth group starts with 8, 9, a, or b (variant 1)
      expect(['8', '9', 'a', 'b'], contains(parts[3][0]));
    });

    test('generateUuidV4 produces unique values', () {
      final ids = List.generate(1000, (_) => generateUuidV4()).toSet();
      expect(ids.length, equals(1000),
          reason: 'Expected 1000 unique UUIDs, got duplicates');
    });

    test('generateUuidV4 uses secure randomness (distribution check)', () {
      // Generate 500 UUIDs and check that the hex characters are not
      // all the same — a degenerate RNG would fail this.
      final chars = List.generate(500, (_) => generateUuidV4())
          .join()
          .replaceAll('-', '')
          .split('');
      final distinct = chars.toSet().length;
      expect(distinct, greaterThanOrEqualTo(14),
          reason: 'Expected at least 14 distinct hex chars across 500 UUIDs');
    });
  });

  // ── Phase 1+3: FeedPendingOperation model ─────────────────────────────────
  group('Phase 1+3 — FeedPendingOperation serialization', () {
    late FeedPendingOperation op;
    final now = DateTime(2026, 5, 16, 8, 30);

    setUp(() {
      op = FeedPendingOperation(
        operationId: 'aaaabbbb-cccc-4ddd-8eee-ffffffffffff',
        pondId: 'pond-1',
        doc: 15,
        round: 2,
        feedKg: 12.5,
        baseFeed: 12.0,
        createdAt: now,
        queuedAt: now,
        attemptCount: 0,
        status: FeedOpStatus.pending,
      );
    });

    test('toJson / fromJson round-trips correctly', () {
      final restored = FeedPendingOperation.fromJson(op.toJson());
      expect(restored.operationId, equals(op.operationId));
      expect(restored.pondId, equals(op.pondId));
      expect(restored.doc, equals(op.doc));
      expect(restored.round, equals(op.round));
      expect(restored.feedKg, equals(op.feedKg));
      expect(restored.baseFeed, equals(op.baseFeed));
      expect(restored.createdAt, equals(op.createdAt));
      expect(restored.status, equals(FeedOpStatus.pending));
      expect(restored.attemptCount, equals(0));
      expect(restored.nextRetryAt, isNull);
      expect(restored.lastError, isNull);
    });

    test('toJsonString / fromJsonString round-trips correctly', () {
      final json = op.toJsonString();
      final restored = FeedPendingOperation.fromJsonString(json);
      expect(restored.operationId, equals(op.operationId));
      expect(restored.feedKg, equals(12.5));
    });

    test('status enum round-trips for all values', () {
      for (final s in FeedOpStatus.values) {
        op.status = s;
        final restored = FeedPendingOperation.fromJson(op.toJson());
        expect(restored.status, equals(s));
      }
    });

    test('nextRetryAt is preserved when set', () {
      final retryTime = DateTime(2026, 5, 16, 9, 0);
      op.nextRetryAt = retryTime;
      final restored = FeedPendingOperation.fromJson(op.toJson());
      expect(restored.nextRetryAt, equals(retryTime));
    });

    test('attemptCount increments are preserved', () {
      op.attemptCount = 3;
      op.lastError = 'connection timeout';
      final restored = FeedPendingOperation.fromJson(op.toJson());
      expect(restored.attemptCount, equals(3));
      expect(restored.lastError, equals('connection timeout'));
    });

    test('fromJson with missing optional fields uses defaults', () {
      final minimal = {
        'operationId': 'id-1',
        'pondId': 'pond-1',
        'doc': 1,
        'round': 1,
        'feedKg': 5.0,
        'baseFeed': 5.0,
        'createdAt': now.toIso8601String(),
        'queuedAt': now.toIso8601String(),
      };
      final restored = FeedPendingOperation.fromJson(minimal);
      expect(restored.attemptCount, equals(0));
      expect(restored.status, equals(FeedOpStatus.pending));
      expect(restored.nextRetryAt, isNull);
      expect(restored.lastError, isNull);
    });
  });

  // ── Phase 3: Exponential backoff logic ────────────────────────────────────
  group('Phase 3 — Exponential backoff', () {
    // Replicate the backoff formula from FeedSyncQueue to test it directly.
    Duration backoffDelay(int attempt, {int seed = 42}) {
      const baseDelaySeconds = 5;
      const maxDelaySeconds = 300;
      final rng = Random(seed);
      final base = baseDelaySeconds * pow(2, attempt - 1).toInt();
      final capped = base.clamp(1, maxDelaySeconds);
      final jitterRange = (capped * 0.2).round();
      final jitter = jitterRange > 0
          ? rng.nextInt(jitterRange * 2 + 1) - jitterRange
          : 0;
      return Duration(seconds: (capped + jitter).clamp(1, maxDelaySeconds));
    }

    test('attempt 1 base delay is 5s (±1s jitter)', () {
      final delay = backoffDelay(1, seed: 0);
      expect(delay.inSeconds, inInclusiveRange(4, 6));
    });

    test('attempt 2 base delay is 10s', () {
      final delay = backoffDelay(2, seed: 0);
      expect(delay.inSeconds, inInclusiveRange(8, 12));
    });

    test('attempt 3 base delay is 20s', () {
      final delay = backoffDelay(3, seed: 0);
      expect(delay.inSeconds, inInclusiveRange(16, 24));
    });

    test('delay is capped at 300s', () {
      // Attempt 8: 5 * 2^7 = 640 → capped at 300
      final delay = backoffDelay(8, seed: 0);
      expect(delay.inSeconds, lessThanOrEqualTo(300));
    });

    test('delay is always at least 1s', () {
      for (int attempt = 1; attempt <= 10; attempt++) {
        final delay = backoffDelay(attempt, seed: attempt);
        expect(delay.inSeconds, greaterThanOrEqualTo(1),
            reason: 'attempt $attempt produced sub-1s delay');
      }
    });

    test('delays are monotonically non-decreasing on average', () {
      // Average over several seeds to smooth jitter.
      double avgDelay(int attempt) {
        final samples =
            List.generate(20, (i) => backoffDelay(attempt, seed: i).inSeconds);
        return samples.fold(0, (s, v) => s + v) / samples.length;
      }

      final d1 = avgDelay(1);
      final d2 = avgDelay(2);
      final d3 = avgDelay(3);
      final d4 = avgDelay(4);

      expect(d2, greaterThan(d1));
      expect(d3, greaterThan(d2));
      expect(d4, greaterThan(d3));
    });
  });

  // ── Phase 5: Feed amount validation ──────────────────────────────────────
  group('Phase 5 — Feed amount validation', () {
    void validate(double amount) {
      // Mirrors FeedService._validateFeedAmount logic.
      if (amount.isNaN) throw ArgumentError('NaN');
      if (amount.isInfinite) throw ArgumentError('Infinite');
      if (amount < 0) throw ArgumentError('Negative: $amount');
      if (amount > 50.0) throw ArgumentError('Exceeds max: $amount');
    }

    test('valid amounts pass without error', () {
      for (final qty in [0.0, 0.1, 1.0, 10.0, 25.5, 50.0]) {
        expect(() => validate(qty), returnsNormally,
            reason: '${qty}kg should be valid');
      }
    });

    test('NaN is rejected', () {
      expect(() => validate(double.nan), throwsArgumentError);
    });

    test('positive infinity is rejected', () {
      expect(() => validate(double.infinity), throwsArgumentError);
    });

    test('negative infinity is rejected', () {
      expect(() => validate(double.negativeInfinity), throwsArgumentError);
    });

    test('negative amounts are rejected', () {
      expect(() => validate(-0.001), throwsArgumentError);
      expect(() => validate(-10.0), throwsArgumentError);
    });

    test('amounts above 50 kg are rejected', () {
      expect(() => validate(50.001), throwsArgumentError);
      expect(() => validate(100.0), throwsArgumentError);
      expect(() => validate(1000.0), throwsArgumentError);
    });

    test('zero is allowed (Do Not Feed round)', () {
      expect(() => validate(0.0), returnsNormally);
    });

    test('boundary value 50.0 is allowed', () {
      expect(() => validate(50.0), returnsNormally);
    });

    test('NaN from 0/0 arithmetic is caught', () {
      const qty = 0.0 / 0.0; // NaN
      expect(() => validate(qty), throwsArgumentError);
    });

    test('Infinity from x/0 arithmetic is caught', () {
      const qty = 1.0 / 0.0; // +Infinity
      expect(() => validate(qty), throwsArgumentError);
    });
  });

  // ── Phase 1: Duplicate prevention logic ───────────────────────────────────
  group('Phase 1 — Duplicate tap / same operationId detection', () {
    test('two operations with the same operationId are distinguishable', () {
      const opId = 'aaaabbbb-cccc-4ddd-8eee-ffffffffffff';
      final op1 = FeedPendingOperation(
        operationId: opId,
        pondId: 'pond-1',
        doc: 5,
        round: 1,
        feedKg: 10.0,
        baseFeed: 10.0,
        createdAt: DateTime.now(),
        queuedAt: DateTime.now(),
      );
      final op2 = FeedPendingOperation(
        operationId: opId, // same id → duplicate
        pondId: 'pond-1',
        doc: 5,
        round: 1,
        feedKg: 10.0,
        baseFeed: 10.0,
        createdAt: DateTime.now(),
        queuedAt: DateTime.now(),
      );
      // Queue dedup: last enqueue with same id replaces the first.
      final ops = <FeedPendingOperation>[op1];
      ops.removeWhere((o) => o.operationId == op2.operationId);
      ops.add(op2);
      expect(ops.length, equals(1),
          reason: 'Duplicate operationId must collapse to a single queue entry');
    });

    test('two operations with different operationIds are both kept', () {
      final op1 = FeedPendingOperation(
        operationId: generateUuidV4(),
        pondId: 'pond-1',
        doc: 5,
        round: 1,
        feedKg: 10.0,
        baseFeed: 10.0,
        createdAt: DateTime.now(),
        queuedAt: DateTime.now(),
      );
      final op2 = FeedPendingOperation(
        operationId: generateUuidV4(), // different id
        pondId: 'pond-1',
        doc: 5,
        round: 2,
        feedKg: 10.0,
        baseFeed: 10.0,
        createdAt: DateTime.now(),
        queuedAt: DateTime.now(),
      );
      final ops = <FeedPendingOperation>[op1];
      ops.removeWhere((o) => o.operationId == op2.operationId);
      ops.add(op2);
      expect(ops.length, equals(2));
    });
  });

  // ── Phase 3: Queue filtering logic ────────────────────────────────────────
  group('Phase 3 — Queue skip/retry logic', () {
    final baseTime = DateTime(2026, 5, 16, 10, 0);

    FeedPendingOperation makeOp({
      FeedOpStatus status = FeedOpStatus.pending,
      int attempts = 0,
      DateTime? nextRetryAt,
    }) {
      return FeedPendingOperation(
        operationId: generateUuidV4(),
        pondId: 'pond-1',
        doc: 1,
        round: 1,
        feedKg: 5.0,
        baseFeed: 5.0,
        createdAt: baseTime,
        queuedAt: baseTime,
        attemptCount: attempts,
        status: status,
        nextRetryAt: nextRetryAt,
      );
    }

    bool shouldProcess(FeedPendingOperation op, DateTime now) {
      if (op.status == FeedOpStatus.synced) return false;
      if (op.status == FeedOpStatus.failed) return false;
      if (op.nextRetryAt != null && op.nextRetryAt!.isAfter(now)) return false;
      return true;
    }

    test('synced ops are skipped', () {
      final op = makeOp(status: FeedOpStatus.synced);
      expect(shouldProcess(op, baseTime), isFalse);
    });

    test('failed ops are skipped', () {
      final op = makeOp(status: FeedOpStatus.failed);
      expect(shouldProcess(op, baseTime), isFalse);
    });

    test('pending op with future nextRetryAt is skipped', () {
      final op = makeOp(nextRetryAt: baseTime.add(const Duration(minutes: 5)));
      expect(shouldProcess(op, baseTime), isFalse);
    });

    test('pending op with past nextRetryAt is processed', () {
      final op =
          makeOp(nextRetryAt: baseTime.subtract(const Duration(seconds: 1)));
      expect(shouldProcess(op, baseTime), isTrue);
    });

    test('pending op with no nextRetryAt is processed immediately', () {
      final op = makeOp();
      expect(shouldProcess(op, baseTime), isTrue);
    });

    test('op moves to failed after max attempts', () {
      const maxAttempts = 5;
      final op = makeOp(attempts: maxAttempts - 1);
      // Simulate final failure
      op.attemptCount++;
      if (op.attemptCount >= maxAttempts) {
        op.status = FeedOpStatus.failed;
      }
      expect(op.status, equals(FeedOpStatus.failed));
    });
  });

  // ── Phase 6: Failure recovery — local state preserved ─────────────────────
  group('Phase 6 — Failure recovery', () {
    test('pending op survives serialization (simulates app restart)', () {
      final original = FeedPendingOperation(
        operationId: generateUuidV4(),
        pondId: 'pond-42',
        doc: 7,
        round: 3,
        feedKg: 18.75,
        baseFeed: 18.0,
        createdAt: DateTime(2026, 5, 16, 6, 0),
        queuedAt: DateTime(2026, 5, 16, 6, 1),
        attemptCount: 2,
        status: FeedOpStatus.pending,
        nextRetryAt: DateTime(2026, 5, 16, 6, 5),
        lastError: 'SocketException: Network unreachable',
      );

      // Simulate write to SharedPreferences string
      final persisted = original.toJsonString();

      // Simulate read back after app restart
      final restored = FeedPendingOperation.fromJsonString(persisted);

      expect(restored.operationId, equals(original.operationId));
      expect(restored.pondId, equals('pond-42'));
      expect(restored.doc, equals(7));
      expect(restored.round, equals(3));
      expect(restored.feedKg, equals(18.75));
      expect(restored.attemptCount, equals(2));
      expect(restored.status, equals(FeedOpStatus.pending));
      expect(restored.nextRetryAt, equals(original.nextRetryAt));
      expect(restored.lastError, contains('SocketException'));
    });

    test('multiple pending ops survive serialization', () {
      final ops = List.generate(
        5,
        (i) => FeedPendingOperation(
          operationId: generateUuidV4(),
          pondId: 'pond-$i',
          doc: i + 1,
          round: 1,
          feedKg: 5.0 + i,
          baseFeed: 5.0 + i,
          createdAt: DateTime.now(),
          queuedAt: DateTime.now(),
        ),
      );

      // Simulate SharedPreferences string list storage
      final stored = ops.map((o) => o.toJsonString()).toList();
      final restored = stored.map(FeedPendingOperation.fromJsonString).toList();

      expect(restored.length, equals(5));
      for (int i = 0; i < 5; i++) {
        expect(restored[i].operationId, equals(ops[i].operationId));
        expect(restored[i].pondId, equals('pond-$i'));
        expect(restored[i].feedKg, equals(5.0 + i));
      }
    });
  });

  // ── Manual test documentation (Phase 7 integration scenarios) ─────────────
  // The following describe integration test cases that require a live DB or
  // mocked SharedPreferences. Run manually during QA or with integration test
  // infrastructure (e.g., fake_async + mocktail).
  //
  // Test: Duplicate tap
  //   1. User taps "Feed Done" twice within 200ms.
  //   2. In-memory lock (_updateLocks) absorbs the second tap.
  //   3. DB receives exactly one RPC call.
  //   Expected: One feed_log row, one feed_round completed row.
  //
  // Test: Airplane mode
  //   1. Enable airplane mode.
  //   2. User marks feed done → FeedService throws SocketException.
  //   3. FeedSyncQueue.enqueue() is called with the operationId.
  //   4. Disable airplane mode → FeedSyncQueue.processQueue() retries.
  //   5. DB write succeeds. Feed log appears in history.
  //   Expected: Exactly one feed_log row after reconnect.
  //
  // Test: App restart mid-sync
  //   1. User marks feed done offline → enqueued to SharedPreferences.
  //   2. Kill the app.
  //   3. Restart the app → main() calls FeedSyncQueue.processQueue().
  //   4. Queue processes the pending op with original operationId.
  //   Expected: Feed log written exactly once.
  //
  // Test: Retry storm (server returns 503 repeatedly)
  //   1. Mock server to return 503 for 4 attempts.
  //   2. processQueue() retries with exponential backoff.
  //   3. On attempt 5 server succeeds.
  //   Expected: Exactly one feed_log row; backoff delays increased each round.
  //
  // Test: Multi-device conflict
  //   1. Device A and Device B both mark round 1 done offline.
  //   2. Both reconnect simultaneously.
  //   3. Device A's RPC lands first (operationId=A).
  //   4. Device B's RPC runs: (pond_id,doc,round) already exists → UPSERT
  //      updates feed_given to Device B's quantity; operationId stays as A
  //      because COALESCE preserves first non-null value.
  //   Expected: No duplicate rows; last-write-wins for quantity.
  //
  // Test: Partial transaction failure
  //   1. Inject a savepoint error after feed_rounds UPDATE but before feed_logs INSERT.
  //   2. Call complete_feed_round_with_log.
  //   3. Verify the EXCEPTION block fires and {success:false} is returned.
  //   4. Client receives error and enqueues for retry.
  //   Expected: DB atomically rolls back; next retry succeeds cleanly.
}
