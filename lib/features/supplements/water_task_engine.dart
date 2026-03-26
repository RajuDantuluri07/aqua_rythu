import 'supplement_provider.dart';

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

      final normalizedStartDate = DateTime(p.date!.year, p.date!.month, p.date!.day);
      
      if (normalizedToday.isBefore(normalizedStartDate)) return false;

      // Repeat logic
      if (p.frequencyDays != null && p.frequencyDays! > 0) {
        final diff = normalizedToday.difference(normalizedStartDate).inDays;
        return diff % p.frequencyDays! == 0;
      }

      // No repeat case: Only show on selected date
      return normalizedToday.isAtSameMomentAs(normalizedStartDate);
    }).expand((plan) {
      return plan.feedingTimes.map((time) {
        return WaterTask(
          name: plan.name,
          timeSlot: time,
          items: plan.items,
          preferredTime: plan.preferredTime,
        );
      });
    }).toList();
  }
}