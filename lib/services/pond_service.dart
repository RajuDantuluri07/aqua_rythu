import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/engines/feed_plan_generator.dart';
import '../core/utils/logger.dart';
import '../core/utils/doc_utils.dart';

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
  }) async {
    await createPondAndReturnId(
      farmId: farmId,
      name: name,
      area: area,
      stockingDate: stockingDate,
      seedCount: seedCount,
      plSize: plSize,
      numTrays: numTrays,
    );
  }

  /// Creates a pond + feed schedule and returns the new pond ID.
  /// Used when the caller needs the ID (e.g. to pre-mark feed rounds).
  Future<String?> createPondAndReturnId({
    required String farmId,
    required String name,
    required double area,
    required DateTime stockingDate,
    required int seedCount,
    required int plSize,
    required int numTrays,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final response = await supabase.rpc(
        'create_pond_with_feed_plan',
        params: {
          'p_farm_id': farmId,
          'p_name': name,
          'p_area': area,
          'p_stocking_date':
              stockingDate.toIso8601String().split('T')[0],
          'p_seed_count': seedCount,
          'p_pl_size': plSize,
          'p_num_trays': numTrays,
          'p_user_id': user.id,
        },
      );

      if (response == null || response is! String) {
        throw Exception('Invalid response from pond creation');
      }

      final pondId = response;
      AppLogger.info("Created pond: $pondId");

      // MANDATORY: Generate feed schedule immediately after pond creation
      await generateFeedSchedule(pondId);

      AppLogger.info("Pond + feed plan created: $pondId");
      return pondId;
    } catch (e) {
      throw Exception('Failed to create pond: $e');
    }
  }

  // ================================
  // 🚀 FEED SCHEDULE GENERATION (uses feed_plan_generator)
  // ================================

  Future<void> generateFeedSchedule(String pondId) async {
    // Look up pond details needed for scaled generation
    final pond = await supabase
        .from('ponds')
        .select('stocking_date, seed_count, area')
        .eq('id', pondId)
        .maybeSingle();

    if (pond == null) {
      AppLogger.error("Cannot generate feed: pond $pondId not found");
      return;
    }

    // Generate ONLY the blind feeding phase (DOC 1–25).
    // DOC 26–29 (transitional) are added by ensureFutureFeedExists rolling recovery.
    // DOC ≥ 30 (smart mode) has no pre-generated schedule — amounts are computed live.
    await generateFeedPlan(
      pondId: pondId,
      startDoc: 1,
      endDoc: 25,
      stockingCount: pond['seed_count'] ?? 100000,
      pondArea: (pond['area'] as num?)?.toDouble() ?? 1.0,
      stockingDate: DateTime.parse(pond['stocking_date']),
    );

    AppLogger.info("Feed schedule generated for pond: $pondId (DOC 1–25 blind phase)");
  }

  // ================================
  // ✅ GET PONDS (NO BROKEN FILTERS)
  // ================================
  Future<List<Map<String, dynamic>>> getPonds(String farmId) async {
    return await supabase
        .from('ponds')
        .select('''
          id,
          name,
          area,
          stocking_date,
          seed_count,
          pl_size,
          num_trays,
          status,
          current_abw,
          is_smart_feed_enabled
        ''')
        .eq('farm_id', farmId)
        .order('created_at', ascending: false);
  }

  // ================================
  // 🔥 GET TODAY FEED
  // ================================
  Future<List<Map<String, dynamic>>> getTodayFeed({
    required String pondId,
    required String stockingDate,
  }) async {
    final stockDate = DateTime.parse(stockingDate);
    final doc = calculateDocFromStockingDate(stockDate);

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
  Future<void> saveFeedSchedule(String pondId, List<Map<String, dynamic>> scheduleData) async {
    throw UnimplementedError('saveFeedSchedule is deprecated - use feed_rounds table only');
  }

  @Deprecated('Use feed_rounds table only - feed_schedules is deprecated')
  Future<List<Map<String, dynamic>>> getFeedSchedule(String pondId) async {
    throw UnimplementedError('getFeedSchedule is deprecated - use feed_rounds table only');
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
  }) async {
    try {
      // 1. Delete all historical rows tied to this pond in parallel
      await Future.wait([
        supabase.from('feed_rounds').delete().eq('pond_id', pondId),
        supabase.from('feed_logs').delete().eq('pond_id', pondId),
        supabase.from('tray_logs').delete().eq('pond_id', pondId),
        supabase.from('sampling_logs').delete().eq('pond_id', pondId),
        supabase.from('water_logs').delete().eq('pond_id', pondId),
        supabase.from('harvest_logs').delete().eq('pond_id', pondId),
      ]);

      AppLogger.info('Cleared all cycle data for pond $pondId');

      // 2. Update pond with new cycle details
      await supabase.from('ponds').update({
        'stocking_date': newStockingDate.toIso8601String().split('T')[0],
        'seed_count': seedCount,
        'pl_size': plSize,
        'num_trays': numTrays,
        'status': 'active',
        'current_abw': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', pondId);

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
      // Delete child rows first — FK constraints may not cascade automatically.
      // Matches the same table set used by clearPondCycleData.
      await Future.wait([
        supabase.from('feed_rounds').delete().eq('pond_id', pondId),
        supabase.from('feed_logs').delete().eq('pond_id', pondId),
        supabase.from('tray_logs').delete().eq('pond_id', pondId),
        supabase.from('sampling_logs').delete().eq('pond_id', pondId),
        supabase.from('water_logs').delete().eq('pond_id', pondId),
        supabase.from('harvest_logs').delete().eq('pond_id', pondId),
      ]);

      await supabase
          .from('ponds')
          .delete()
          .eq('id', pondId);

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
      await supabase
          .from('ponds')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pondId);

      AppLogger.info("Pond status updated: $pondId → $status");
    } catch (e) {
      throw Exception('Failed to update pond status: $e');
    }
  }

  // ================================
  // ✅ SMART FEED ACTIVATION
  // ================================
  
  Future<void> updateSmartFeedStatus({
    required String pondId,
    required bool isEnabled,
  }) async {
    try {
      await supabase
          .from('ponds')
          .update({
            'is_smart_feed_enabled': isEnabled,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pondId);
      
      AppLogger.info("Smart feed status updated for pond $pondId (enabled: $isEnabled)");
    } catch (e) {
      throw Exception('Failed to update Smart Feed status: $e');
    }
  }
}
