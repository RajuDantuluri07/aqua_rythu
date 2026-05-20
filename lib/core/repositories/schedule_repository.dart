import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supplement_schedule.dart';
import '../models/supplement_schedule_log.dart';
import '../utils/logger.dart';

class ScheduleRepository {
  final _supabase = Supabase.instance.client;

  // ── Schedules ────────────────────────────────────────────────────────────

  Future<List<SupplementSchedule>> fetchSchedulesByPond(
    String pondId, {
    String? farmId,
  }) async {
    try {
      // Q1: schedules explicitly targeting this pond (current_pond type)
      final q1 = await _supabase
          .from('supplement_schedules')
          .select()
          .eq('pond_id', pondId)
          .order('created_at', ascending: false);

      // Q2: farm-wide (all_ponds) and multi-pond (selected_ponds) schedules.
      // RLS already scopes these to farms the user belongs to.
      // Optional farmId filter prevents showing another farm's "all ponds"
      // schedules when a user is a member of multiple farms.
      var q2Builder = _supabase
          .from('supplement_schedules')
          .select()
          .inFilter('target_type', ['all_ponds', 'selected_ponds'])
          .neq('pond_id', pondId); // exclude duplicates already in q1
      if (farmId != null && farmId.isNotEmpty) {
        q2Builder = q2Builder.eq('farm_id', farmId);
      }
      final q2 = await q2Builder.order('created_at', ascending: false);

      final seen = <String>{};
      final all = [
        ...(q1 as List).map((j) => SupplementSchedule.fromJson(j as Map<String, dynamic>)),
        ...(q2 as List).map((j) => SupplementSchedule.fromJson(j as Map<String, dynamic>)),
      ];
      return all
          .where((s) => seen.add(s.id) && s.appliesToPond(pondId))
          .toList();
    } catch (e) {
      AppLogger.error('ScheduleRepository.fetchSchedulesByPond failed: $e');
      rethrow;
    }
  }

  Future<List<SupplementSchedule>> fetchActiveSchedulesByPond(
    String pondId, {
    String? farmId,
  }) async {
    try {
      final q1 = await _supabase
          .from('supplement_schedules')
          .select()
          .eq('pond_id', pondId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      var q2Builder = _supabase
          .from('supplement_schedules')
          .select()
          .eq('status', 'active')
          .inFilter('target_type', ['all_ponds', 'selected_ponds'])
          .neq('pond_id', pondId);
      if (farmId != null && farmId.isNotEmpty) {
        q2Builder = q2Builder.eq('farm_id', farmId);
      }
      final q2 = await q2Builder.order('created_at', ascending: false);

      final seen = <String>{};
      final all = [
        ...(q1 as List).map((j) => SupplementSchedule.fromJson(j as Map<String, dynamic>)),
        ...(q2 as List).map((j) => SupplementSchedule.fromJson(j as Map<String, dynamic>)),
      ];
      return all
          .where((s) => seen.add(s.id) && s.appliesToPond(pondId))
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
