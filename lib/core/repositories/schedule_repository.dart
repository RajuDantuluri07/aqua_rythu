import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supplement_schedule.dart';
import '../models/supplement_schedule_log.dart';

class ScheduleRepository {
  final _supabase = Supabase.instance.client;

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
    } catch (_) {
      return [];
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
    } catch (_) {
      return [];
    }
  }

  Future<SupplementSchedule?> insertSchedule(SupplementSchedule schedule) async {
    try {
      final now = DateTime.now();
      final data = schedule.toJson()
        ..remove('id')
        ..['created_at'] = now.toIso8601String()
        ..['updated_at'] = now.toIso8601String();

      final response = await _supabase
          .from('supplement_schedules')
          .insert(data)
          .select()
          .maybeSingle();

      if (response == null) return null;
      return SupplementSchedule.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<SupplementSchedule?> updateSchedule(SupplementSchedule schedule) async {
    try {
      final data = schedule.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('supplement_schedules')
          .update(data)
          .eq('id', schedule.id)
          .select()
          .maybeSingle();

      if (response == null) return null;
      return SupplementSchedule.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateScheduleStatus(String id, String status) async {
    try {
      await _supabase
          .from('supplement_schedules')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (_) {
      // Silent error handling
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _supabase.from('supplement_schedules').delete().eq('id', id);
    } catch (_) {
      // Silent error handling
    }
  }

  Future<SupplementScheduleLog?> insertLog(SupplementScheduleLog log) async {
    try {
      final now = DateTime.now();
      final data = log.toJson()
        ..remove('id')
        ..['created_at'] = now.toIso8601String();

      final response = await _supabase
          .from('supplement_schedule_logs')
          .insert(data)
          .select()
          .maybeSingle();

      if (response == null) return null;
      return SupplementScheduleLog.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
