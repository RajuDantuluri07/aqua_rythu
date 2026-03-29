import 'supplement_provider.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';

/// 💧 WATER TASK ENGINE
/// Ticket ID: AQR-SUPPLEMENT-001
class WaterTask {
  final String name;
  final String timeSlot;
  final List<SupplementItem> items;
  final WaterMixTime? preferredTime;

  WaterTask({
    required this.name,
    required this.timeSlot,
    required this.items,
    this.preferredTime,
  });
}

class WaterTaskEngine {
  static List<WaterTask> generateWaterTasks({
    required DateTime today,
    required List<Supplement> plans,
  }) {
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return plans.where((p) {
      if (p.type != SupplementType.waterMix || p.date == null) return false;
      return p.isActiveOnDate(normalizedToday);
    }).expand((plan) {
      final timeSlot = plan.effectiveWaterTime ?? '';
      return [
        WaterTask(
          name: plan.name,
          timeSlot: timeSlot,
          items: plan.items,
          preferredTime: plan.preferredTime,
        ),
      ];
    }).toList();
  }
}
