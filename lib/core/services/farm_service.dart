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

    // Fetch all pond IDs for this farm so their children can be cleaned up.
    final pondRows = await supabase
        .from('ponds')
        .select('id')
        .eq('farm_id', farmId);

    // Delete child data for every pond sequentially before removing the ponds.
    for (final pond in pondRows) {
      final pondId = pond['id'] as String;
      await supabase.from('feed_rounds').delete().eq('pond_id', pondId);
      await supabase.from('feed_logs').delete().eq('pond_id', pondId);
      await supabase.from('tray_logs').delete().eq('pond_id', pondId);
      await supabase.from('sampling_logs').delete().eq('pond_id', pondId);
      await supabase.from('water_logs').delete().eq('pond_id', pondId);
      await supabase.from('harvest_logs').delete().eq('pond_id', pondId);
    }

    // Delete farm-level expenses (not tied to a specific pond).
    await supabase.from('expenses').delete().eq('farm_id', farmId);

    // Now it is safe to delete the ponds and then the farm.
    await supabase.from('ponds').delete().eq('farm_id', farmId);
    await supabase
        .from('farms')
        .delete()
        .eq('id', farmId)
        .eq('user_id', user.id);
  }
}
