// lib/features/supplements/supplement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';

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
  final bool isPaused;

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
    this.isPaused = false,
  });

  Supplement copyWith({
    String? id,
    String? name,
    int? startDoc,
    int? endDoc,
    SupplementType? type,
    SupplementGoal? goal,
    List<String>? pondIds,
    double? feedQty,
    List<String>? feedingTimes,
    int? frequencyDays,
    WaterMixTime? preferredTime,
    DateTime? date,
    List<SupplementItem>? items,
    String? notes,
    bool? isPaused,
  }) {
    return Supplement(
      id: id ?? this.id,
      name: name ?? this.name,
      startDoc: startDoc ?? this.startDoc,
      endDoc: endDoc ?? this.endDoc,
      type: type ?? this.type,
      goal: goal ?? this.goal,
      pondIds: pondIds ?? this.pondIds,
      feedQty: feedQty ?? this.feedQty,
      feedingTimes: feedingTimes ?? this.feedingTimes,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      preferredTime: preferredTime ?? this.preferredTime,
      date: date ?? this.date,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  // Helper to check status
  SupplementStatus getStatus(int currentDoc) {
    if (currentDoc < startDoc) return SupplementStatus.upcoming;
    if (currentDoc > endDoc) return SupplementStatus.completed;
    return SupplementStatus.active;
  }

  List<SupplementItem> calculateDosage(double feedKg) {
    if (type != SupplementType.feedMix) return [];
    if (feedQty <= 0) {
      return items.map((item) => item).toList();
    }

    return items.map((item) {
      final rate = item.quantity / feedQty;
      return SupplementItem(
        id: item.id,
        name: item.name,
        quantity: rate * feedKg,
        unit: item.unit,
        type: item.type,
        isMandatory: item.isMandatory,
        dosePerKg: item.dosePerKg,
      );
    }).toList();
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
        'isPaused': isPaused,
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
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      items: (json['items'] as List)
          .map((e) => SupplementItem.fromJson(e))
          .toList(),
      notes: json['notes'] ?? '',
      isPaused: json['isPaused'] ?? false,
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
      id: '${DateTime.now().millisecondsSinceEpoch}_$pondId',
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
    final newState = [...state, supplement];
    newState.sort((a, b) => a.startDoc.compareTo(b.startDoc));
    state = newState;
  }

  // 🔹 UPDATE
  void editSupplement(Supplement updated) {
    final newState = [
      for (final s in state)
        if (s.id == updated.id) updated else s
    ];
    newState.sort((a, b) => a.startDoc.compareTo(b.startDoc));
    state = newState;
  }

  void togglePause(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(isPaused: !s.isPaused) else s
    ];
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
