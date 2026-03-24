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
/// 🧠 CALCULATION ENGINE
/// -----------------------------------------------------------------
class SupplementCalculator {
  const SupplementCalculator._(); // no instance

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
      final inDocRange = currentDoc >= s.startDoc && currentDoc <= s.endDoc;

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