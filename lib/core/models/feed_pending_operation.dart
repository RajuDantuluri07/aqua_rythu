import 'dart:convert';

enum FeedOpStatus { pending, synced, failed }

/// A feed completion operation that has been queued for offline/retry sync.
///
/// The [operationId] is a client-generated UUID produced before the first DB
/// attempt. Retrying with the same operationId is always safe — the RPC
/// detects it and returns {operationDuplicate:true} without any writes.
class FeedPendingOperation {
  final String operationId;
  final String pondId;
  final int doc;
  final int round;
  final double feedKg;
  final double baseFeed;
  final DateTime createdAt;
  final DateTime queuedAt;

  int attemptCount;
  DateTime? nextRetryAt;
  FeedOpStatus status;
  String? lastError;

  FeedPendingOperation({
    required this.operationId,
    required this.pondId,
    required this.doc,
    required this.round,
    required this.feedKg,
    required this.baseFeed,
    required this.createdAt,
    required this.queuedAt,
    this.attemptCount = 0,
    this.nextRetryAt,
    this.status = FeedOpStatus.pending,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'pondId': pondId,
        'doc': doc,
        'round': round,
        'feedKg': feedKg,
        'baseFeed': baseFeed,
        'createdAt': createdAt.toIso8601String(),
        'queuedAt': queuedAt.toIso8601String(),
        'attemptCount': attemptCount,
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'status': status.name,
        'lastError': lastError,
      };

  factory FeedPendingOperation.fromJson(Map<String, dynamic> json) {
    return FeedPendingOperation(
      operationId: json['operationId'] as String,
      pondId: json['pondId'] as String,
      doc: (json['doc'] as num).toInt(),
      round: (json['round'] as num).toInt(),
      feedKg: (json['feedKg'] as num).toDouble(),
      baseFeed: (json['baseFeed'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.tryParse(json['nextRetryAt'] as String)
          : null,
      status: FeedOpStatus.values.byName(
          (json['status'] as String?) ?? FeedOpStatus.pending.name),
      lastError: json['lastError'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory FeedPendingOperation.fromJsonString(String raw) =>
      FeedPendingOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  String toString() =>
      'FeedPendingOp(id=$operationId pond=$pondId doc=$doc r=$round '
      '${feedKg.toStringAsFixed(2)}kg attempts=$attemptCount status=${status.name})';
}
