import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';

/// Persists supplement plans to the `supplements` table.
/// Schema: id (text PK), user_id (uuid), data (jsonb), created_at, updated_at
class SupplementService {
  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchSupplements() async {
    final uid = _userId;
    if (uid == null) return [];

    try {
      final rows = await _supabase
          .from('supplements')
          .select('data')
          .eq('user_id', uid)
          .order('created_at', ascending: true);

      return rows
          .map<Map<String, dynamic>>(
              (r) => Map<String, dynamic>.from(r['data'] as Map))
          .toList();
    } catch (e) {
      AppLogger.error('SupplementService.fetchSupplements failed', e);
      return [];
    }
  }

  Future<void> upsertSupplement(Map<String, dynamic> supplementJson) async {
    final uid = _userId;
    if (uid == null) return;

    try {
      await _supabase.from('supplements').upsert({
        'id': supplementJson['id'],
        'user_id': uid,
        'data': supplementJson,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.error('SupplementService.upsertSupplement failed', e);
      rethrow;
    }
  }

  Future<void> deleteSupplement(String id) async {
    try {
      await _supabase.from('supplements').delete().eq('id', id);
    } catch (e) {
      AppLogger.error('SupplementService.deleteSupplement failed', e);
      rethrow;
    }
  }
}
