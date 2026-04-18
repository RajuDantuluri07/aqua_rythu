import 'package:supabase_flutter/supabase_flutter.dart';
import '../engines/feed/feed_base_calculation_engine.dart';
import '../engines/feed/feed_input_builder.dart';
import '../engines/planning/feed_plan_constants.dart';
import '../engines/planning/feed_plan_generator.dart';
import '../engines/feed/master_feed_engine.dart';
import '../enums/tray_status.dart';
import '../utils/logger.dart';

class FeedService {
  final supabase = Supabase.instance.client;

  Future<void> saveFeed({
    required String pondId,
    required DateTime date,
    required int doc,
    required List<double> rounds,
    required double expectedFeed,
    required double cumulativeFeed,
    double? leftoverPercent,
    String? stockingType,
    int? density,
    String? engineVersion,
  }) async {
    // Store today's daily total (sum of all rounds passed so far).
    // _persistFeedLog always passes log.rounds = ALL today's rounds, so total is
    // the growing running-daily sum. _actualFeedForDoc and _computeLastFcr both
    // take the LAST row per date as the authoritative day total — this is correct.
    // NOTE: cumulativeFeed (all-time since stocking) is intentionally NOT stored
    // here; it lives only in FeedHistoryLog in-memory state.
    final total = FeedBaseCalculationEngine.sumRounds(rounds);
    await supabase.from('feed_logs').insert({
      'pond_id': pondId,
      'feed_given': total,
      'created_at': date.toIso8601String(),
      'doc': doc,
      if (leftoverPercent != null) 'tray_leftover': leftoverPercent,
      if (stockingType != null) 'stocking_type': stockingType,
      if (density != null) 'density': density,
      if (engineVersion != null) 'engine_version': engineVersion,
    });
  }

  /// Fetch all logged feed entries for a pond, oldest first.
  /// Fix #2: include 'doc' so FeedHistoryLog.doc is populated (was always 0).
  Future<List<Map<String, dynamic>>> fetchFeedLogs(String pondId) async {
    return await supabase
        .from('feed_logs')
        .select('feed_given, created_at, doc')
        .eq('pond_id', pondId)
        .order('created_at', ascending: true);
  }

  Future<DateTime?> fetchLatestFeedTimeForDoc({
    required String pondId,
    required int doc,
  }) async {
    final row = await supabase
        .from('feed_logs')
        .select('created_at')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return DateTime.tryParse(row['created_at'] as String? ?? '');
  }

