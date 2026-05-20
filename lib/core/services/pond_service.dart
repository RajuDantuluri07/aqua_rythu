import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../systems/planning/feed_plan_generator.dart';
import '../../systems/planning/feed_plan_constants.dart';
import '../../systems/feed/blind_feeding_engine.dart';
import '../utils/logger.dart';
import 'analytics_service.dart';
import 'crashlytics_service.dart';
import '../utils/doc_utils.dart';
import '../utils/uuid_generator.dart';
import '../../features/farm/farm_provider.dart';
import '../../features/pond/enums/seed_type.dart';
import '../models/crop_cycle.dart';
import 'crop_cycle_service.dart';
export '../../features/farm/farm_provider.dart' show Pond, PondStatus;

class PondService {
  final supabase = Supabase.instance.client;

  // ================================
  // ✅ CREATE POND (STABLE)
  // ================================
  Future<void> createPond({
    required String farmId,
    required String name,
    required double area,
    required DateTime stockingDate,
    required int seedCount,
    required int plSize,
    required int numTrays,
    SeedType? seedType,
    String? feedBrandId,
    String? operationId,
    bool skipFeedRounds = false,
  }) async {
    await createPondAndReturnId(
      farmId: farmId,
      name: name,
      area: area,
      stockingDate: stockingDate,
      seedCount: seedCount,
      plSize: plSize,
      numTrays: numTrays,
      seedType: seedType,
      feedBrandId: feedBrandId,
      operationId: operationId,
      skipFeedRounds: skipFeedRounds,
    );
  }

  /// Creates a pond + blind-phase feed schedule atomically via a single DB RPC.
  /// Returns the new pond ID. Passing [operationId] makes the call idempotent —
  /// a second call with the same ID returns the existing pond without a duplicate.
  ///
  /// Set [skipFeedRounds] to true for smart-init ponds (DOC past blind phase)
  /// so no fake historical feed rows are created.
  Future<String?> createPondAndReturnId({
    required String farmId,
    required String name,
    required double area,
    required DateTime stockingDate,
    required int seedCount,
    required int plSize,
    required int numTrays,
    SeedType? seedType,
    String? feedBrandId,
    String? operationId,
    bool skipFeedRounds = false,
  }) async {
    if (supabase.auth.currentUser == null) {
      throw Exception('User not logged in');
    }

    final resolvedSeedType = seedType ?? SeedTypeX.fromPlSize(plSize);
    final opId = operationId ?? generateUuidV4();

    final params = <String, dynamic>{
      'p_farm_id':       farmId,
      'p_name':          name,
      'p_area':          area,
      'p_stocking_date': stockingDate.toIso8601String().split('T')[0],
      'p_seed_count':    seedCount,
      'p_pl_size':       plSize,
      'p_num_trays':     numTrays,
      'p_stocking_type': resolvedSeedType.dbValue,
      'p_operation_id':  opId,
    };
    if (feedBrandId != null) {
      params['p_feed_brand_id'] = feedBrandId;
    }
    if (skipFeedRounds) {
      params['p_skip_feed_rounds'] = true;
    }

    final result = await supabase.rpc('create_pond_with_feed_plan', params: params);
    final response = Map<String, dynamic>.from(result as Map);

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to create pond');
    }

    final pondId = response['pond_id'] as String;
    final roundsCreated = response['feed_rounds_created'] as int? ?? 0;
    final isDuplicate = response['duplicate'] == true;

