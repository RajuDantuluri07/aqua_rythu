import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../systems/planning/feed_plan_generator.dart';
import '../utils/logger.dart';
import 'analytics_service.dart';
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
    );
  }

  /// Creates a pond + blind-phase feed schedule atomically via a single DB RPC.
  /// Returns the new pond ID. Passing [operationId] makes the call idempotent —
  /// a second call with the same ID returns the existing pond without a duplicate.
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
    }
    return pondId;
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
      stockingDate: DateTime.parse(pond['stocking_date']).toUtc(),
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
        stockingDate: DateTime.parse(row['stocking_date'] as String).toUtc(),
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
    } catch (e) {
      AppLogger.error('Failed to fetch pond by ID: $pondId', e);
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
    final stockDate = DateTime.parse(stockingDate).toUtc();
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

    // 4. Regenerate feed plan.
    await generateFeedSchedule(pondId);
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
    } catch (e) {
      throw Exception('Failed to start new cycle for pond $pondId: $e');
    }
  }

  // ================================
  // ✅ DELETE POND
  // ================================

  Future<void> deletePond(String pondId) async {
    try {
      await supabase.rpc('delete_pond_cascade', params: {'p_pond_id': pondId});
      AppLogger.info("Pond deleted from DB: $pondId");
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
      throw Exception('Failed to update Smart Feed status: $e');
    }
  }
}
