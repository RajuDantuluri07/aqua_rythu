import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for pond data — Supabase queries only, no business logic.
class PondRepository {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getPond(String pondId) async {
    return await _supabase
        .from('ponds')
        .select('id, seed_count, stocking_date, current_abw, area, num_trays, status, is_smart_feed_enabled, initial_feed_rounds, post_week_feed_rounds, is_custom_feed_plan')
        .eq('id', pondId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getPondsByFarm(String farmId) async {
    return await _supabase
        .from('ponds')
        .select('id, name, area, stocking_date, seed_count, pl_size, num_trays, status, current_abw, is_smart_feed_enabled, initial_feed_rounds, post_week_feed_rounds, is_custom_feed_plan')
        .eq('farm_id', farmId)
        .order('created_at', ascending: false);
  }

  Future<void> updateAbw(String pondId, double abwGrams) async {
    await _supabase
        .from('ponds')
        .update({'current_abw': abwGrams, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', pondId);
  }
}
