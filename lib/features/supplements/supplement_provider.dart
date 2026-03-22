// lib/features/supplements/supplement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SupplementStatus { upcoming, active, completed }

/// ---------------------------------------------------
/// 📦 MODEL (Backend Ready)
/// ---------------------------------------------------

class SupplementItem {
  final String name;
  final double dosePerKg;
  final String unit;

  SupplementItem({
    required this.name,
    required this.dosePerKg,
    required this.unit,
  });
  
  // Ready for JSON serialization
  Map<String, dynamic> toJson() => {
        'name': name,
        'dosePerKg': dosePerKg,
        'unit': unit,
      };

  factory SupplementItem.fromJson(Map<String, dynamic> json) {
    return SupplementItem(
      name: json['name'],
      dosePerKg: (json['dosePerKg'] as num).toDouble(),
      unit: json['unit'],
    );
  }
}

class Supplement {
  final String id;
  final String name;
  final int startDoc;
  final int endDoc;
  final double feedQty;
  final List<String> feedingTimes;
  final List<SupplementItem> items;

  Supplement({
    required this.id,
    required this.name,
    required this.startDoc,
    required this.endDoc,
    required this.feedQty,
    required this.feedingTimes,
    required this.items,
  });

  // Helper to check status
  SupplementStatus getStatus(int currentDoc) {
    if (currentDoc < startDoc) return SupplementStatus.upcoming;
    if (currentDoc > endDoc) return SupplementStatus.completed;
    return SupplementStatus.active;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDoc': startDoc,
        'endDoc': endDoc,
        'feedQty': feedQty,
        'feedingTimes': feedingTimes,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Supplement.fromJson(Map<String, dynamic> json) {
    return Supplement(
      id: json['id'],
      name: json['name'],
      startDoc: json['startDoc'],
      endDoc: json['endDoc'],
      feedQty: (json['feedQty'] as num?)?.toDouble() ?? 1.0,
      feedingTimes: List<String>.from(json['feedingTimes']),
      items: (json['items'] as List)
          .map((e) => SupplementItem.fromJson(e))
          .toList(),
    );
  }
}

/// ---------------------------------------------------
/// 🎮 CONTROLLER / NOTIFIER
/// ---------------------------------------------------

class SupplementNotifier extends StateNotifier<List<Supplement>> {
  SupplementNotifier() : super([]);

  // 🔹 CREATE
  void addSupplement(Supplement supplement) {
    // In a real app, this would be: await repository.add(supplement);
    state = [...state, supplement]..sort((a, b) => a.startDoc.compareTo(b.startDoc));
  }

  // 🔹 UPDATE
  void editSupplement(Supplement updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s
    ]..sort((a, b) => a.startDoc.compareTo(b.startDoc));
  }

  // 🔹 DELETE
  void deleteSupplement(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

/// ---------------------------------------------------
/// 🌐 PROVIDER
/// ---------------------------------------------------

final supplementProvider =
    StateNotifierProvider<SupplementNotifier, List<Supplement>>((ref) {
  return SupplementNotifier();
});
