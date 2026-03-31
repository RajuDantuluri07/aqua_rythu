import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPonds() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    final response = await supabase.from('ponds').select('''
          id,
          name,
          area,
          num_trays,
          current_abw,
          stocking_date,
          feed_history_logs (
            date,
            expected_feed,
            rounds
          )
        ''').eq('is_deleted', false);

    final ponds = List<Map<String, dynamic>>.from(response);

    for (final pond in ponds) {
      final feeds = pond['feed_history_logs'] as List?;

      if (feeds != null && feeds.isNotEmpty) {
        feeds.sort((a, b) {
          final dateA = DateTime.parse(a['date'] as String);
          final dateB = DateTime.parse(b['date'] as String);
          return dateA.compareTo(dateB);
        });
      }

      final latestFeed = (feeds != null && feeds.isNotEmpty) ? feeds.last : null;
      pond['today_feed'] = latestFeed?['expected_feed'] ?? 0;
    }

    return ponds;
  }
}