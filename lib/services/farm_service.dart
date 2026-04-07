import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/pond_repository.dart';
import '../repositories/feed_repository.dart';
import '../repositories/tray_repository.dart';
import '../core/engines/smart_feed_engine.dart';

class FarmService {
  final pondRepo = PondRepository();
  final feedRepo = FeedRepository();
  final trayRepo = TrayRepository();

  /// Daily orchestration: recalculate feed for the next DOC based on
  /// current tray readings and FCR. Delegates all logic to SmartFeedEngine.
  Future<void> runDailyCycle(String pondId) async {
    await SmartFeedEngine.recalculateFeedPlan(pondId);
  }


  final supabase = Supabase.instance.client;

  Future<String> createFarm({
    required String name,
    required String location,
    String farmType = 'Aquaculture',
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final response = await supabase.from('farms').insert({
      'name': name,
      'location': location,
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

  Future<void> updateFarm({
    required String farmId,
    required String name,
    required String location,
  }) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await supabase.from('farms').update({
      'name': name,
      'location': location,
    }).eq('id', farmId).eq('user_id', user.id);
  }

  Future<void> deleteFarm(String farmId) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // First delete all ponds associated with this farm
    await supabase
        .from('ponds')
        .delete()
        .eq('farm_id', farmId);

    // Then delete the farm
    await supabase.from('farms').delete().eq('id', farmId).eq('user_id', user.id);
  }
}