  /// Fetch all feed plans for a pond
  Future<List<Map<String, dynamic>>> getFeedPlans(String pondId) async {
    if (pondId.isEmpty) {
      throw Exception('Invalid pondId');
    }
    
    try {
      return await supabase
          .from('feed_rounds')
          .select('doc, round, planned_amount, base_feed, status')
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

  /// Pre-mark the first [count] feed rounds for a pond+doc as completed.
  /// Called right after pond creation when the farmer reports they've
  /// already fed N times today.
  Future<void> premarkRoundsCompleted({
    required String pondId,
    required int doc,
    required int count,
  }) async {
    if (count <= 0) return;
    final rows = await supabase
        .from('feed_rounds')
        .select('id, round')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round', ascending: true)
        .limit(count);

    for (final row in rows) {
      await supabase
          .from('feed_rounds')
          .update({'status': 'completed'})
          .eq('id', row['id'] as String);
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

  /// Writes redistributed round amounts back to DB (called after redistribution
  /// guard fires in [PondDashboardNotifier.loadTodayFeed]).
  /// Only updates rows that exist (idMap); skips rounds with no row id.
  Future<void> persistCorrectedRounds(
    String pondId,
    int doc,
    Map<int, double> correctedAmounts,
    Map<int, String> idMap,
  ) async {
    for (final entry in correctedAmounts.entries) {
      final round = entry.key;
      final amount = entry.value;
      final id = idMap[round];
      if (id == null || id.isEmpty) continue;
      await supabase.from('feed_rounds').update({
        'planned_amount': amount,
        'base_feed': amount,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }
    AppLogger.info(
        'Redistribution written to DB for pond $pondId DOC $doc: '
        '${correctedAmounts.entries.map((e) => "R${e.key}:${e.value.toStringAsFixed(2)}kg").join(" | ")}');
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

        // Enforce config constraints: inactive rounds for this DOC are always 0.
        // This is the write gate — DB must never hold feed amounts for rounds
        // that have no scheduled time for the given DOC.
        final config = getFeedConfig(doc);
        final paddedRounds = List<double>.generate(4, (i) {
          if (i >= rounds.length) return 0.0;
          if (i >= config.splits.length || config.splits[i] == 0.0) return 0.0;
          return rounds[i];
        });

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

        // Parallelize the 4 rounds per DOC — previously sequential (4 awaits),
        // now a single parallel batch (1 await for 4 concurrent operations).
        await Future.wait(List.generate(4, (i) async {
          final round = FeedBaseCalculationEngine.oneBasedIndex(i);
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
        }));
      }

      AppLogger.info("Feed plans saved for pond $pondId (${feedPlans.length} DOCs × 4 rounds)");
    } catch (e) {
      throw Exception('Failed to save feed plans: $e');
    }
  }

  // ── FEED ADJUSTMENT (moved from FeedOrchestrator) ──────────────────────────

  /// Called immediately after a tray log is saved.
  ///
  /// Runs the full pipeline and updates feed_rounds for DOC+1, DOC+2, DOC+3.
  Future<void> applyTrayAdjustment({
    required String pondId,
    required int doc,
    required TrayStatus trayStatus,
  }) async {
    // Only apply smart-phase adjustments when DOC is in smart mode.
    // kSmartModeMinDoc is the canonical threshold owned by MasterFeedEngine.
    if (doc <= kSmartModeMinDoc) return;

    try {
      final result = await MasterFeedEngine.orchestrateForPond(pondId);

      if (result.combinedFactor <= 0.0) return;

      final reasonTag = _reasonTag(result.combinedFactor, trayStatus.name);

      await _logDebug(
        pondId: pondId,
        doc: doc,
        result: result,
        reason: reasonTag,
      );

      for (final offset in [1, 2, 3]) {
        final futureDoc = FeedBaseCalculationEngine.futureDocFor(doc, offset);
        if (futureDoc > 120) break;
        await _applyFactorFromBase(pondId, futureDoc, result.combinedFactor, reasonTag);
      }

      AppLogger.info(
        'FeedService.applyTrayAdjustment: pond $pondId DOC $doc '
        '(smart) → +1/+2/+3 '
        'tray=${trayStatus.name} factor=${result.combinedFactor.toStringAsFixed(3)}',
      );
    } catch (e) {
      AppLogger.error('FeedService.applyTrayAdjustment failed for $pondId', e);
    }
  }

  /// Called after feed logs are saved and on dashboard load.
  ///
  /// Runs the full pipeline and updates feed_rounds for DOC+1.
  Future<void> recalculateFeedPlan(String pondId) async {
    try {
      final input = await FeedInputBuilder.fromDB(pondId);
      await ensureFutureFeedExists(pondId, input.doc);

      // Fix #7: Only apply smart-phase factor adjustments in smart mode (DOC ≥ 31).
      // For blind/tray-habit phases, ensureFutureFeedExists above is sufficient —
      // applying environment or tray corrections here would violate the blind-feed rule.
      if (input.doc <= kSmartModeMinDoc) return;

      final result = MasterFeedEngine.orchestrate(input);
      if (result.combinedFactor <= 0.0) return;

      final nextDoc = FeedBaseCalculationEngine.nextDoc(input.doc);
      final reason = _reasonTag(result.combinedFactor, 'RECALC');

      await _logDebug(
        pondId: pondId,
        doc: input.doc,
        result: result,
        reason: reason,
      );

      await _applyFactorFromBase(pondId, nextDoc, result.combinedFactor, reason);

      AppLogger.info(
        'FeedService.recalculate: pond $pondId DOC=${input.doc} '
        '→ DOC $nextDoc factor=${result.combinedFactor.toStringAsFixed(3)}',
      );
    } catch (e) {
      AppLogger.error('FeedService.recalculateFeedPlan failed for $pondId', e);
    }
  }

  Future<void> _applyFactorFromBase(
    String pondId,
    int doc,
    double factor,
    String reason,
  ) async {
    final rows = await supabase
        .from('feed_rounds')
        .select('id, base_feed, is_manual')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .eq('status', 'pending');

    for (final row in rows) {
      if (row['is_manual'] == true) continue;
      final base = (row['base_feed'] as num?)?.toDouble();
      if (base == null || base <= 0) continue;

      final adjusted = FeedBaseCalculationEngine.adjustedFeed(base, factor);

      try {
        await supabase.from('feed_rounds').update({
          'planned_amount': double.parse(adjusted.toStringAsFixed(3)),
          'adjustment_reason': reason,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', row['id'] as String).eq('status', 'pending');
      } catch (e) {
        AppLogger.debug(
            'FeedService: race on row ${row['id']} (doc $doc) — skipped');
      }
    }
  }

  Future<void> _logDebug({
    required String pondId,
    required int doc,
    required OrchestratorResult result,
    required String reason,
  }) async {
    try {
      await supabase.from('feed_debug_logs').insert({
        'pond_id': pondId,
        'doc': doc,
        'mode': result.isSmartApplied ? 'smart' : 'blind',
        'base_feed': result.baseFeed,
        'expected_feed': result.intelligence.expectedFeed,
        'actual_feed': result.intelligence.actualFeed,
        'deviation': result.intelligence.deviation,
        'deviation_pct': result.intelligence.deviationPercent,
        'intelligence_status': result.intelligence.status.name,
        'tray_factor': result.correction.trayFactor,
        'growth_factor': result.correction.growthFactor,
        'sampling_factor': result.correction.samplingFactor,
        'environment_factor': result.correction.environmentFactor,
        'fcr_factor': result.correction.fcrFactor,
        'intelligence_factor': result.correction.intelligenceFactor,
        'combined_factor': result.combinedFactor,
        'final_feed': result.finalFeed,
        'engine_version': MasterFeedEngine.version,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.debug('feed_debug_logs insert failed (non-critical): $e');
    }
  }

  static String _reasonTag(double factor, String tag) {
    final pct = FeedBaseCalculationEngine.factorPct(factor);
    const prefix = 'TRAY';
    final tagUpper = tag.toUpperCase();
    if (pct == 0) return '${prefix}_$tagUpper HOLD';
    return pct > 0
        ? '${prefix}_$tagUpper +$pct%'
        : '${prefix}_$tagUpper $pct%';
  }
}
