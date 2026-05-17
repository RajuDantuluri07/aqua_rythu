import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'analytics_service.dart';

class SamplingService {
  final _supabase = Supabase.instance.client;

  Future<void> addSampling({
    required String pondId,
    required DateTime date,
    required int doc,
    required double weightKg,
    required int totalPieces,
    required double averageBodyWeight,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Deduplicate: skip insert if a sampling log already exists for this
    // pond+doc today. Protects against double-tap and network retries.
    final today = date.toIso8601String().split('T')[0];
    final existing = await _supabase
        .from('sampling_logs')
        .select('id')
        .eq('pond_id', pondId)
        .eq('doc', doc)
        .gte('created_at', '${today}T00:00:00')
        .lt('created_at', '${today}T23:59:59.999')
        .limit(1);

    if (existing.isNotEmpty) {
      AppLogger.warn(
          'SamplingService: duplicate skipped for pond $pondId DOC $doc');
      // Still update the pond ABW cache so the engine sees the latest value.
      await _supabase.from('ponds').update({
        'current_abw': averageBodyWeight,
        'latest_sample_date': date.toIso8601String(),
      }).eq('id', pondId);
      return;
    }

    // 1. Insert sampling log
    await _supabase.from('sampling_logs').insert({
      'pond_id': pondId,
      'doc': doc,
      'avg_weight': averageBodyWeight,
      'count': totalPieces,
      'created_at': date.toIso8601String(),
    });

    // 2. Update pond ABW cache — read by engine without extra DB hit (fix #5)
    await _supabase.from('ponds').update({
      'current_abw': averageBodyWeight,
      'latest_sample_date': date.toIso8601String(),
    }).eq('id', pondId);

    AppLogger.info(
      'SamplingService.addSampling: pond $pondId DOC $doc ABW ${averageBodyWeight.toStringAsFixed(1)}g',
    );
    unawaited(AnalyticsService.instance.logSamplingAdded(
      pondId: pondId, doc: doc, abwG: averageBodyWeight,
    ));
  }

  Future<List<Map<String, dynamic>>> fetchSamplings(String pondId) async {
    final result = await _supabase
        .from('sampling_logs')
        .select('*')
        .eq('pond_id', pondId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }
}
