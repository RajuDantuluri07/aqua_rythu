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
          feed_plans (
            doc,
            r1,
            r2,
            r3,
            r4,
            total
          )
        ''').eq('is_deleted', false);

    final ponds = List<Map<String, dynamic>>.from(response);

    for (final pond in ponds) {
      final feedPlans = pond['feed_plans'] as List?;
      
      if (feedPlans != null && feedPlans.isNotEmpty) {
        // Calculate today's DOC
        final stockingDate = DateTime.parse(pond['stocking_date'] as String);
        final todayDoc = DateTime.now().difference(stockingDate).inDays + 1;
        
        // Find today's feed plan
        final todayPlan = feedPlans.firstWhere(
          (plan) => (plan['doc'] as int) == todayDoc,
          orElse: () => {'total': 0},
        );
        
        pond['today_feed'] = todayPlan['total'] ?? 0;
      } else {
        pond['today_feed'] = 0;
      }
    }

    return ponds;
  }
}