import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_plan_constants.dart';
import 'engine_constants.dart';
import '../utils/logger.dart';

final supabase = Supabase.instance.client;

/// Generates a feeding schedule for a range of DOCs (1–120).
///
/// DOC ≤ 30 → blind feeding using DB base rates + normalization.
/// DOC > 30 → biomass-based smart feeding using FeedEngineConstants.
///
/// Safe to call anytime — skips ranges that already have rows.
Future<void> generateFeedPlan({
  required String pondId,
  required int startDoc,
  required int endDoc,
  required int stockingCount,
  required double pondArea,
  required DateTime stockingDate,
}) async {
  if (startDoc > endDoc) return;
  final clampedEnd = endDoc.clamp(startDoc, 120);

  AppLogger.info('Generating feed plan: pond $pondId DOC $startDoc–$clampedEnd');

  // Skip if rows already exist anywhere in this range
  final existing = await supabase
      .from('feed_rounds')
      .select('id')
      .eq('pond_id', pondId)
      .gte('doc', startDoc)
      .lte('doc', clampedEnd)
      .limit(1);

  if (existing.isNotEmpty) {
    AppLogger.debug('Feed rows already exist for $pondId DOC $startDoc–$clampedEnd — skip');
    return;
  }

  final batch = <Map<String, dynamic>>[];

  // ── BLIND FEEDING (DOC 1–30) ────────────────────────────────────────────
  if (startDoc <= 30) {
    final blindEnd = clampedEnd.clamp(startDoc, 30);
    await _addBlindFeedRows(
      batch: batch,
      pondId: pondId,
      startDoc: startDoc,
      endDoc: blindEnd,
      stockingCount: stockingCount,
      pondArea: pondArea,
    );
  }

  // ── SMART FEEDING (DOC 31–120) ──────────────────────────────────────────
  if (clampedEnd > 30) {
    final smartStart = startDoc > 30 ? startDoc : 31;
    _addSmartFeedRows(
      batch: batch,
      pondId: pondId,
      startDoc: smartStart,
      endDoc: clampedEnd,
      stockingCount: stockingCount,
    );
  }

  if (batch.isNotEmpty) {
    try {
      await supabase.from('feed_rounds').insert(batch);
      AppLogger.info('Inserted ${batch.length} feed rounds for pond $pondId (DOC $startDoc–$clampedEnd)');
    } catch (e) {
      AppLogger.error('Feed plan insert failed for pond $pondId', e);
    }
  }
}

// ── BLIND FEED ROWS (DOC ≤ 30) ──────────────────────────────────────────────

Future<void> _addBlindFeedRows({
  required List<Map<String, dynamic>> batch,
  required String pondId,
  required int startDoc,
  required int endDoc,
  required int stockingCount,
  required double pondArea,
}) async {
  final baseRatesData = await supabase
      .from('feed_base_rates')
      .select('doc, base_feed_amount')
      .gte('doc', startDoc)
      .lte('doc', 30);

  AppLogger.debug('Base rates loaded: ${baseRatesData.length} entries for pond $pondId');

  final remoteRates = <int, double>{
    for (final item in baseRatesData)
      item['doc'] as int: (item['base_feed_amount'] as num).toDouble()
  };

  // Normalize to 235 kg baseline for 100K PL / 1 Acre over the full blind phase
  double rawTotal = 0;
  for (int doc = startDoc; doc <= endDoc; doc++) {
    rawTotal += remoteRates[doc] ?? (2.0 + doc * 0.1);
  }
  final normFactor = rawTotal > 0 ? 235.0 / rawTotal : 1.0;
  final scaleFactor = (stockingCount / 100000) * (pondArea / 1.0);

  for (int doc = startDoc; doc <= endDoc; doc++) {
    final baseFeed = remoteRates[doc] ?? (2.0 + doc * 0.1);
    final totalFeed = baseFeed * normFactor * scaleFactor;
    final feedType = getFeedType(doc);

    for (int round = 1; round <= 4; round++) {
      final roundFeed = totalFeed * roundDistribution[round]!;
      batch.add({
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'planned_amount': roundFeed,
        'base_feed': roundFeed, // immutable original — always use this for adjustments
        'feed_type': feedType,
        'status': 'pending',
      });
    }
  }
}

// ── SMART FEED ROWS (DOC > 30) ───────────────────────────────────────────────

void _addSmartFeedRows({
  required List<Map<String, dynamic>> batch,
  required String pondId,
  required int startDoc,
  required int endDoc,
  required int stockingCount,
}) {
  for (int doc = startDoc; doc <= endDoc; doc++) {
    final totalFeed = _biomassFeedKg(doc, stockingCount);

    for (int round = 1; round <= 4; round++) {
      final roundFeed = totalFeed * roundDistribution[round]!;
      batch.add({
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'planned_amount': roundFeed,
        'base_feed': roundFeed, // immutable original — always use this for adjustments
        'feed_type': 'Smart',
        'status': 'pending',
      });
    }
  }
}

/// Biomass-based daily feed in kg for a given DOC and stocking count.
double _biomassFeedKg(int doc, int stockingCount) {
  final survival = _interpolate(FeedEngineConstants.survivalRates, doc);
  final abwGrams = _interpolate(FeedEngineConstants.abwTargets, doc);
  final feedingRate = _interpolate(FeedEngineConstants.feedingRates, doc);
  final biomassKg = stockingCount * survival * abwGrams / 1000;
  return biomassKg * feedingRate;
}

// ── ROLLING RECOVERY ─────────────────────────────────────────────────────────

/// Checks if tomorrow's feed rows exist. If not, generates the next 7 DOCs.
/// Call this on dashboard load and after tray/feed events.
Future<void> ensureFutureFeedExists(String pondId, int currentDoc) async {
  try {
    final tomorrow = currentDoc + 1;
    if (tomorrow > 120) return;

    final existing = await supabase
        .from('feed_rounds')
        .select('id')
        .eq('pond_id', pondId)
        .eq('doc', tomorrow)
        .limit(1);

    if (existing.isNotEmpty) return; // Already covered

    // Fetch pond details needed for generation
    final pond = await supabase
        .from('ponds')
        .select('seed_count, stocking_date, area')
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      AppLogger.error('ensureFutureFeedExists: pond $pondId not found in DB');
      return;
    }

    final lookAheadEnd = (currentDoc + 7).clamp(tomorrow, 120);

    await generateFeedPlan(
      pondId: pondId,
      startDoc: tomorrow,
      endDoc: lookAheadEnd,
      stockingCount: (pond['seed_count'] as int?) ?? 100000,
      pondArea: (pond['area'] as num?)?.toDouble() ?? 1.0,
      stockingDate: DateTime.parse(pond['stocking_date'] as String),
    );

    AppLogger.info('ensureFutureFeedExists: generated DOC $tomorrow–$lookAheadEnd for pond $pondId');
  } catch (e) {
    AppLogger.error('ensureFutureFeedExists failed for pond $pondId', e);
  }
}

// ── INTERPOLATION HELPER ─────────────────────────────────────────────────────

double _interpolate(Map<int, double> table, int doc) {
  final keys = table.keys.toList()..sort();
  if (doc <= keys.first) return table[keys.first]!;
  if (doc >= keys.last) return table[keys.last]!;
  for (int i = 0; i < keys.length - 1; i++) {
    final k1 = keys[i], k2 = keys[i + 1];
    if (doc >= k1 && doc <= k2) {
      final t = (doc - k1) / (k2 - k1);
      return table[k1]! + t * (table[k2]! - table[k1]!);
    }
  }
  return table[keys.last]!;
}
