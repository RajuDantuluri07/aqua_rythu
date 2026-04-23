import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_plan_constants.dart';
import '../feed/master_feed_engine.dart';
import '../../../features/pond/enums/stocking_type.dart';
import '../../../core/utils/logger.dart';

final supabase = Supabase.instance.client;

// Global lock set to prevent concurrent feed plan generation for the same pond
final Set<String> _feedPlanLocks = <String>{};

/// Generates a feeding schedule for a range of DOCs (1–120).
///
/// Uses [MasterFeedEngine.compute] as the single source of truth.
/// No biomass, no 235 normalization, no FCR.
/// Tray factor defaults to 1.0 during plan generation (no leftover data yet).
Future<void> generateFeedPlan({
  required String pondId,
  required int startDoc,
  required int endDoc,
  required int stockingCount,
  required double pondArea,
  required DateTime stockingDate,
  String stockingType = 'nursery',
}) async {
  if (startDoc > endDoc) return;
  final clampedEnd = endDoc.clamp(startDoc, 120);

  // Acquire lock to prevent concurrent feed plan generation for the same pond
  final lockKey = '${pondId}_${startDoc}_${endDoc}';
  if (_feedPlanLocks.contains(lockKey)) {
    AppLogger.warn(
        'Feed plan generation already in progress for pond $pondId (DOC $startDoc-$endDoc)');
    return;
  }

  _feedPlanLocks.add(lockKey);
  try {
    AppLogger.info(
        'Generating feed plan: pond $pondId DOC $startDoc–$clampedEnd '
        'type=$stockingType density=$stockingCount');

    final existingRows = await supabase
        .from('feed_rounds')
        .select('doc')
        .eq('pond_id', pondId)
        .gte('doc', startDoc)
        .lte('doc', clampedEnd);

    final existingDocs = <int>{
      for (final row in existingRows) row['doc'] as int,
    };

    final batch = <Map<String, dynamic>>[];

    for (int doc = startDoc; doc <= clampedEnd; doc++) {
      if (existingDocs.contains(doc)) continue;

      final stockingTypeEnum = stockingType == 'hatchery'
          ? StockingType.hatchery
          : StockingType.nursery;
      final totalFeed = MasterFeedEngine.compute(
        doc: doc,
        stockingType: stockingTypeEnum,
        density: stockingCount,
      );

      final feedType = getFeedType(doc);
      final config = getFeedConfig(doc);

      for (int round = 1; round <= 4; round++) {
        final roundFeed = config.quantityForRound(round - 1, totalFeed);
        batch.add({
          'pond_id': pondId,
          'doc': doc,
          'round': round,
          'planned_amount': roundFeed,
          'base_feed': roundFeed,
          'feed_type': feedType,
          'status': 'pending',
        });
      }
    }

    if (batch.isNotEmpty) {
      try {
        // Upsert instead of insert so concurrent auto-recovery calls are safe.
        // The unique constraint on (pond_id, doc, round) means the second call
        // simply no-ops on conflicts rather than throwing a duplicate key error.
        await supabase.from('feed_rounds').upsert(batch,
            onConflict: 'pond_id,doc,round', ignoreDuplicates: true);
        AppLogger.info('Upserted ${batch.length} feed rounds for pond $pondId '
            '(DOC $startDoc–$clampedEnd)');
      } catch (e) {
        AppLogger.error('Feed plan upsert failed for pond $pondId', e);
        rethrow; // Re-throw to be caught by outer try block
      }
    }
  } catch (e) {
    AppLogger.error('Feed plan generation failed for pond $pondId', e);
  } finally {
    // Always release the lock
    _feedPlanLocks.remove(lockKey);
    AppLogger.debug(
        'Released feed plan lock for pond $pondId (DOC $startDoc-$endDoc)');
  }
}

// ── ROLLING RECOVERY ─────────────────────────────────────────────────────────

/// Checks if tomorrow's feed rows exist. If not, generates the next 7 DOCs.
/// Only generates blind-phase schedule (DOC 1–29). DOC ≥ 30 is smart mode —
/// feed is computed dynamically on demand, never pre-generated here.
/// Call this on dashboard load and after tray/feed events.
Future<void> ensureFutureFeedExists(String pondId, int currentDoc) async {
  final lockKey = '${pondId}_ensure_future_feed_${currentDoc}';

  // Prevent concurrent future feed generation for the same pond
  if (_feedPlanLocks.contains(lockKey)) {
    AppLogger.warn(
        'ensureFutureFeedExists already in progress for pond $pondId (DOC $currentDoc)');
    return;
  }

  _feedPlanLocks.add(lockKey);
  try {
    final tomorrow = currentDoc + 1;
    // Never pre-generate beyond the blind/tray-habit phase.
    // Fix #4: DOC ≥ 31 → smart feeding; amounts are computed live, not stored.
    if (tomorrow > 30) return;

    final existing = await supabase
        .from('feed_rounds')
        .select('id')
        .eq('pond_id', pondId)
        .eq('doc', tomorrow)
        .limit(1);

    if (existing.isNotEmpty) return;

    final pond = await supabase
        .from('ponds')
        .select('seed_count, stocking_date, area, stocking_type')
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      AppLogger.error('ensureFutureFeedExists: pond $pondId not found in DB');
      return;
    }

    // Fix #4: cap look-ahead at DOC 30 (end of tray-habit/blind phase).
    final lookAheadEnd = (currentDoc + 7).clamp(tomorrow, 30);

    await generateFeedPlan(
      pondId: pondId,
      startDoc: tomorrow,
      endDoc: lookAheadEnd,
      stockingCount: (pond['seed_count'] as int?) ?? 100000,
      pondArea: (pond['area'] as num?)?.toDouble() ?? 1.0,
      stockingDate: DateTime.parse(pond['stocking_date'] as String),
      stockingType: (pond['stocking_type'] as String?) ?? 'nursery',
    );

    AppLogger.info(
        'ensureFutureFeedExists: generated DOC $tomorrow–$lookAheadEnd '
        'for pond $pondId');
  } catch (e) {
    AppLogger.error('ensureFutureFeedExists failed for pond $pondId', e);
  } finally {
    // Always release the lock
    _feedPlanLocks.remove(lockKey);
    AppLogger.debug(
        'Released ensureFutureFeedExists lock for pond $pondId (DOC $currentDoc)');
  }
}
