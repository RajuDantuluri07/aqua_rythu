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

  /// Fetch all logged feed entries for a pond, oldest first
  Future<List<Map<String, dynamic>>> fetchFeedLogs(String pondId) async {
    return await supabase
        .from('feed_logs')
        .select('feed_given, created_at')
        .eq('pond_id', pondId)
        .order('created_at', ascending: true);
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

  /// Save feed schedule — always upserts exactly 4 rows per DOC.
  /// Never deletes rows; qty=0 means inactive (no card shown on dashboard).
  Future<void> saveFeedPlans(String pondId, List<dynamic> feedPlans) async {
    if (pondId.isEmpty) throw Exception('Invalid pondId');

    try {
      for (final plan in feedPlans) {
        final doc = plan.doc is int ? plan.doc as int : plan['doc'] as int;
        final List<double> rounds = plan.rounds is List
            ? List<double>.from((plan.rounds as List).map((v) => (v as num).toDouble()))
            : [
                (plan['r1'] as num?)?.toDouble() ?? 0.0,
                (plan['r2'] as num?)?.toDouble() ?? 0.0,
                (plan['r3'] as num?)?.toDouble() ?? 0.0,
                (plan['r4'] as num?)?.toDouble() ?? 0.0,
              ];

        // Ensure exactly 4 rounds
        final paddedRounds = List<double>.generate(4, (i) => i < rounds.length ? rounds[i] : 0.0);

        // Fetch existing row IDs for this doc (to update vs insert)
        final existing = await supabase
            .from('feed_rounds')
            .select('id, round')
            .eq('pond_id', pondId)
            .eq('doc', doc)
            .order('round');

        final Map<int, String> existingIds = {
          for (final row in existing) (row['round'] as int): row['id'] as String
        };

        for (int i = 0; i < 4; i++) {
          final round = i + 1;
          final qty = paddedRounds[i];
          final existingId = existingIds[round];

          if (existingId != null) {
            await supabase.from('feed_rounds').update({
              'planned_amount': qty,
              'base_feed': qty,
              'is_manual': true,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', existingId);
          } else {
            await supabase.from('feed_rounds').insert({
              'pond_id': pondId,
              'doc': doc,
              'round': round,
              'planned_amount': qty,
              'base_feed': qty,
              'status': 'pending',
              'is_manual': true,
            });
          }
        }
      }

      AppLogger.info("Feed plans saved for pond $pondId (${feedPlans.length} DOCs × 4 rounds)");
    } catch (e) {
      throw Exception('Failed to save feed plans: $e');
    }
  }
}