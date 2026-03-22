import '../supplement_provider.dart';

/// -----------------------------------------------------------------
/// 📦 RESULT MODEL
/// -----------------------------------------------------------------
class SupplementDoseResult {
  final String supplementName;
  final String itemName;
  final double totalDose;
  final double dosePerTray;
  final String unit;

  const SupplementDoseResult({
    required this.supplementName,
    required this.itemName,
    required this.totalDose,
    required this.dosePerTray,
    required this.unit,
  });

  @override
  String toString() {
    return '$supplementName → $itemName: '
        '${totalDose.toStringAsFixed(2)} $unit '
        '(Tray: ${dosePerTray.toStringAsFixed(2)} $unit)';
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
    int trayCount = 4,
  }) {
    // 🔒 Safety checks
    if (supplements.isEmpty || feedQty <= 0 || trayCount <= 0) {
      return [];
    }

    // Normalize feeding time once
    final normalizedTime = currentFeedingTime.toLowerCase();

    // Step 1: Filter valid supplements
    final validSupplements = supplements.where((s) {
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
        final dosePerTray = totalDose / trayCount;

        itemResults.add(
          SupplementDoseResult(
            supplementName: supplement.name,
            itemName: item.name,
            totalDose: _round(totalDose),
            dosePerTray: _round(dosePerTray),
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