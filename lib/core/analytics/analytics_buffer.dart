import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Offline-safe analytics queue backed by SharedPreferences.
// Events that fail to write to Supabase are enqueued here and drained on the
// next successful network opportunity (app start or resume).
class AnalyticsBuffer {
  static const _key = 'analytics_offline_queue';
  static const _maxQueueSize = 500; // cap to prevent unbounded growth

  static Future<void> enqueue(
    SharedPreferences prefs,
    Map<String, dynamic> event,
  ) async {
    try {
      final raw = prefs.getStringList(_key) ?? [];
      if (raw.length >= _maxQueueSize) raw.removeAt(0); // drop oldest on overflow
      raw.add(jsonEncode(event));
      await prefs.setStringList(_key, raw);
    } catch (_) {}
  }

  static Future<void> drain(
    SharedPreferences prefs,
    SupabaseClient client,
  ) async {
    try {
      final raw = prefs.getStringList(_key);
      if (raw == null || raw.isEmpty) return;

      final rows = raw
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (rows.isEmpty) {
        await prefs.remove(_key);
        return;
      }

      await client.from('analytics_events').insert(rows);
      await prefs.remove(_key);
    } catch (_) {
      // Leave queue intact — will retry on next drain
    }
  }

  static Future<int> queueLength(SharedPreferences prefs) async {
    return (prefs.getStringList(_key) ?? []).length;
  }
}
