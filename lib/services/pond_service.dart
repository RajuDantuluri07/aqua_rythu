import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Verify feed plan exists
      final feedCheck = await supabase
          .from('feed_plans')
          .select('id')
          .eq('pond_id', pondId)
          .limit(1);

      if (feedCheck.isEmpty) {
        throw Exception('Feed plan not generated');
      }

      print('✅ Pond + Feed Plan created: $pondId');
    } catch (e) {
      throw Exception('Failed to create pond: $e');
    }
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
  // 🔥 GET TODAY FEED (CORRECT WAY)
  // ================================
  Future<List<Map<String, dynamic>>> getTodayFeed({
    required String pondId,
    required String stockingDate,
  }) async {
    final today = DateTime.now();
    final stockDate = DateTime.parse(stockingDate);

    final doc = today.difference(stockDate).inDays + 1;

    print("📊 Calculated DOC: $doc");

    // Safety: avoid negative or >30 for now
    if (doc < 1 || doc > 30) {
      return [];
    }

    final response = await supabase
        .from('feed_plans')
        .select('''
          id,
          doc,
          round,
          feed_amount,
          feed_type,
          is_completed,
          date
        ''')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .order('round', ascending: true);

    return response;
  }

  // ================================
  // ✅ FEED SCHEDULE METHODS
  // ================================
  
  Future<void> saveFeedSchedule(String pondId, List<Map<String, dynamic>> scheduleData) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      // Delete existing schedule for this pond
      await supabase
          .from('feed_schedules')
          .delete()
          .eq('pond_id', pondId);

      // Insert new schedule
      final scheduleWithMeta = {
        'pond_id': pondId,
        'schedule_data': scheduleData,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'user_id': user.id,
      };

      await supabase
          .from('feed_schedules')
          .insert(scheduleWithMeta);

      print('✅ Feed schedule saved for pond: $pondId');
    } catch (e) {
      throw Exception('Failed to save feed schedule: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFeedSchedule(String pondId) async {
    try {
      final response = await supabase
          .from('feed_schedules')
          .select('schedule_data')
          .eq('pond_id', pondId)
          .order('updated_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return [];
      }

      final scheduleData = response.first['schedule_data'] as List<dynamic>;
      return scheduleData.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to load feed schedule: $e');
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
      
      print('✅ Smart Feed status updated for pond: $pondId (enabled: $isEnabled)');
    } catch (e) {
      throw Exception('Failed to update Smart Feed status: $e');
    }
  }
}