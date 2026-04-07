import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for feed data — Supabase queries only, no business logic.
class FeedRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getFeedRounds(String pondId, int doc) async {
    return await _supabase
        .from('feed_rounds')
        .select()
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round');
  }

  Future<double> getTotalFeed(String pondId) async {
    final rows = await _supabase
        .from('feed_logs')
        .select('feed_given')
        .eq('pond_id', pondId);

    return rows.fold<double>(
      0.0,
      (sum, row) => sum + ((row['feed_given'] as num?)?.toDouble() ?? 0.0),
    );
  }

  Future<void> updateNextDayFeed(String pondId, int doc, double amount) async {
    final rows = await _supabase
        .from('feed_rounds')
        .select('id, planned_amount, is_manual')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .eq('status', 'pending');

    for (final row in rows) {
      if (row['is_manual'] == true) continue;
      await _supabase
          .from('feed_rounds')
          .update({'planned_amount': double.parse(amount.toStringAsFixed(3))})
          .eq('id', row['id'] as String);
    }
  }

  /// Returns the base_feed rows for a DOC (id + base_feed per round).
  /// base_feed is the immutable original — used to prevent compounding.
  Future<List<Map<String, dynamic>>> getBaseFeedRows(String pondId, int doc) async {
    return await _supabase
        .from('feed_rounds')
        .select('id, base_feed, is_manual')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .eq('status', 'pending');
  }

  /// Returns the total planned feed (sum across all rounds) for a given DOC.
  /// Returns null if no rows exist for that DOC.
  Future<double?> getFeedByDoc(String pondId, int doc) async {
    final rows = await _supabase
        .from('feed_rounds')
        .select('planned_amount')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .eq('status', 'pending');

    if (rows.isEmpty) return null;

    return rows.fold<double>(
      0.0,
      (sum, row) => sum + ((row['planned_amount'] as num?)?.toDouble() ?? 0.0),
    );
  }

  /// Updates all non-manual pending rounds for a DOC by distributing [newFeed]
  /// proportionally across existing round amounts.
  Future<void> updateFeed({
    required String pondId,
    required int doc,
    required double newFeed,
    required bool isSmartAdjusted,
  }) async {
    final rows = await _supabase
        .from('feed_rounds')
        .select('id, planned_amount, is_manual')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .eq('status', 'pending');

    if (rows.isEmpty) return;

    // Only adjust non-manual rows
    final adjustable = rows.where((r) => r['is_manual'] != true).toList();
    if (adjustable.isEmpty) return;

    final currentTotal = adjustable.fold<double>(
      0.0,
      (sum, r) => sum + ((r['planned_amount'] as num?)?.toDouble() ?? 0.0),
    );

    if (currentTotal <= 0) return;

    final factor = newFeed / currentTotal;

    for (final row in adjustable) {
      final current = (row['planned_amount'] as num).toDouble();
      final updated = double.parse((current * factor).toStringAsFixed(3));
      await _supabase
          .from('feed_rounds')
          .update({'planned_amount': updated})
          .eq('id', row['id'] as String);
    }
  }

  /// Atomically sets planned_amount + is_smart_adjusted for ONE row.
  ///
  /// The WHERE clause includes `is_smart_adjusted = false` — PostgreSQL will
  /// only execute the update if the row has not been adjusted yet. If a
  /// concurrent call already set it to true, this returns false (0 rows
  /// affected) and the caller should treat it as a safe no-op.
  ///
  /// Returns true if the row was updated, false if a concurrent process
  /// already claimed it.
  Future<bool> atomicUpdateRound({
    required String rowId,
    required double newPlannedAmount,
    required String adjustmentReason,
  }) async {
    final updated = await _supabase
        .from('feed_rounds')
        .update({
          'planned_amount': newPlannedAmount,
          'is_smart_adjusted': true,
          'adjustment_reason': adjustmentReason,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rowId)
        .eq('is_smart_adjusted', false) // atomic guard — only succeeds once
        .select();

    return updated.isNotEmpty;
  }

  Future<void> logFeedGiven(String pondId, double amount) async {
    await _supabase.from('feed_logs').insert({
      'pond_id': pondId,
      'feed_given': amount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
