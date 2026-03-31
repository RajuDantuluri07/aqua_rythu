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

  /// Fetch all feed plans for a pond
  Future<List<Map<String, dynamic>>> getFeedPlans(String pondId) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }
    
    try {
      return await supabase
          .from('feed_plans')
          .select()
          .eq('pond_id', pondId)
          .order('doc', ascending: true)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plans: $e');
    }
  }

  /// Fetch feed plan for a specific DOC
  Future<List<Map<String, dynamic>>> getFeedPlanForDoc({
    required String pondId,
    required int doc,
  }) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }

    try {
      return await supabase
          .from('feed_plans')
          .select()
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plan for DOC $doc: $e');
    }
  }

  /// Fetch feed plans for a specific date range
  Future<List<Map<String, dynamic>>> getFeedPlansByDateRange({
    required String pondId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }

    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];

    try {
      return await supabase
          .from('feed_plans')
          .select()
          .eq('pond_id', pondId)
          .gte('date', startDateStr)
          .lte('date', endDateStr)
          .order('date', ascending: true)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plans for date range: $e');
    }
  }

  /// Mark a feed plan as completed
  Future<void> markFeedPlanCompleted({
    required String feedPlanId,
  }) async {
    if (feedPlanId.isEmpty) {
      throw Exception('Invalid feedPlanId');
    }

    try {
      await supabase
          .from('feed_plans')
          .update({
            'is_completed': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', feedPlanId);
    } catch (e) {
      throw Exception('Failed to mark feed plan as completed: $e');
    }
  }

  /// Manually override a feed plan amount
  Future<void> overrideFeedAmount({
    required String feedPlanId,
    required double newAmount,
  }) async {
    if (feedPlanId.isEmpty) {
      throw Exception('Invalid feedPlanId');
    }

    try {
      await supabase
          .from('feed_plans')
          .update({
            'feed_amount': newAmount,
            'is_manual': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', feedPlanId);
    } catch (e) {
      throw Exception('Failed to override feed amount: $e');
    }
  }
}