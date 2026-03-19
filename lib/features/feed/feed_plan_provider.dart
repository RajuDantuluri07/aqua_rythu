import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import '../pond/feed_plan_generator.dart';

final todayFeedProvider = Provider.family<double, String>((ref, pondId) {
  final farmState = ref.watch(farmProvider);
  
  // Find the pond object to get seedCount and stockingDate
  Pond? pond;
  for (var farm in farmState.farms) {
    try {
      pond = farm.ponds.firstWhere((p) => p.id == pondId);
      break;
    } catch (_) {}
  }

  if (pond == null) return 0;

  final doc = pond.doc;
  
  // Generate plan (Assuming 60 days blind feeding phase)
  final plan = FeedPlanGenerator.generate(plCount: pond.seedCount, durationDays: 60);

  if (doc <= 0 || doc > plan.length) return 0;

  return plan[doc - 1].totalFeed;
});