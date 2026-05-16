import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/pond_repository.dart';
import '../repositories/feed_repository.dart';
import '../repositories/tray_repository.dart';
import '../../features/pond/controllers/pond_dashboard_controller.dart';

class FarmService {
  final pondRepo = PondRepository();
  final feedRepo = LocalFeedRepository();
  final trayRepo = TrayRepository();

  /// Daily orchestration: recalculate feed for the next DOC.
  Future<void> runDailyCycle(String pondId) async {
    // Use proper controller instead of deprecated FeedService
    await pondDashboardController.load(pondId);
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

    try {
      final response = await supabase
          .from('farms')
          .insert({
            'name': name,
            'location': location,
            'user_id': user.id,
          })
          .select()
          .single();

      return response['id'].toString();
    } catch (e) {
      throw Exception('Failed to create farm: $e');
    }
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

    await supabase
        .from('farms')
        .update({
          'name': name,
          'location': location,
        })
        .eq('id', farmId)
        .eq('user_id', user.id);
  }

  Future<void> deleteFarm(String farmId) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    // Single DB transaction via RPC — atomically deletes all pond children,
    // expenses, ponds, and the farm itself.
    await supabase.rpc('delete_farm_cascade', params: {
      'p_farm_id': farmId,
      'p_user_id': user.id,
    });
  }
}
