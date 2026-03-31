import 'package:supabase_flutter/supabase_flutter.dart';
import '../feed_plan_constants.dart';

// Assuming supabase client is accessible via instance
final supabase = Supabase.instance.client;

/// Generates a feeding schedule for a specific range of days (e.g., 1–30, 31–60).
///
/// Creates 4 rounds per day for each day in the range.
Future<void> generateFeedPlan({
  required String pondId,
  required int startDoc,
  required int endDoc,
  required int stockingCount,
  required double pondArea,
}) async {
  // Edge Case: If the start of this range already exists -> DO NOT duplicate
  final existing = await supabase
      .from('feed_schedule')
      .select('id')
      .eq('pond_id', pondId)
      .eq('doc', startDoc)
      .limit(1)
      .maybeSingle();

  if (existing != null) return;

  // 1. Fetch base feed rates from Supabase for the target range.
  final List<dynamic> baseRatesData = await supabase
      .from('feed_base_rates')
      .select('doc, base_feed_amount')
      .gte('doc', startDoc)
      .lte('doc', endDoc);

  // 2. Convert the list to a temporary map for O(1) lookup inside the loop.
  final Map<int, double> remoteBaseFeedPlan = {
    for (var item in baseRatesData)
      item['doc'] as int: (item['base_feed_amount'] as num).toDouble()
  };

  final List<Map<String, dynamic>> batchData = [];
  final scaleFactor = (stockingCount / 100000) * (pondArea / 1.0);

  for (int doc = startDoc; doc <= endDoc; doc++) {
    final baseFeed = remoteBaseFeedPlan[doc];

    // Edge Case: If baseFeed missing -> log error
    if (baseFeed == null) {
      print('FeedPlanGenerator ERROR: Base feed missing for DOC $doc');
      continue;
    }

    final totalFeed = baseFeed * scaleFactor;
    final feedType = getFeedType(doc);

    for (int round = 1; round <= 4; round++) {
      batchData.add({
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'scheduled_time': roundTimings[round],
        'planned_feed_kg': totalFeed * roundDistribution[round]!,
        'feed_type': feedType,
        'status': 'pending',
        'is_blind': doc <= 30,
      });
    }
  }

  if (batchData.isNotEmpty) {
    await supabase.from('feed_schedule').insert(batchData);
  }
}