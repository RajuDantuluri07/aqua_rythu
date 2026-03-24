import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ================= MODEL =================
class HarvestEntry {
  final String pondId;
  final DateTime date;
  final int doc;
  final double quantity; // kg
  final int countPerKg;
  final double pricePerKg;
  final double expenses;
  final String notes;
  final String type;     // partial / intermediate / final

  HarvestEntry({
    required this.pondId,
    required this.date,
    required this.doc,
    required this.quantity,
    required this.countPerKg,
    required this.pricePerKg,
    this.expenses = 0,
    this.notes = "",
    required this.type,
  });

  double get revenue => quantity * pricePerKg;
  double get profit => revenue - expenses;
}

/// ================= NOTIFIER =================
class HarvestNotifier extends StateNotifier<List<HarvestEntry>> {
  HarvestNotifier() : super([]);

  /// ➕ ADD HARVEST
  void addHarvest(HarvestEntry entry) {
    state = [...state, entry];
  }

  /// 🧹 RESET HARVESTS (New Cycle)
  void clearHarvests() {
    state = [];
  }

  /// 📊 TOTAL HARVEST
  double get totalHarvest =>
      state.fold(0, (sum, h) => sum + h.quantity);

  /// 💰 TOTAL REVENUE
  double get totalRevenue =>
      state.fold(0, (sum, h) => sum + h.revenue);

  /// 💸 TOTAL EXPENSES
  double get totalExpenses =>
      state.fold(0, (sum, h) => sum + h.expenses);

  /// 💰 TOTAL PROFIT
  double get totalProfit => totalRevenue - totalExpenses;

  /// 🏁 FINAL HARVEST DONE?
  bool get isFinalHarvestDone =>
      state.any((h) => h.type == "final");
}

/// ================= PROVIDER =================
final harvestProvider =
    StateNotifierProvider.family<HarvestNotifier, List<HarvestEntry>, String>(
  (ref, pondId) => HarvestNotifier(), // Notifier doesn't strictly need ID if entry has it
);