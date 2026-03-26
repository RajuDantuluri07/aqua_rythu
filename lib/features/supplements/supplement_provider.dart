// lib/features/supplements/supplement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SupplementStatus { upcoming, active, completed }

enum SupplementType {
  feedMix,
  waterMix,
}

enum SupplementGoal {
  growthBoost,
  diseasePrevention,
  waterCorrection,
  stressRecovery,
}

enum WaterMixTime {
  morning,
  evening,
  afterFeed,
}

/// ---------------------------------------------------
/// 📦 MODEL (Backend Ready)
/// ---------------------------------------------------

/// Ticket ID: AQR-SUPPLEMENT-001
/// Runtime result for UI display
class CalculatedItem {
  final String name;
  final double quantity;
  final String unit;

  const CalculatedItem({required this.name, required this.quantity, required this.unit});
}

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
  final SupplementType type;
  final SupplementGoal? goal;

  final List<String> pondIds;

  /// FEED MIX ONLY
  final double feedQty; // default 0 if waterMix
  final List<String> feedingTimes; // Represents "timeSlots" (R1, R2, etc)

  /// WATER MIX ONLY
  final int? frequencyDays; // Maps to repeatIntervalDays
  final WaterMixTime? preferredTime;
  final DateTime? date; // Start date for water tasks
  
  final List<SupplementItem> items;
  final String notes;

  Supplement({
    required this.id,
    required this.name,
    required this.startDoc,
    required this.endDoc,
    this.type = SupplementType.feedMix,
    this.goal,
    this.pondIds = const [],
    this.feedQty = 0.0,
    this.feedingTimes = const [],
    this.frequencyDays,
    this.preferredTime,
    this.date,
    required this.items,
    this.notes = '',
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
        'type': type.name,
        'goal': goal?.name,
        'pondIds': pondIds,
        'feedQty': feedQty,
        'feedingTimes': feedingTimes,
        'frequencyDays': frequencyDays,
        'preferredTime': preferredTime?.name,
        'date': date?.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'notes': notes,
      };

  factory Supplement.fromJson(Map<String, dynamic> json) {
    return Supplement(
      id: json['id'],
      name: json['name'],
      startDoc: json['startDoc'],
      endDoc: json['endDoc'],
      type: json['type'] != null
          ? SupplementType.values.byName(json['type'])
          : SupplementType.feedMix,
      goal: json['goal'] != null
          ? SupplementGoal.values.byName(json['goal'])
          : null,
      pondIds: List<String>.from(json['pondIds'] ?? []),
      feedQty: (json['feedQty'] as num?)?.toDouble() ?? 0.0,
      feedingTimes: List<String>.from(json['feedingTimes'] ?? []),
      frequencyDays: json['frequencyDays'],
      preferredTime: json['preferredTime'] != null
          ? WaterMixTime.values.byName(json['preferredTime'])
          : null,
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      items: (json['items'] as List)
          .map((e) => SupplementItem.fromJson(e))
          .toList(),
      notes: json['notes'] ?? '',
    );
  }
}

/// ---------------------------------------------------
/// 📦 LOG MODEL (History Tracking)
/// ---------------------------------------------------
class SupplementLog {
  final String id;
  final String supplementId;
  final String pondId;
  final DateTime timestamp;
  final List<CalculatedItem> appliedItems;

  SupplementLog({
    required this.id,
    required this.supplementId,
    required this.pondId,
    required this.timestamp,
    required this.appliedItems,
  });
}

class SupplementLogNotifier extends StateNotifier<List<SupplementLog>> {
  SupplementLogNotifier() : super([]);

  void logApplication({
    required String supplementId,
    required String pondId,
    required List<CalculatedItem> items,
  }) {
    final log = SupplementLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supplementId: supplementId,
      pondId: pondId,
      timestamp: DateTime.now(),
      appliedItems: items,
    );
    state = [...state, log];
  }
}

final supplementLogProvider =
    StateNotifierProvider<SupplementLogNotifier, List<SupplementLog>>((ref) {
  return SupplementLogNotifier();
});

/// ---------------------------------------------------
/// 🎮 CONTROLLER / NOTIFIER
/// ---------------------------------------------------

class SupplementNotifier extends StateNotifier<List<Supplement>> {
  SupplementNotifier() : super([]);

  List<Supplement> getByPond(String pondId) {
    return state.where((e) => e.pondIds.contains(pondId) || e.pondIds.contains('ALL')).toList();
  }

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
