import 'package:supabase_flutter/supabase_flutter.dart';

class SamplingService {
  final supabase = Supabase.instance.client;

  Future<void> addSampling({
    required String pondId,
    required DateTime date,
    required int doc,
    required double weightKg,
    required int totalPieces,
    required double averageBodyWeight,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // 1. Insert sampling log
    await supabase.from('sampling_logs').insert({
      'pond_id': pondId,
      'date': date.toIso8601String(),
      'doc': doc,
      'weight_kg': weightKg,
      'count_groups': 1,
      'pieces_per_group': totalPieces,
      'total_pieces': totalPieces,
      'average_body_weight': averageBodyWeight,
    });

    // 2. Update pond (VERY IMPORTANT)
    await supabase.from('ponds').update({
      'current_abw': averageBodyWeight,
      'last_sampling_doc': doc,
    }).eq('id', pondId);
  }
}