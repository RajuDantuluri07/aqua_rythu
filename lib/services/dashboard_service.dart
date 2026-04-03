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
          feed_rounds (
            doc,
            feed_amount
          )
        ''').eq('is_deleted', false);

    final ponds = List<Map<String, dynamic>>.from(response);

    for (final pond in ponds) {
      final feedRounds = pond['feed_rounds'] as List?;
      
      if (feedRounds != null && feedRounds.isNotEmpty) {
        // Calculate today's DOC
        final stockingDate = DateTime.parse(pond['stocking_date'] as String);
        final todayDoc = DateTime.now().difference(stockingDate).inDays + 1;
        
        // Calculate today's total feed from rounds
        final todayTotal = feedRounds
            .where((r) => r['doc'] == todayDoc)
            .fold(0.0, (sum, r) => sum + ((r['feed_amount'] as num?)?.toDouble() ?? 0.0));

        pond['today_feed'] = todayTotal;
      } else {
        pond['today_feed'] = 0;
      }
    }

    return ponds;
  }
}