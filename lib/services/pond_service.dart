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
          current_abw
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
}