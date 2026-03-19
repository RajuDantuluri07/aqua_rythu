import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ================= MODEL =================
class HarvestEntry {
  final int doc;
  final double quantity; // kg
  final String type;     // partial / intermediate / final

  HarvestEntry({
    required this.doc,
    required this.quantity,
    required this.type,
  });
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

  /// 🏁 FINAL HARVEST DONE?
  bool get isFinalHarvestDone =>
      state.any((h) => h.type == "final");
}

/// ================= PROVIDER =================
final harvestProvider =
    StateNotifierProvider.family<HarvestNotifier, List<HarvestEntry>, String>(
  (ref, pondId) => HarvestNotifier(),
);