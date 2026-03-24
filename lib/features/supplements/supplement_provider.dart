// lib/features/supplements/supplement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SupplementStatus { upcoming, active, completed }

enum SupplementType {
  feedMix,
  waterMix,
}

enum WaterMixTime {
  morning,
  evening,
  afterFeed,
}

/// ---------------------------------------------------
/// 📦 MODEL (Backend Ready)
/// ---------------------------------------------------

class MixItem {
  final String name;
  final double dosePerKg;
  final String unit;

  MixItem({
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

  factory MixItem.fromJson(Map<String, dynamic> json) {
    return MixItem(
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

  /// FEED MIX ONLY
  final double feedQty; // default 0 if waterMix
  final List<String> feedingTimes; // empty if waterMix

  /// WATER MIX ONLY
  final int? frequencyDays;
  final WaterMixTime? preferredTime;

  final List<String> pondIds; // ['pondId1', 'pondId2'] or ['ALL']

  final List<MixItem> items;

  Supplement({
    required this.id,
    required this.name,
    required this.startDoc,
    required this.endDoc,
    this.type = SupplementType.feedMix,
    this.feedQty = 0.0,
    this.feedingTimes = const [],
    this.frequencyDays,
    this.preferredTime,
    this.pondIds = const ['ALL'],
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
        'type': type.name,
        'feedQty': feedQty,
        'feedingTimes': feedingTimes,
        'frequencyDays': frequencyDays,
        'preferredTime': preferredTime?.name,
        'pondIds': pondIds,
        'items': items.map((e) => e.toJson()).toList(),
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
      feedQty: (json['feedQty'] as num?)?.toDouble() ?? 0.0,
      feedingTimes: List<String>.from(json['feedingTimes'] ?? []),
      frequencyDays: json['frequencyDays'],
      preferredTime: json['preferredTime'] != null
          ? WaterMixTime.values.byName(json['preferredTime'])
          : null,
      pondIds: List<String>.from(json['pondIds'] ?? ['ALL']),
      items: (json['items'] as List)
          .map((e) => MixItem.fromJson(e))
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
