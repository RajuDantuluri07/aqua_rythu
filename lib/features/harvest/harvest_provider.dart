import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ================= MODEL =================
class HarvestEntry {
  final String id;
  final String pondId;
  final DateTime date;
  final int doc;
  final double quantity; // kg
  final int countPerKg;
  final double pricePerKg;
  final double expenses;
  final String notes;
  final String type; // partial / intermediate / final

  HarvestEntry({
    String? id,
    required this.pondId,
    required this.date,
    required this.doc,
    required this.quantity,
    required this.countPerKg,
    required this.pricePerKg,
    this.expenses = 0,
    this.notes = "",
    required this.type,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  double get revenue => quantity * pricePerKg;
  double get profit => revenue - expenses;
}

/// ================= NOTIFIER =================
class HarvestNotifier extends StateNotifier<List<HarvestEntry>> {
  final String pondId;
  final _supabase = Supabase.instance.client;

  HarvestNotifier(this.pondId) : super([]) {
    _loadHarvests();
  }

  Future<void> _loadHarvests() async {
    try {
      final data = await _supabase
          .from('harvest_logs')
          .select()
          .eq('pond_id', pondId)
          .order('created_at', ascending: false);

      final entries = (data as List).map((row) => HarvestEntry(
        id: row['id'].toString(),
        pondId: pondId,
        date: row['date'] != null
            ? DateTime.parse(row['date'])
            : DateTime.parse(row['created_at']),
        doc: row['doc'] ?? 1,
        quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
        countPerKg: row['count_per_kg'] ?? 0,
        pricePerKg: (row['price'] as num?)?.toDouble() ?? 0,
        expenses: (row['expenses'] as num?)?.toDouble() ?? 0,
        notes: row['notes'] ?? '',
        type: row['harvest_type'] ?? 'partial',
      )).toList();

      state = entries;
    } catch (e) {
      print('❌ Failed to load harvests: $e');
    }
  }

  Future<void> addHarvest(HarvestEntry entry) async {
    // Update UI immediately
    state = [...state, entry];

    // Persist to Supabase
    try {
      await _supabase.from('harvest_logs').insert({
        'pond_id': pondId,
        'harvest_type': entry.type,
        'quantity': entry.quantity,
        'price': entry.pricePerKg,
        'expenses': entry.expenses,
        'notes': entry.notes,
        'doc': entry.doc,
        'date': entry.date.toIso8601String().split('T')[0],
        'count_per_kg': entry.countPerKg,
      });
    } catch (e) {
      print('❌ Failed to save harvest: $e');
    }
  }

  void clearHarvests() {
    state = [];
  }

  double get totalHarvest => state.fold(0, (sum, h) => sum + h.quantity);
  double get totalRevenue => state.fold(0, (sum, h) => sum + h.revenue);
  double get totalExpenses => state.fold(0, (sum, h) => sum + h.expenses);
  double get totalProfit => totalRevenue - totalExpenses;
  bool get isFinalHarvestDone => state.any((h) => h.type == "final");
}

/// ================= PROVIDER =================
final harvestProvider =
    StateNotifierProvider.family<HarvestNotifier, List<HarvestEntry>, String>(
  (ref, pondId) => HarvestNotifier(pondId),
);
