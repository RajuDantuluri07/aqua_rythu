import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/doc_utils.dart';

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
          stocking_date
        ''').eq('is_deleted', false);

    final ponds = List<Map<String, dynamic>>.from(response);

    for (final pond in ponds) {
      final stockingDate = DateTime.parse(pond['stocking_date'] as String);
      final todayDoc = calculateDocFromStockingDate(stockingDate);
      final pondId = pond['id'] as String;

      // Read actual consumed from feed_logs (last row = running cumulative total).
      // feed_rounds.planned_amount is the engine recommendation, not what was fed —
      // using planned caused dashboard to diverge from intelligence and HomeBuilder KPIs.
      final feedRow = await supabase
          .from('feed_logs')
          .select('feed_given')
          .eq('pond_id', pondId)
          .eq('doc', todayDoc)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      pond['today_feed'] =
          (feedRow?['feed_given'] as num?)?.toDouble() ?? 0.0;
    }

    return ponds;
  }
}
