import 'package:supabase_flutter/supabase_flutter.dart';

class FarmService {
  final supabase = Supabase.instance.client;

  Future<String> createFarm({
    required String name,
    required String location,
    required String farmType,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final response = await supabase.from('farms').insert({
      'name': name,
      'location': location,
      'farm_type': farmType,
      'user_id': user.id,
    }).select().single();

    return response['id'].toString();
  }

  Future<List<Map<String, dynamic>>> getFarmsWithPonds() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    return await supabase
        .from('farms')
        .select('*, ponds(*)')
        .eq('user_id', user.id);
  }
}