    AppLogger.info(
      'Pond created: $pondId — $roundsCreated feed rounds '
      '(brand: ${feedBrandId ?? 'none'}, duplicate: $isDuplicate)',
    );
    if (!isDuplicate) {
      unawaited(AnalyticsService.instance.logPondCreated(pondId: pondId));
      final doc = calculateDocFromStockingDateLegacy(stockingDate);
      if (seedCount > 0) {
        unawaited(AnalyticsService.instance.logStockingAdded(
          pondId: pondId,
          seedType: resolvedSeedType.dbValue,
          seedCount: seedCount,
          plSizeMm: plSize.toDouble(),
          doc: doc,
        ));
      }
      if (roundsCreated > 0) {
        unawaited(AnalyticsService.instance.logFeedSetupCompleted(
          pondId: pondId,
          seedType: resolvedSeedType.dbValue,
        ));
      }
    }
    return pondId;
  }

  // ================================
  // ✅ SMART FEED INITIALIZATION
  // ================================

  /// Activates smart feeding for a pond that joined after the blind phase.
  /// Stores the farmer's current operating data as the intelligence baseline
  /// and sets is_smart_feed_enabled = true immediately.
  Future<void> initializeSmartFeedPond({
    required String pondId,
    required int doc,
    required double currentFeedKg,
    double? abw,
    double? survivalPct,
    required int roundsPerDay,
    DateTime? lastSamplingDate,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'anchor_feed': currentFeedKg,
        'is_anchor_initialized': true,
        if (abw != null) 'current_abw': abw,
        if (survivalPct != null) 'survival_pct': survivalPct,
        'post_week_feed_rounds': roundsPerDay,
        'is_custom_feed_plan': true,
        'is_smart_feed_enabled': true,
        'smart_feed_initialized': true,
        'smart_feed_initialized_at': DateTime.now().toUtc().toIso8601String(),
        'initialization_doc': doc,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (lastSamplingDate != null) {
        updateData['latest_sample_date'] = lastSamplingDate.toIso8601String();
      }
      await supabase.from('ponds').update(updateData).eq('id', pondId);
      unawaited(AnalyticsService.instance.logSmartFeedInitialized(pondId: pondId, doc: doc));
      AppLogger.info(
        'Smart feed initialized for pond $pondId — '
        'DOC $doc, anchor ${currentFeedKg.toStringAsFixed(1)} kg, '
        'ABW ${abw?.toStringAsFixed(1) ?? '-'} g, survival ${survivalPct?.toStringAsFixed(0) ?? '-'}%, '
        '$roundsPerDay rounds/day',
      );
    } catch (e, st) {
      CrashlyticsService.instance
          .logError(e, st, reason: 'initializeSmartFeedPond failed');
      throw Exception('Failed to initialize smart feed for pond $pondId: $e');
    }
  }

  // ================================
  // ✅ TODAY OPERATIONAL ROUNDS
  // ================================

  /// Writes today's feed rounds to the DB for a post-blind-feed pond.
  ///
  /// PRO path: pass [totalFeedKg] from the farmer's initialization input.
  /// FREE path: omit [totalFeedKg] (defaults to 0) — the method computes a
  /// reasonable starting amount from the blind-feed formula at the cap DOC
  /// (DOC 10 for nursery, DOC 30 for hatchery) scaled to [seedCount].
  ///
  /// Writes today's operational feed rounds to the DB.
  ///
  /// FIX 3 — Generation guard: if rows already exist for (pond_id, doc) they
  /// are returned as-is. Nothing is overwritten — farmer edits and completed
  /// rounds are preserved.
  ///
  /// FIX 2 — Single source of truth: the same [totalFeedKg] value is used to
  /// compute every round amount. No separate recalculation elsewhere.
  ///
  /// FIX 4 — Rounding fix: the remainder after integer-cent division is added
  /// to the last round so SUM(planned_amount) == totalFeedKg exactly (±0.01 kg).
  Future<void> generateTodayOperationalRounds({
    required String pondId,
    required int doc,
    required int roundsPerDay,
    double totalFeedKg = 0.0,
    int seedCount = 100000,
    SeedType? seedType,
  }) async {
    try {
      // FIX 3: Guard — return existing rounds, never overwrite them.
      final existing = await supabase
          .from('feed_rounds')
          .select('id')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .limit(1);
      if (existing.isNotEmpty) {
        AppLogger.info(
            'generateTodayOperationalRounds: rounds already exist for pond=$pondId doc=$doc — skipping');
        return;
      }

      // Determine total feed for the day.
      double feedPerDay = totalFeedKg;
      if (feedPerDay <= 0) {
        final capDoc = (seedType == SeedType.nurseryBig) ? 10 : 30;
        feedPerDay = BlindFeedingEngine.calculateBlindFeed(
          doc: capDoc,
          seedCount: seedCount,
          seedType: seedType?.dbValue ?? 'hatchery',
        );
      }

      // FIX 4: Distribute evenly to 2 decimal places; add remainder to last round
      // so SUM(rounds) == feedPerDay exactly.
      final basePerRound = (feedPerDay / roundsPerDay * 100).floor() / 100.0;
      final roundAmounts = List.generate(roundsPerDay, (i) {
        if (i == roundsPerDay - 1) {
          // Last round absorbs rounding remainder.
          final sum = double.parse(
              (basePerRound * (roundsPerDay - 1)).toStringAsFixed(2));
          return double.parse((feedPerDay - sum).toStringAsFixed(2));
        }
        return basePerRound;
      });

      await supabase.from('feed_rounds').insert(
        [
          for (int r = 1; r <= roundsPerDay; r++)
            {
              'pond_id': pondId,
              'doc': doc,
              'round': r,
              'planned_amount': roundAmounts[r - 1],
              'base_feed': roundAmounts[r - 1],
              'feed_type': getFeedType(doc),
              'status': 'pending',
            },
        ],
      );

      // FIX 4: Validate that the rounds sum to the intended daily target.
      final actualSum = roundAmounts.fold(0.0, (s, v) => s + v);
      final delta = (actualSum - feedPerDay).abs();
      if (delta > 0.01) {
        final msg =
            'Feed round sum mismatch: expected ${feedPerDay.toStringAsFixed(3)} kg, '
            'got ${actualSum.toStringAsFixed(3)} kg (Δ${delta.toStringAsFixed(3)}) '
            '— pond=$pondId doc=$doc rounds=$roundsPerDay';
        AppLogger.error(msg);
        CrashlyticsService.instance.logError(
          Exception(msg),
          StackTrace.current,
          reason: 'feed_round_sum_mismatch',
        );
      }

      AppLogger.info(
        'Operational rounds created: pond=$pondId doc=$doc '
        '${roundAmounts.map((a) => a.toStringAsFixed(2)).join(' + ')} kg '
        '= ${actualSum.toStringAsFixed(2)} kg',
      );
    } catch (e, st) {
      CrashlyticsService.instance
          .logError(e, st, reason: 'generateTodayOperationalRounds failed');
      rethrow;
    }
  }

  /// Creates today's feed rounds for a mid-crop pond with planned_amount = 0.
  /// Farmer manually enters each round's actual amount at confirmation time.
  /// Guard: skips if rounds already exist for (pond_id, doc).
  Future<void> generateManualOperationalRounds({
    required String pondId,
    required int doc,
    required int roundsPerDay,
  }) async {
    try {
      final existing = await supabase
          .from('feed_rounds')
          .select('id')
          .eq('pond_id', pondId)
          .eq('doc', doc)
          .limit(1);
      if (existing.isNotEmpty) {
        AppLogger.info(
            'generateManualOperationalRounds: rounds exist for pond=$pondId doc=$doc — skipping');
        return;
      }

      await supabase.from('feed_rounds').insert([
        for (int r = 1; r <= roundsPerDay; r++)
          {
            'pond_id': pondId,
            'doc': doc,
            'round': r,
            'planned_amount': 0.0,
            'base_feed': 0.0,
            'feed_type': getFeedType(doc),
            'status': 'pending',
          },
      ]);

      AppLogger.info(
          'Manual rounds created: pond=$pondId doc=$doc rounds=$roundsPerDay');
    } catch (e, st) {
      CrashlyticsService.instance
          .logError(e, st, reason: 'generateManualOperationalRounds failed');
      rethrow;
    }
  }

  // ================================
  // 🚀 FEED SCHEDULE GENERATION (uses feed_plan_generator)
  // ================================

  Future<void> generateFeedSchedule(String pondId) async {
    // Look up pond details needed for scaled generation
    final pond = await supabase
        .from('ponds')
        .select('stocking_date, seed_count, area, stocking_type')
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      AppLogger.error("Cannot generate feed: pond $pondId not found");
      return;
    }

    final stockingType = (pond['stocking_type'] as String?) ?? 'nursery';

    // Generate blind feeding phase:
    // - Nursery: DOC 1–10 only (nursery phase ends at DOC 10)
    // - Hatchery: DOC 1–25 (DOC 26–29 added by rolling recovery)
    // - DOC ≥ 30: no pre-generated schedule for either type
    final endDoc = stockingType == 'nursery' ? 10 : 25;
    await generateFeedPlan(
      pondId: pondId,
      startDoc: 1,
      endDoc: endDoc,
      stockingCount: pond['seed_count'] ?? 100000,
      pondArea: (pond['area'] as num?)?.toDouble() ?? 1.0,
      stockingDate: DateTime.parse(pond['stocking_date']),
      stockingType: stockingType,
    );

    AppLogger.info(
        "Feed schedule generated for pond: $pondId (DOC 1–25 blind phase)");
  }

  // ================================
  // ✅ GET SINGLE POND
  // ================================
  Future<Pond?> getPondById(String pondId) async {
    try {
      final row = await supabase.from('ponds').select('''
            id,
            name,
            area,
            stocking_date,
            seed_count,
            pl_size,
            num_trays,
            status,
            current_abw,
            latest_sample_date,
            is_smart_feed_enabled,
            anchor_feed,
            is_anchor_initialized,
            smart_feed_initialized,
            smart_feed_initialized_at,
            stocking_type,
            feed_brand_id,
            active_crop_id,
            pond_status,
            harvest_status,
            stocked_at,
            harvested_at
          ''').eq('id', pondId).maybeSingle();

      if (row == null) return null;

      return Pond(
        id: row['id'] as String,
        name: row['name'] as String,
        area: (row['area'] as num?)?.toDouble() ?? 0.0,
        stockingDate: DateTime.parse(row['stocking_date'] as String),
        seedCount: row['seed_count'] ?? 100000,
        plSize: row['pl_size'] ?? 10,
        numTrays: row['num_trays'] ?? 4,
        status: PondStatus.values.byName(row['status'] ?? 'active'),
        currentAbw: (row['current_abw'] as num?)?.toDouble(),
        latestSampleDate: row['latest_sample_date'] != null
            ? DateTime.parse(row['latest_sample_date'] as String)
            : null,
        isSmartFeedEnabled: row['is_smart_feed_enabled'] ?? false,
        anchorFeed: (row['anchor_feed'] as num?)?.toDouble(),
        isAnchorInitialized: row['is_anchor_initialized'] ?? false,
        smartFeedInitialized: row['smart_feed_initialized'] ?? false,
        smartFeedInitializedAt: row['smart_feed_initialized_at'] != null
            ? DateTime.tryParse(row['smart_feed_initialized_at'] as String)
            : null,
        seedType: SeedTypeX.fromDb(row['stocking_type'] as String?),
        feedBrandId: row['feed_brand_id'] as String?,
        activeCropId: row['active_crop_id'] as String?,
        pondLifecycleStatus:
            PondLifecycleStatusX.fromDb(row['pond_status'] as String?),
        harvestStatus:
            HarvestStatusX.fromDb(row['harvest_status'] as String?),
        stockedAt: row['stocked_at'] != null
            ? DateTime.tryParse(row['stocked_at'] as String)
            : null,
        harvestedAt: row['harvested_at'] != null
            ? DateTime.tryParse(row['harvested_at'] as String)
            : null,
      );
    } catch (e, st) {
      AppLogger.error('Failed to fetch pond by ID: $pondId', e);
      CrashlyticsService.instance.logError(e, st, reason: 'getPondById failed');
      return null;
    }
  }

  // ================================
  // ✅ GET PONDS (NO BROKEN FILTERS)
  // ================================
  Future<List<Map<String, dynamic>>> getPonds(String farmId) async {
    return await supabase.from('ponds').select('''
          id,
          name,
          area,
          stocking_date,
          seed_count,
          pl_size,
          num_trays,
          status,
          current_abw,
          is_smart_feed_enabled,
          feed_brand_id,
          active_crop_id,
          pond_status
        ''').eq('farm_id', farmId).order('created_at', ascending: false);
  }

  // ================================
  // 🔥 GET TODAY FEED
  // ================================
  Future<List<Map<String, dynamic>>> getTodayFeed({
    required String pondId,
    required String stockingDate,
  }) async {
    final stockDate = DateTime.parse(stockingDate);
    final doc = calculateDocFromStockingDateLegacy(stockDate);

    AppLogger.debug("Calculated DOC: $doc for pond $pondId");

    if (doc < 1) return [];

    final rounds = await supabase
        .from('feed_rounds')
        .select()
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round');

    return rounds;
  }

  // ================================
  // ⚠️ DEPRECATED - DO NOT USE
  // ================================
  // These methods are deprecated for MVP stabilization
  // Use feed_rounds table only

  @Deprecated('Use feed_rounds table only - feed_schedules is deprecated')
  Future<void> saveFeedSchedule(
      String pondId, List<Map<String, dynamic>> scheduleData) async {
    throw UnimplementedError(
        'saveFeedSchedule is deprecated - use feed_rounds table only');
  }

  @Deprecated('Use feed_rounds table only - feed_schedules is deprecated')
  Future<List<Map<String, dynamic>>> getFeedSchedule(String pondId) async {
    throw UnimplementedError(
        'getFeedSchedule is deprecated - use feed_rounds table only');
  }

  // ================================
  // ✅ START NEW CROP CYCLE (multi-crop architecture)
  // ================================

  /// Creates a new farm-level crop cycle and assigns this pond to it.
  /// Pass [existingCycleId] to join an existing active cycle instead.
  /// Clears old operational data and regenerates the feed plan.
  Future<CropCycle> startNewCropCycle({
    required String farmId,
    required String pondId,
    required DateTime stockingDate,
    required int seedCount,
    required int plSize,
    required int numTrays,
    String? feedBrandId,
    String? existingCycleId,
    String? cycleName,
    String? species,
  }) async {
    final svc = CropCycleService();

    // 1. Resolve or create the farm-level crop cycle.
    CropCycle cycle;
    if (existingCycleId != null) {
      cycle = (await svc.getCycleById(existingCycleId))!;
    } else {
      final name = cycleName ??
          'Cycle — ${stockingDate.day}/${stockingDate.month}/${stockingDate.year}';
      cycle = await svc.createCycle(
        farmId: farmId,
        name: name,
        species: species,
        stockingDate: stockingDate,
      );
    }

    // 2. Clear old cycle data for this pond.
    await supabase.rpc('clear_pond_cycle_tables', params: {'p_pond_id': pondId});
    AppLogger.info('Cleared old cycle data for pond $pondId');

    // 3. Update pond with new stocking details and link to crop cycle.
    final updateData = <String, dynamic>{
      'stocking_date': stockingDate.toIso8601String().split('T')[0],
      'seed_count': seedCount,
      'pl_size': plSize,
      'num_trays': numTrays,
      'status': 'active',
      'current_abw': null,
      'active_crop_id': cycle.id,
      'pond_status': PondLifecycleStatus.active.dbValue,
      'harvest_status': HarvestStatus.notStarted.dbValue,
      'stocked_at': stockingDate.toIso8601String(),
      'harvested_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (feedBrandId != null) updateData['feed_brand_id'] = feedBrandId;
    await supabase.from('ponds').update(updateData).eq('id', pondId);

    // 4. Regenerate feed plan — skip if DOC already past blind phase.
    // Generating DOC 1–N blind rounds for a mid-cycle stocking date creates
    // fake historical data. The farmer must initialize via SmartFeedInit instead.
    final resolvedSeedType = SeedTypeX.fromPlSize(plSize);
    final doc = calculateDocFromStockingDateLegacy(stockingDate);
    final needsSmartInit =
        (resolvedSeedType == SeedType.nurseryBig && doc > 10) ||
        (resolvedSeedType == SeedType.hatcherySmall && doc > 30);
    if (!needsSmartInit) {
      await generateFeedSchedule(pondId);
    } else {
      AppLogger.info(
          'New cycle for pond $pondId is DOC $doc (past blind phase) — '
          'skipping blind round generation; farmer must run smart init');
    }
    AppLogger.info('New crop cycle started: ${cycle.id} for pond $pondId');

    return cycle;
  }

  // ================================
  // ✅ NEW CYCLE — CLEAR OLD DATA & REGENERATE FEED PLAN
  // ================================

  Future<void> clearPondCycleData({
    required String pondId,
    required DateTime newStockingDate,
    required int seedCount,
    required int plSize,
    required int numTrays,
    String? feedBrandId,
  }) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('User not logged in');
      final owned = await supabase
          .from('ponds')
          .select('id, farms!inner(user_id)')
          .eq('id', pondId)
          .eq('farms.user_id', uid)
          .maybeSingle();
      if (owned == null) throw Exception('Pond not found or access denied');

      // 1. Delete all historical rows in a single DB transaction via RPC.
      await supabase.rpc('clear_pond_cycle_tables', params: {'p_pond_id': pondId});

      AppLogger.info('Cleared all cycle data for pond $pondId');

      // 2. Update pond with new cycle details
      final updateData = {
        'stocking_date':
            newStockingDate.toUtc().toIso8601String().split('T')[0],
        'seed_count': seedCount,
        'pl_size': plSize,
        'num_trays': numTrays,
        'status': 'active',
        'current_abw': null,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (feedBrandId != null) {
        updateData['feed_brand_id'] = feedBrandId;
      }
      await supabase.from('ponds').update(updateData).eq('id', pondId);

      AppLogger.info('Pond $pondId reset to new cycle');

      // 3. Generate fresh feed plan for new stocking date
      await generateFeedSchedule(pondId);

      AppLogger.info('New feed plan generated for pond $pondId');
    } catch (e, st) {
      CrashlyticsService.instance.logError(e, st, reason: 'clearPondCycleData failed');
      throw Exception('Failed to start new cycle for pond $pondId: $e');
    }
  }

  // ================================
  // ✅ DELETE POND
  // ================================

  Future<void> deletePond(String pondId) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('User not logged in');
      final owned = await supabase
          .from('ponds')
          .select('id, farms!inner(user_id)')
          .eq('id', pondId)
          .eq('farms.user_id', uid)
          .maybeSingle();
      if (owned == null) throw Exception('Pond not found or access denied');
      await supabase.rpc('delete_pond_cascade', params: {'p_pond_id': pondId});
      AppLogger.info("Pond deleted from DB: $pondId");
    } catch (e, st) {
      CrashlyticsService.instance.logError(e, st, reason: 'deletePond failed');
      throw Exception('Failed to delete pond: $e');
    }
  }

  // ================================
  // ✅ POND STATUS UPDATE
  // ================================

  Future<void> updatePondStatus({
    required String pondId,
    required String status,
  }) async {
    try {
      await supabase.from('ponds').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', pondId);

      AppLogger.info("Pond status updated: $pondId → $status");
    } catch (e, st) {
      CrashlyticsService.instance.logError(e, st, reason: 'updatePondStatus failed');
      throw Exception('Failed to update pond status: $e');
    }
  }

  // ================================
  // ✅ SMART FEED ACTIVATION
  // ================================

  Future<void> updateAnchorFeed({
    required String pondId,
    required double anchorFeed,
  }) async {
    try {
      await supabase.from('ponds').update({
        'anchor_feed': anchorFeed,
        'is_anchor_initialized': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', pondId);

      AppLogger.info(
          'Anchor feed set for pond $pondId: ${anchorFeed.toStringAsFixed(2)} kg');
    } catch (e, st) {
      CrashlyticsService.instance.logError(e, st, reason: 'updateAnchorFeed failed');
      throw Exception('Failed to update anchor feed: $e');
    }
  }

  Future<void> updateSmartFeedStatus({
    required String pondId,
    required bool isEnabled,
  }) async {
    try {
      await supabase.from('ponds').update({
        'is_smart_feed_enabled': isEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', pondId);

      AppLogger.info(
          "Smart feed status updated for pond $pondId (enabled: $isEnabled)");
    } catch (e, st) {
      CrashlyticsService.instance.logError(e, st, reason: 'updateSmartFeedStatus failed');
      throw Exception('Failed to update Smart Feed status: $e');
    }
  }
}
