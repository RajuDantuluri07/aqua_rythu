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

  Future<void> logFeedGiven(String pondId, double amount) async {
    await _supabase.from('feed_logs').insert({
      'pond_id': pondId,
      'feed_given': amount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
