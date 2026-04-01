import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_plan_constants.dart';

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
  required DateTime stockingDate,
}) async {
  // 🎯 FIX: Limit feed plan generation to blind feeding phase (DOC 1-30)
  // DOC > 30 will be handled by the Smart Feeding Engine based on sampling.
  final int effectiveEndDoc = endDoc > 30 ? 30 : endDoc;

  // Early exit for ponds already past the blind feeding phase
  if (startDoc > 30) {
    print('FeedPlanGenerator: Pond $pondId is at DOC $startDoc. Skipping blind feed plan.');
    return;
  }

  // Edge Case: If any part of this range already exists -> DO NOT duplicate
  final List<dynamic> existing = await supabase
      .from('feed_plans')
      .select('id')
      .eq('pond_id', pondId)
      .gte('doc', startDoc)
      .lte('doc', effectiveEndDoc)
      .limit(1);

  if (existing.isNotEmpty) return;

  // 1. Fetch base feed rates from Supabase for the blind feeding range (max 30).
  final List<dynamic> baseRatesData = await supabase
      .from('feed_base_rates')
      .select('doc, base_feed_amount')
      .gte('doc', startDoc)
      .lte('doc', 30);

  // 2. Convert the list to a temporary map for O(1) lookup inside the loop.
  final Map<int, double> remoteBaseFeedPlan = {
    for (var item in baseRatesData)
      item['doc'] as int: (item['base_feed_amount'] as num).toDouble()
  };

  // 🎯 FIX 1: Add Total Feed Normalization
  double rawTotal = 0;
  for (int doc = startDoc; doc <= effectiveEndDoc; doc++) {
    double? baseFeed = remoteBaseFeedPlan[doc];
    if (baseFeed != null) {
      rawTotal += baseFeed;
    }
  }

  // Normalize against baseline target (235kg for 100K PL / 1 Acre)
  final normalizationFactor = rawTotal > 0 ? 235.0 / rawTotal : 1.0;

  final List<Map<String, dynamic>> batchData = [];
  final scaleFactor = (stockingCount / 100000) * (pondArea / 1.0);

  for (int doc = startDoc; doc <= effectiveEndDoc; doc++) {
    double? baseFeed = remoteBaseFeedPlan[doc];

    // ✅ FIX 2: Safety Guard - Throw exception if base feed missing within blind phase
    if (baseFeed == null) {
      throw Exception('Base feed missing for DOC $doc (Blind Feeding Phase)');
    }

    final totalFeed = baseFeed * normalizationFactor * scaleFactor;
    final feedType = getFeedType(doc);

    for (int round = 1; round <= 4; round++) {
      batchData.add({
        'pond_id': pondId,
        'doc': doc,
        'date': stockingDate.add(Duration(days: doc - 1)).toIso8601String().split('T')[0],
        'round': round,
        'feed_amount': totalFeed * roundDistribution[round]!,
        'feed_type': feedType,
        'is_manual': false,
        'is_completed': false,
      });
    }
  }

  if (batchData.isNotEmpty) {
    await supabase.from('feed_plans').insert(batchData);
  }
}