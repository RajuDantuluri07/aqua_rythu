import '../supplement_provider.dart';

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
  final String supplementName;
  final String itemName;
  final double totalDose;
  final String unit;

  const SupplementDoseResult({
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
  final String supplementName;
  final List<SupplementDoseResult> items;

  const SupplementGroupResult({
    required this.supplementName,
    required this.items,
  });
}

/// -----------------------------------------------------------------
/// 📦 WATER TREATMENT RESULT (UI READY)
/// -----------------------------------------------------------------
class ActiveWaterTreatment {
  final String supplementId;
  final String supplementName;
  final List<SupplementDoseResult> items;
  final WaterMixTime? preferredTime;
  final bool isOverdue;
  final bool isDueToday;
  final int scheduledDoc;
  final bool isCompleted;
  final bool isSkipped;

  const ActiveWaterTreatment({
    required this.supplementId,
    required this.supplementName,
    required this.items,
    this.preferredTime,
    this.isOverdue = false,
    this.isDueToday = false,
    required this.scheduledDoc,
    this.isCompleted = false,
    this.isSkipped = false,
  });
}

/// -----------------------------------------------------------------
/// 🧠 CALCULATION ENGINE
/// -----------------------------------------------------------------
class SupplementCalculator {
  const SupplementCalculator._(); // no instance

  /// WATER MIX ENTRY POINT
  static List<ActiveWaterTreatment> calculateWaterTreatments({
    required List<Supplement> supplements,
    required int currentDoc,
    required Map<String, String> treatmentLogs,
  }) {
    if (supplements.isEmpty) return [];

    final validSupplements = supplements.where((s) => s.type == SupplementType.waterMix).toList();
    if (validSupplements.isEmpty) return [];

    final List<ActiveWaterTreatment> treatments = [];

    for (final supplement in validSupplements) {
      if (currentDoc < supplement.startDoc) continue;

      bool isDueToday = false;
      bool isOverdue = false;

      int freq = supplement.frequencyDays != null && supplement.frequencyDays! > 0 
          ? supplement.frequencyDays! 
          : 1;

      int daysSinceStart = currentDoc - supplement.startDoc;
      int scheduledDoc = supplement.startDoc + (daysSinceStart ~/ freq) * freq;

      if (scheduledDoc == currentDoc) {
        isDueToday = true;
      } else {
        if (currentDoc > supplement.endDoc) continue;
      }

      String statusKey = "${supplement.id}_$scheduledDoc";
      bool isCompleted = treatmentLogs[statusKey] == 'applied';
      bool isSkipped = treatmentLogs[statusKey] == 'skipped';

      if (isCompleted || isSkipped) {
        if (scheduledDoc != currentDoc) continue;
      }

      if (!isDueToday && !isCompleted && !isSkipped) {
        isOverdue = true;
      }

      final List<SupplementDoseResult> itemResults = [];
      for (final item in supplement.items) {
        itemResults.add(
          SupplementDoseResult(
            supplementName: supplement.name,
            itemName: item.name,
            totalDose: _round(item.dosePerKg),
            unit: item.unit,
          ),
        );
      }

      if (itemResults.isNotEmpty) {
        treatments.add(
          ActiveWaterTreatment(
            supplementId: supplement.id,
            supplementName: supplement.name,
            items: itemResults,
            preferredTime: supplement.preferredTime,
            isDueToday: isDueToday,
            isOverdue: isOverdue,
            scheduledDoc: scheduledDoc,
            isCompleted: isCompleted,
            isSkipped: isSkipped,
          ),
        );
      }
    }

    return treatments;
  }

  /// MAIN ENTRY POINT
  static List<SupplementGroupResult> calculate({
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

    // Step 1: Filter valid supplements
    final validSupplements = supplements.where((s) {
      // This calculator is for feed-based supplements only.
      if (s.type != SupplementType.feedMix) {
        return false;
      }

      final inDocRange =
          currentDoc >= s.startDoc && currentDoc <= s.endDoc;

      final matchesTime = s.feedingTimes
          .map((e) => e.toLowerCase())
          .contains(normalizedTime);

      return inDocRange && matchesTime;
    }).toList();

    if (validSupplements.isEmpty) return [];

    // Step 2: Calculate + Group
    final List<SupplementGroupResult> groupedResults = [];

    for (final supplement in validSupplements) {
      final List<SupplementDoseResult> itemResults = [];

      for (final item in supplement.items) {
        // Normalize rate: If recipe is defined for X kg (feedQty), calculate per-kg rate first.
        // This allows farmers to enter recipes like "500ml for 10kg feed".
        final double rate = (supplement.feedQty > 0)
            ? item.dosePerKg / supplement.feedQty
            : item.dosePerKg;

        final totalDose = rate * feedQty;

        itemResults.add(
          SupplementDoseResult(
            supplementName: supplement.name,
            itemName: item.name,
            totalDose: _round(totalDose),
            unit: item.unit,
          ),
        );
      }

      // Skip empty groups (safety)
      if (itemResults.isNotEmpty) {
        groupedResults.add(
          SupplementGroupResult(
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
    return double.parse(value.toStringAsFixed(2));
  }
}