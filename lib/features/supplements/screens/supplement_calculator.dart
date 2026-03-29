import '../supplement_provider.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';

/// -----------------------------------------------------------------
/// 📦 FRD ALIGNED MODELS
/// -----------------------------------------------------------------

class ActiveFeedSupplement {
  final Map<String, double> items;
  final bool mandatory;

  const ActiveFeedSupplement({
    required this.items,
    this.mandatory = true,
  });
}

/// -----------------------------------------------------------------
/// 📦 RESULT MODEL
/// -----------------------------------------------------------------
class SupplementDoseResult {
  final String supplementId;
  final String supplementName;
  final String itemName;
  final double totalDose;
  final String unit;

  const SupplementDoseResult({
    required this.supplementId,
    required this.supplementName,
    required this.itemName,
    required this.totalDose,
    required this.unit,
  });

  @override
  String toString() {
    return '$supplementName → $itemName: '
        '${totalDose.toStringAsFixed(2)} $unit';
  }
}

/// -----------------------------------------------------------------
/// 📦 GROUPED RESULT (UI READY)
/// -----------------------------------------------------------------
class SupplementGroupResult {
  final String supplementId;
  final String supplementName;
  final List<SupplementDoseResult> items;

  const SupplementGroupResult({
    required this.supplementId,
    required this.supplementName,
    required this.items,
  });
}

/// -----------------------------------------------------------------
/// 🧠 CALCULATION ENGINE
/// -----------------------------------------------------------------
class SupplementCalculator {
  const SupplementCalculator._(); // no instance

  /// CORE CALCULATION ENGINE (SINGLE SOURCE OF TRUTH)
  static List<SupplementItem> calculate({
    required List<SupplementItem> items,
    required double feedKg,
  }) {
    return items.map((item) {
      final calculatedDose = item.quantity * feedKg;
      return SupplementItem(
        name: item.name,
        quantity: calculatedDose,
        unit: item.unit,
        type: item.type,
      );
    }).toList();
  }

  /// ADVANCED ENTRY POINT (Used by Dashboard)
  static List<SupplementGroupResult> calculateActive({
    required List<Supplement> supplements,
    required int currentDoc,
    required String currentFeedingTime,
    required double feedQty,
  }) {
    // 🔒 Safety checks
    if (supplements.isEmpty || feedQty <= 0) {
      return [];
    }

    // Normalize feeding time once
    final normalizedTime = currentFeedingTime.toLowerCase();
    final today = DateTime.now();

    // Step 1: Filter valid supplements
    final validSupplements = supplements.where((s) {
      final inDocRange = s.type == SupplementType.feedMix &&
          currentDoc >= s.startDoc &&
          currentDoc <= s.endDoc;
      final matchesSchedule = s.isActiveOnDate(today) || inDocRange;
      if (s.isPaused) return false;

      final matchesTime =
          s.feedingTimes.map((e) => e.toLowerCase()).contains(normalizedTime);

      return matchesSchedule && matchesTime;
    }).toList();

    if (validSupplements.isEmpty) return [];

    // Step 2: Calculate + Group
    final List<SupplementGroupResult> groupedResults = [];

    for (final supplement in validSupplements) {
      final appliedItems = supplement.calculateAppliedItems(feedKg: feedQty);
      final List<SupplementDoseResult> itemResults = appliedItems
          .map((item) => SupplementDoseResult(
                supplementId: supplement.id,
                supplementName: supplement.name,
                itemName: item.name,
                totalDose: _round(item.quantity),
                unit: item.unit,
              ))
          .toList();

      // Skip empty groups (safety)
      if (itemResults.isNotEmpty) {
        groupedResults.add(
          SupplementGroupResult(
            supplementId: supplement.id,
            supplementName: supplement.name,
            items: itemResults,
          ),
        );
      }
    }

    return groupedResults;
  }

  /// WATER CALCULATION ENTRY POINT
  static List<SupplementGroupResult> calculateWater({
    required List<Supplement> supplements,
    required int currentDoc,
    required double pondArea, // in acres
    String? currentTimeSlot,
  }) {
    if (supplements.isEmpty || pondArea <= 0) {
      return [];
    }

    final validSupplements = supplements.where((s) {
      if (s.type != SupplementType.waterMix) return false;
      if (s.isPaused) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      bool isScheduledForToday = true;
      if (s.date != null) {
        final startDate = DateTime(s.date!.year, s.date!.month, s.date!.day);
        if (today.isBefore(startDate)) {
          isScheduledForToday = false;
        } else if (s.frequencyDays != null && s.frequencyDays! > 0) {
          final diff = today.difference(startDate).inDays;
          isScheduledForToday = diff % s.frequencyDays! == 0;
        } else {
          isScheduledForToday = today.isAtSameMomentAs(startDate);
        }
      }

      bool matchesTime = true;
      final waterTime = s.effectiveWaterTime;
      if (currentTimeSlot != null && waterTime != null && waterTime.isNotEmpty) {
        matchesTime = waterTime.toLowerCase() == currentTimeSlot.toLowerCase();
      }

      return isScheduledForToday && matchesTime;
    }).toList();

    if (validSupplements.isEmpty) return [];

    final List<SupplementGroupResult> groupedResults = [];

    for (final supplement in validSupplements) {
      final appliedItems = supplement.calculateAppliedItems(pondArea: pondArea);
      final List<SupplementDoseResult> itemResults = appliedItems
          .map((item) => SupplementDoseResult(
                supplementId: supplement.id,
                supplementName: supplement.name,
                itemName: item.name,
                totalDose: _round(item.quantity),
                unit: item.unit,
              ))
          .toList();

      if (itemResults.isNotEmpty) {
        groupedResults.add(
          SupplementGroupResult(
            supplementId: supplement.id,
            supplementName: supplement.name,
            items: itemResults,
          ),
        );
      }
    }

    return groupedResults;
  }

  /// -----------------------------------------------------------------
  /// 🔧 HELPERS
  /// -----------------------------------------------------------------

  /// Round to 2 decimal places (consistent UI + calculation)
  static double _round(double value) {
    if (value.isInfinite || value.isNaN) return 0.0;
    return (value * 100).round() / 100.0;
  }
}
