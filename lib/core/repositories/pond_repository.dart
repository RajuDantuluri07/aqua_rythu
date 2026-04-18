import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for pond data — Supabase queries only, no business logic.
class PondRepository {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getPond(String pondId) async {
    try {
      return await _supabase
          .from('ponds')
          .select('id, seed_count, stocking_date, current_abw, area, num_trays, status, is_smart_feed_enabled, initial_feed_rounds, post_week_feed_rounds, is_custom_feed_plan')
          .eq('id', pondId)
          .maybeSingle();
    } catch (e) {
      debugPrint('PondRepository.getPond error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPondsByFarm(String farmId) async {
    try {
      return await _supabase
          .from('ponds')
          .select('id, name, area, stocking_date, seed_count, pl_size, num_trays, status, current_abw, is_smart_feed_enabled, initial_feed_rounds, post_week_feed_rounds, is_custom_feed_plan')
          .eq('farm_id', farmId)
          .order('created_at', ascending: false);
    } catch (e) {
      debugPrint('PondRepository.getPondsByFarm error: $e');
      return [];
    }
  }

  Future<void> updateAbw(String pondId, double abwGrams) async {
    try {
      await _supabase
          .from('ponds')
          .update({'current_abw': abwGrams})
          .eq('id', pondId);
    } catch (e) {
      debugPrint('PondRepository.updateAbw error: $e');
    }
  }
}
