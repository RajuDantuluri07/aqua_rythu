import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/logger.dart';

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
  }
}
