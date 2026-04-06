import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';

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
    // feed_logs table: pond_id, feed_given, created_at
    // Store total feed given; tray columns are optional
    final total = rounds.fold(0.0, (sum, r) => sum + r);
    await supabase.from('feed_logs').insert({
      'pond_id': pondId,
      'feed_given': total,
      'created_at': date.toIso8601String(),
    });
  }

  /// Fetch all feed plans for a pond
  Future<List<Map<String, dynamic>>> getFeedPlans(String pondId) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }
    
    try {
      return await supabase
          .from('feed_rounds')
          .select('doc, round, planned_amount, status')
          .eq('pond_id', pondId)
          .order('doc', ascending: true)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plans: $e');
    }
  }

  /// Fetch feed rounds for specific pond and DOC
  Future<List<dynamic>> getFeedRounds(String pondId, int doc) async {
    final res = await supabase
        .from('feed_rounds')
        .select()
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round');

    AppLogger.debug("Fetched ${res.length} feed rounds for pond $pondId");

    return res;
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
          .from('feed_rounds')
          .select()
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plan for DOC $doc: $e');
    }
  }

  /// Fetch feed plans for a specific DOC range
  Future<List<Map<String, dynamic>>> getFeedPlansByDateRange({
    required String pondId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }

    // Derive DOC range from the pond's stocking date via a broader query
    // then filter client-side — feed_rounds uses doc not date
    try {
      return await supabase
          .from('feed_rounds')
          .select()
          .eq('pond_id', pondId)
          .order('doc', ascending: true)
          .order('round', ascending: true);
    } catch (e) {
      throw Exception('Failed to fetch feed plans: $e');
    }
  }

  /// Insert a single feed_rounds row and return its new id.
  /// Used for DOC > 30 rounds that have no pre-generated plan.
  Future<String> insertFeedRound({
    required String pondId,
    required int doc,
    required int round,
    required double plannedAmount,
    String status = 'completed',
  }) async {
    final response = await supabase
        .from('feed_rounds')
        .insert({
          'pond_id': pondId,
          'doc': doc,
          'round': round,
          'planned_amount': plannedAmount,
          'status': status,
          'is_manual': true,
        })
        .select('id')
        .single();
    return response['id'] as String;
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
          .from('feed_rounds')
          .update({'status': 'completed'})
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
          .from('feed_rounds')
          .update({
            'planned_amount': newAmount,
            'is_manual': true,
          })
          .eq('id', feedPlanId);
    } catch (e) {
      throw Exception('Failed to override feed amount: $e');
    }
  }

  /// Save bulk feed plans for a pond (replaces existing plans)
  Future<void> saveFeedPlans(String pondId, List<dynamic> feedPlans) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }

    try {
      // Delete existing feed plans for this pond (only for blind feeding DOC 1-30)
      await supabase
          .from('feed_rounds')
          .delete()
          .eq('pond_id', pondId)
          .lte('doc', 30);

      // Insert new feed plans
      final List<Map<String, dynamic>> plansToInsert = [];
      
      for (final plan in feedPlans) {
        // Handle both FeedDayPlan objects and JSON maps
        final doc = plan.doc is int ? plan.doc as int : plan['doc'] as int;
        final rounds = plan.rounds is List ? 
            plan.rounds as List<double> : 
            [
              (plan['r1'] as num?)?.toDouble() ?? 0.0,
              (plan['r2'] as num?)?.toDouble() ?? 0.0,
              (plan['r3'] as num?)?.toDouble() ?? 0.0,
              (plan['r4'] as num?)?.toDouble() ?? 0.0,
            ];
        
        for (int round = 0; round < rounds.length; round++) {
          plansToInsert.add({
            'pond_id': pondId,
            'doc': doc,
            'round': round + 1,
            'planned_amount': rounds[round],
            'status': 'pending',
            'is_manual': true, // Flag as user-defined override
          });
        }
      }

      if (plansToInsert.isNotEmpty) {
        await supabase
            .from('feed_rounds')
            .insert(plansToInsert);
      }

      AppLogger.info("Feed plans saved for pond $pondId (${plansToInsert.length} records)");
    } catch (e) {
      throw Exception('Failed to save feed plans: $e');
    }
  }
}