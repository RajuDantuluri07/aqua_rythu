import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supplement_schedule.dart';
import '../models/supplement_schedule_log.dart';
import '../utils/logger.dart';

class ScheduleRepository {
  final _supabase = Supabase.instance.client;

  // ── Schedules ────────────────────────────────────────────────────────────

  Future<List<SupplementSchedule>> fetchSchedulesByPond(String pondId) async {
    try {
      final response = await _supabase
          .from('supplement_schedules')
          .select()
          .eq('pond_id', pondId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupplementSchedule.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('ScheduleRepository.fetchSchedulesByPond failed: $e');
      rethrow;
    }
  }

  Future<List<SupplementSchedule>> fetchActiveSchedulesByPond(String pondId) async {
    try {
      final response = await _supabase
          .from('supplement_schedules')
          .select()
          .eq('pond_id', pondId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupplementSchedule.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('ScheduleRepository.fetchActiveSchedulesByPond failed: $e');
      rethrow;
    }
  }

  Future<SupplementSchedule> insertSchedule(SupplementSchedule schedule) async {
    final now = DateTime.now();
    final data = schedule.toJson()
      ..remove('id')
      ..['created_at'] = now.toIso8601String()
      ..['updated_at'] = now.toIso8601String();

    final response = await _supabase
        .from('supplement_schedules')
        .insert(data)
        .select()
        .single();

    return SupplementSchedule.fromJson(response);
  }

  Future<SupplementSchedule> updateSchedule(SupplementSchedule schedule) async {
    final data = schedule.toJson();
    data['updated_at'] = DateTime.now().toIso8601String();
    // Never overwrite created_at — the DB holds the authoritative value.
    data.remove('id');
    data.remove('created_at');

    final response = await _supabase
        .from('supplement_schedules')
        .update(data)
        .eq('id', schedule.id)
        .select()
        .single();

    return SupplementSchedule.fromJson(response);
  }

  Future<void> updateScheduleStatus(String id, String status) async {
    await _supabase
        .from('supplement_schedules')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> deleteSchedule(String id) async {
    await _supabase.from('supplement_schedules').delete().eq('id', id);
  }

  // ── Application Logs ─────────────────────────────────────────────────────

  Future<List<SupplementScheduleLog>> fetchLogsByPond(
    String pondId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('supplement_schedule_logs')
          .select()
          .eq('pond_id', pondId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => SupplementScheduleLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('ScheduleRepository.fetchLogsByPond failed: $e');
      rethrow;
    }
  }

  Future<SupplementScheduleLog> insertLog(SupplementScheduleLog log) async {
    final now = DateTime.now();
    final data = log.toJson()
      ..remove('id')
      ..['created_at'] = now.toIso8601String();

    final response = await _supabase
        .from('supplement_schedule_logs')
        .insert(data)
        .select()
        .single();

    return SupplementScheduleLog.fromJson(response);
  }
}
