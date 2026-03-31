import 'package:supabase_flutter/supabase_flutter.dart';

class FeedService {
  final supabase = Supabase.instance.client;

  Future<void> saveFeed({
    required String pondId,
    required DateTime date,
    required int doc,
    required List<double> rounds,
    required double expectedFeed,
    required double cumulativeFeed,
  }) async {
    await supabase.from('feed_history_logs').insert({
      'pond_id': pondId,
      'date': date.toIso8601String(),
      'doc': doc,
      'rounds': rounds,
      'expected_feed': expectedFeed,
      'cumulative_feed': cumulativeFeed,
    });
  }
}