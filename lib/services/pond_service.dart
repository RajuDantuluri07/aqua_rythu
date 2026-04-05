import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_plan_generator.dart';

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
      print("CREATED POND ID: $pondId");

      // MANDATORY: Generate feed schedule immediately after pond creation
      await generateFeedSchedule(pondId);

      print('✅ Pond + Feed Plan ensured: $pondId');
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
      print("❌ Cannot generate feed: pond $pondId not found");
      return;
    }

    await generateFeedPlan(
      pondId: pondId,
      startDoc: 1,
      endDoc: 30,
      stockingCount: pond['seed_count'] ?? 100000,
      pondArea: (pond['area'] as num?)?.toDouble() ?? 1.0,
      stockingDate: DateTime.parse(pond['stocking_date']),
    );

    print("✅ Feed schedule generated for pond: $pondId");
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
    final today = DateTime.now();
    final stockDate = DateTime.parse(stockingDate);

    final doc = today.difference(stockDate).inDays + 1;

    print("📊 Calculated DOC: $doc");

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
      
      print('✅ Smart Feed status updated for pond: $pondId (enabled: $isEnabled)');
    } catch (e) {
      throw Exception('Failed to update Smart Feed status: $e');
    }
  }
}