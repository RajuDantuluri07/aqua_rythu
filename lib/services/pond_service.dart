import 'package:supabase_flutter/supabase_flutter.dart';

class PondService {
  final supabase = Supabase.instance.client;

  Future<void> createPond({
    required String farmId,
    required String name,
    required double area,
    required DateTime stockingDate,
    required int seedCount,
    required int plSize,
    int numTrays = 4,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await supabase.from('ponds').insert({
      'farm_id': farmId,
      'name': name,
      'area': area,
      'stocking_date': stockingDate.toIso8601String(),
      'seed_count': seedCount,
      'pl_size': plSize,
      'num_trays': numTrays,
    });
  }
}