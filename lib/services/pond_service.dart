import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_rythu/core/engines/feed_calculation_engine.dart';

class PondService {
  final supabase = Supabase.instance.client;

  Future<void> createPond({
    required String farmId,
    required String name,
    required double area,
    required DateTime stockingDate,
    required int seedCount,
    required int plSize,
    int numTrays = 4,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // Create the pond
    final pondResponse = await supabase.from('ponds').insert({
      'farm_id': farmId,
      'name': name,
      'area': area,
      'stocking_date': stockingDate.toIso8601String(),
      'seed_count': seedCount,
      'pl_size': plSize,
      'num_trays': numTrays,
    }).select().single();

    final pondId = pondResponse['id'].toString();

    // Generate 120-day feed plan
    await _generateFeedPlan(
      pondId: pondId,
      seedCount: seedCount,
      stockingDate: stockingDate,
      numTrays: numTrays,
    );
  }

  Future<List<Map<String, dynamic>>> getPonds(String farmId) async {
    // Get today's date in YYYY-MM-DD format to filter nested feed plans
    final today = DateTime.now().toIso8601String().split('T')[0];

    return await supabase
        .from('ponds')
        .select('*, feed_plans(*)')
        .eq('farm_id', farmId)
        .eq('feed_plans.date', today)
        .order('round', referencedTable: 'feed_plans');
  }

  Future<void> _generateFeedPlan({
    required String pondId,
    required int seedCount,
    required DateTime stockingDate,
    required int numTrays,
  }) async {
    // Validation
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId: cannot be empty');
    }

    final feedPlanRecords = <Map<String, dynamic>>[];

    // Generate 120 days of feed plans with 4 rounds per day
    for (int doc = 1; doc <= 120; doc++) {
      final totalFeed = FeedCalculationEngine.calculateFeed(
        seedCount: seedCount,
        doc: doc,
      );

      // Distribute feed across rounds (typically 4 rounds per day)
      final rounds = FeedCalculationEngine.distributeFeed(totalFeed, 4);

      // Calculate the date for this DOC
      final planDate = stockingDate.add(Duration(days: doc - 1));

      // Create individual records for each round
      for (int roundNum = 1; roundNum <= 4; roundNum++) {
        final feedAmount = roundNum <= rounds.length ? rounds[roundNum - 1] : 0.0;

        feedPlanRecords.add({
          'pond_id': pondId,
          'doc': doc,
          'date': planDate.toIso8601String().split('T')[0], // Date only (YYYY-MM-DD)
          'round': roundNum,
          'feed_amount': feedAmount,
          'feed_type': 'standard',
          'is_manual': false,
          'is_completed': false,
        });
      }
    }

    // Insert all feed plans at once (480 total: 120 days × 4 rounds)
    if (feedPlanRecords.isNotEmpty) {
      try {
        await supabase.from('feed_plans').insert(feedPlanRecords);
      } catch (e) {
        throw Exception('Failed to generate feed plans: $e');
      }
    }
  }
}