import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_plan_constants.dart';
import '../feed/feed_engine_v2.dart';
import '../feed/blind_feeding_engine.dart';
import '../../../features/pond/enums/seed_type.dart';
import '../../../features/pond/enums/stocking_type.dart';
import '../../../core/utils/logger.dart';

final supabase = Supabase.instance.client;

// Global lock set to prevent concurrent feed plan generation for the same pond
final Set<String> _feedPlanLocks = <String>{};

/// Create a FeedConfig with equal splits for the given number of rounds
FeedConfig _createFeedConfig(int numRounds) {
  final splitValue = 1.0 / numRounds;
  final splits = List<double>.filled(numRounds, splitValue);

  // Define timings for different round counts
  final timings24h = _getTimings24h(numRounds);
  final timingsDisplay = _getTimingsDisplay(numRounds);

  return FeedConfig(
    rounds: numRounds,
    splits: splits,
    timings24h: timings24h,
    timingsDisplay: timingsDisplay,
  );
}

/// Get 24-hour timings for specified number of rounds
List<String> _getTimings24h(int numRounds) {
  switch (numRounds) {
    case 2:
      return ["06:00", "16:00"];
    case 3:
      return ["06:00", "12:00", "18:00"];
    case 4:
      return ["06:00", "11:00", "16:00", "21:00"];
    default:
      return ["06:00", "11:00", "16:00", "21:00"];
  }
}

/// Get display timings for specified number of rounds
List<String> _getTimingsDisplay(int numRounds) {
  switch (numRounds) {
    case 2:
      return ["06:00 AM", "04:00 PM"];
    case 3:
      return ["06:00 AM", "12:00 PM", "06:00 PM"];
    case 4:
      return ["06:00 AM", "11:00 AM", "04:00 PM", "09:00 PM"];
    default:
      return ["06:00 AM", "11:00 AM", "04:00 PM", "09:00 PM"];
  }
}

/// Generates a feeding schedule for a range of DOCs (1–120).
///
/// Uses seed-type-specific DOC tables for blind-phase plan generation.
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

  // Nursery phase ends at DOC 10 — prevent plan generation beyond that
  final docCap = stockingType == 'nursery' ? 10 : clampedEnd;
  final finalEnd = clampedEnd.clamp(startDoc, docCap);

  // Acquire lock to prevent concurrent feed plan generation for the same pond
  final lockKey = '${pondId}_${startDoc}_$endDoc';
  if (_feedPlanLocks.contains(lockKey)) {
    AppLogger.warn(
        'Feed plan generation already in progress for pond $pondId (DOC $startDoc-$endDoc)');
    return;
  }

  _feedPlanLocks.add(lockKey);
  try {
    AppLogger.info(
        'Generating feed plan: pond $pondId DOC $startDoc–$finalEnd '
        'type=$stockingType density=$stockingCount');

    final batch = <Map<String, dynamic>>[];

    for (int doc = startDoc; doc <= finalEnd; doc++) {
      // Always generate for all docs in range - upsert will update existing or insert new
      final stockingTypeEnum = stockingType == 'hatchery'
          ? StockingType.hatchery
          : StockingType.nursery;
      final seedType = stockingTypeEnum == StockingType.hatchery
          ? SeedType.hatcherySmall
          : SeedType.nurseryBig;
      final feedResult = await FeedEngineV2.getBlindFeed(
        seedType: seedType,
        doc: doc,
        seedCountLakhs: stockingCount / 100000,
      );
      final totalFeed = feedResult.totalFeedKg;

      final feedType = getFeedType(doc);

      // Determine number of feeds for this DOC and seed type
      final seedTypeEnum = stockingType == 'hatchery'
          ? SeedType.hatcherySmall
          : SeedType.nurseryBig;
      final numRounds = BlindFeedingEngine.getMealsPerDay(doc, seedType: seedTypeEnum);

      // Create dynamic config based on actual number of rounds
      final config = _createFeedConfig(numRounds);

      for (int round = 1; round <= numRounds; round++) {
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
      // BUG #8 FIX: Validate the generated schedule against BlindFeedingEngine
      // before writing. A bug in the DOC ramp or split formula would silently
      // produce wrong values for every row in the plan.
      if (finalEnd >= 30 && startDoc <= 30) {
        final expectedDoc30 = BlindFeedingEngine.calculateBlindFeed(
          doc: 30,
          seedCount: stockingCount,
          seedType: stockingType,
        );
        final generatedDoc30Total = batch
            .where((row) => row['doc'] == 30)
            .fold<double>(
                0.0, (sum, row) => sum + (row['planned_amount'] as double));

        if (expectedDoc30 > 0) {
          final variance = (generatedDoc30Total - expectedDoc30).abs();
          final pct = (variance / expectedDoc30) * 100;
          if (pct > 5.0) {
            AppLogger.warn(
              'Feed schedule DOC 30 validation: expected=${expectedDoc30.toStringAsFixed(2)}kg '
              'generated=${generatedDoc30Total.toStringAsFixed(2)}kg '
              'variance=${pct.toStringAsFixed(1)}% — check DOC ramp formula',
            );
          } else {
            AppLogger.info(
              'Feed schedule DOC 30 validation passed: '
              '${generatedDoc30Total.toStringAsFixed(2)}kg '
              '(expected ${expectedDoc30.toStringAsFixed(2)}kg)',
            );
          }
        }
      }

      try {
        // Upsert to update existing rows with correct seed-type amounts or insert new
        await supabase.from('feed_rounds').upsert(batch,
            onConflict: 'pond_id,doc,round');
        AppLogger.info('Upserted ${batch.length} feed rounds for pond $pondId '
            '(DOC $startDoc–$clampedEnd)');
      } catch (e) {
        AppLogger.error('Feed plan upsert failed for pond $pondId', e);
        rethrow;
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
  final lockKey = '${pondId}_ensure_future_feed_$currentDoc';

  // Prevent concurrent future feed generation for the same pond
  if (_feedPlanLocks.contains(lockKey)) {
    AppLogger.warn(
        'ensureFutureFeedExists already in progress for pond $pondId (DOC $currentDoc)');
    return;
  }

  _feedPlanLocks.add(lockKey);
  try {
    final tomorrow = currentDoc + 1;

    // Fetch pond to determine stocking type (nursery vs hatchery)
    final pond = await supabase
        .from('ponds')
        .select('seed_count, stocking_date, area, stocking_type')
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      AppLogger.error('ensureFutureFeedExists: pond $pondId not found in DB');
      return;
    }

    final stockingType = (pond['stocking_type'] as String?) ?? 'nursery';
    final docCap = stockingType == 'nursery' ? 10 : 30;

    // Never pre-generate beyond the phase ceiling (DOC 10 for nursery, DOC 30 for hatchery).
    if (tomorrow > docCap) return;

    final existing = await supabase
        .from('feed_rounds')
        .select('id')
        .eq('pond_id', pondId)
        .eq('doc', tomorrow)
        .limit(1);

    if (existing.isNotEmpty) return;

    // Cap look-ahead at the phase ceiling.
    final lookAheadEnd = (currentDoc + 7).clamp(tomorrow, docCap);

    await generateFeedPlan(
      pondId: pondId,
      startDoc: tomorrow,
      endDoc: lookAheadEnd,
      stockingCount: (pond['seed_count'] as int?) ?? 100000,
      pondArea: (pond['area'] as num?)?.toDouble() ?? 1.0,
      stockingDate: DateTime.parse(pond['stocking_date'] as String),
      stockingType: stockingType,
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
