import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ================= MODEL =================
class HarvestEntry {
  final String pondId;
  final DateTime date;
  final int doc;
  final double quantity; // kg
  final int countPerKg;
  final double pricePerKg;
  final String type;     // partial / intermediate / final

  HarvestEntry({
    required this.pondId,
    required this.date,
    required this.doc,
    required this.quantity,
    required this.countPerKg,
    required this.pricePerKg,
    required this.type,
  });

  double get revenue => quantity * pricePerKg;
}

/// ================= NOTIFIER =================
class HarvestNotifier extends StateNotifier<List<HarvestEntry>> {
  HarvestNotifier() : super([]);

  /// ➕ ADD HARVEST
  void addHarvest(HarvestEntry entry) {
    state = [...state, entry];
  }

  /// 📊 TOTAL HARVEST
  double get totalHarvest =>
      state.fold(0, (sum, h) => sum + h.quantity);

  /// 💰 TOTAL REVENUE
  double get totalRevenue =>
      state.fold(0, (sum, h) => sum + h.revenue);

  /// 🏁 FINAL HARVEST DONE?
  bool get isFinalHarvestDone =>
      state.any((h) => h.type == "final");
}

/// ================= PROVIDER =================
final harvestProvider =
    StateNotifierProvider.family<HarvestNotifier, List<HarvestEntry>, String>(
  (ref, pondId) => HarvestNotifier(), // Notifier doesn't strictly need ID if entry has it
);