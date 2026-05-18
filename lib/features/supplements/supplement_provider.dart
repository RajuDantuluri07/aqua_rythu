// lib/features/supplements/supplement_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aqua_rythu/features/supplements/screens/supplement_item.dart';
import 'package:aqua_rythu/core/models/supplement_schedule_log.dart';
import 'package:aqua_rythu/core/repositories/schedule_repository.dart';
import 'package:aqua_rythu/core/services/inventory_service.dart';
import 'package:aqua_rythu/core/utils/logger.dart';

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

  const CalculatedItem(
      {required this.name, required this.quantity, required this.unit});

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };

  factory CalculatedItem.fromJson(Map<String, dynamic> json) {
    return CalculatedItem(
      name: json['name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
    );
  }
}

class Supplement {
  final String id;
  final String name;
  final int startDoc;
  final int endDoc;
  final DateTime? startDate;
  final DateTime? endDate;
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
  final String? waterTime; // HH:mm for water mix schedules

  final List<SupplementItem> items;
  final String notes;
  final bool isPaused;

  Supplement({
    required this.id,
    required this.name,
    required this.startDoc,
    required this.endDoc,
    this.startDate,
    this.endDate,
    this.type = SupplementType.feedMix,
    this.goal,
    this.pondIds = const [],
    this.feedQty = 0.0,
    this.feedingTimes = const [],
    this.frequencyDays,
    this.preferredTime,
    this.date,
    this.waterTime,
    required this.items,
    this.notes = '',
    this.isPaused = false,
  });

  Supplement copyWith({
    String? id,
    String? name,
    int? startDoc,
    int? endDoc,
    DateTime? startDate,
    DateTime? endDate,
    SupplementType? type,
    SupplementGoal? goal,
    List<String>? pondIds,
    double? feedQty,
    List<String>? feedingTimes,
    int? frequencyDays,
    WaterMixTime? preferredTime,
    DateTime? date,
    String? waterTime,
    List<SupplementItem>? items,
    String? notes,
    bool? isPaused,
  }) {
    return Supplement(
      id: id ?? this.id,
      name: name ?? this.name,
      startDoc: startDoc ?? this.startDoc,
      endDoc: endDoc ?? this.endDoc,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      goal: goal ?? this.goal,
      pondIds: pondIds ?? this.pondIds,
      feedQty: feedQty ?? this.feedQty,
      feedingTimes: feedingTimes ?? this.feedingTimes,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      preferredTime: preferredTime ?? this.preferredTime,
      date: date ?? this.date,
      waterTime: waterTime ?? this.waterTime,
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

  bool isActiveOnDate(DateTime targetDate) {
    final day = DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (type == SupplementType.feedMix) {
      if (startDate == null || endDate == null) return false;
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      return !day.isBefore(start) && !day.isAfter(end);
    }

    if (date == null) {
      return false;
    }
    final scheduled = DateTime(date!.year, date!.month, date!.day);
    if (day.isBefore(scheduled)) {
      return false;
    }
    if (frequencyDays == null || frequencyDays == 0) {
      return day.isAtSameMomentAs(scheduled);
    }
    final diff = day.difference(scheduled).inDays;
    return diff % frequencyDays! == 0;
  }

  bool appliesToPond(String pondId) {
    return pondIds.contains(pondId) || pondIds.contains('ALL');
  }

  String? get effectiveWaterTime {
    if (waterTime != null && waterTime!.isNotEmpty) {
      return waterTime;
    }
    if (type == SupplementType.waterMix && feedingTimes.isNotEmpty) {
      final first = feedingTimes.first;
      if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(first)) {
        return first;
      }
    }
    return null;
  }

  DateTime? get scheduleAnchorDate {
    if (type == SupplementType.feedMix) {
      return startDate;
    }
    return date;
  }

  List<SupplementItem> calculateDosage(double feedKg) {
    if (type != SupplementType.feedMix) return [];
    if (feedQty <= 0) return [];

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

  List<CalculatedItem> calculateAppliedItems({
    double? feedKg,
    double? pondArea,
  }) {
    if (type == SupplementType.feedMix) {
      final qty = feedKg ?? 0;
      if (qty <= 0) {
        return [];
      }
      return calculateDosage(qty)
          .map((item) => CalculatedItem(
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
              ))
          .toList();
    }

    final area = pondArea ?? 0;
    if (area <= 0) {
      return [];
    }

    return items
        .map((item) => CalculatedItem(
              name: item.name,
              quantity: item.quantity * area,
              unit: item.unit,
            ))
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDoc': startDoc,
        'endDoc': endDoc,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'type': type.name,
        'goal': goal?.name,
        'pondIds': pondIds,
        'feedQty': feedQty,
        'feedingTimes': feedingTimes,
        'frequencyDays': frequencyDays,
        'preferredTime': preferredTime?.name,
        'date': date?.toIso8601String(),
        'waterTime': waterTime,
        'items': items.map((e) => e.toJson()).toList(),
        'notes': notes,
        'isPaused': isPaused,
      };

  factory Supplement.fromJson(Map<String, dynamic> json) {
    return Supplement(
      id: json['id'],
      name: json['name'],
      startDoc: json['startDoc'] ?? 1,
      endDoc: json['endDoc'] ?? 999,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate:
          json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      type: () {
        try {
          return json['type'] != null
              ? SupplementType.values.byName(json['type'] as String)
              : SupplementType.feedMix;
        } catch (_) {
          return SupplementType.feedMix;
        }
      }(),
      goal: () {
        try {
          return json['goal'] != null
              ? SupplementGoal.values.byName(json['goal'] as String)
              : null;
        } catch (_) {
          return null;
        }
      }(),
      pondIds: List<String>.from(json['pondIds'] ?? []),
      feedQty: (json['feedQty'] as num?)?.toDouble() ?? 0.0,
      feedingTimes: List<String>.from(json['feedingTimes'] ?? []),
      frequencyDays: json['frequencyDays'],
      preferredTime: () {
        try {
          return json['preferredTime'] != null
              ? WaterMixTime.values.byName(json['preferredTime'] as String)
              : null;
        } catch (_) {
          return null;
        }
      }(),
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      waterTime: json['waterTime'] ??
          (((json['feedingTimes'] as List?) != null &&
                  (json['feedingTimes'] as List).isNotEmpty)
              ? (json['feedingTimes'] as List).first as String
              : null),
      items: (json['items'] as List)
          .map((e) => SupplementItem.fromJson(e))
          .toList(),
      notes: json['notes'] ?? '',
      isPaused: json['isPaused'] ?? false,
    );
  }
}

/// ---------------------------------------------------
/// 📦 LOG MODEL (Application History — DB-backed)
/// ---------------------------------------------------
class SupplementLog {
  final String id;
  final String supplementId; // supplement_schedule.id
  final String pondId;
  final String? pondName;
  final DateTime timestamp;
  final List<CalculatedItem> appliedItems;
  final String? supplementName;
  final String? scheduledTime;
  final SupplementType? supplementType;
  final int? feedRound;
  final double? inputValue;
  final String? inputUnit;
  final DateTime? scheduledAt;

  SupplementLog({
    required this.id,
    required this.supplementId,
    required this.pondId,
    this.pondName,
    required this.timestamp,
    required this.appliedItems,
    this.supplementName,
    this.scheduledTime,
    this.supplementType,
    this.feedRound,
    this.inputValue,
    this.inputUnit,
    this.scheduledAt,
  });

  /// Build from the DB-persisted SupplementScheduleLog row.
  factory SupplementLog.fromDbLog(SupplementScheduleLog dbLog) {
    final items = dbLog.appliedItems.map(CalculatedItem.fromJson).toList();
    SupplementType? type;
    if (dbLog.feedRound != null) {
      type = SupplementType.feedMix;
    } else if (dbLog.inputUnit == 'acre') {
      type = SupplementType.waterMix;
    }

    return SupplementLog(
      id: dbLog.id,
      supplementId: dbLog.supplementScheduleId,
      pondId: dbLog.pondId ?? '',
      timestamp: dbLog.createdAt,
      appliedItems: items,
      supplementName: dbLog.supplementName,
      scheduledTime: dbLog.feedRound,
      supplementType: type,
      feedRound: dbLog.feedRound != null
          ? int.tryParse(dbLog.feedRound!.replaceAll(RegExp(r'[^0-9]'), ''))
          : null,
      inputValue: dbLog.inputValue,
      inputUnit: dbLog.inputUnit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplementId': supplementId,
        'pondId': pondId,
        'pondName': pondName,
        'timestamp': timestamp.toIso8601String(),
        'appliedItems': appliedItems.map((item) => item.toJson()).toList(),
        'supplementName': supplementName,
        'scheduledTime': scheduledTime,
        'supplementType': supplementType?.name,
        'feedRound': feedRound,
        'inputValue': inputValue,
        'inputUnit': inputUnit,
        'scheduledAt': scheduledAt?.toIso8601String(),
      };
}

/// ---------------------------------------------------
/// 🎮 DB-BACKED LOG NOTIFIER (family by pondId)
/// ---------------------------------------------------
class SupplementLogNotifier extends StateNotifier<AsyncValue<List<SupplementLog>>> {
  final String pondId;
  final ScheduleRepository _repo;
  final InventoryService _inventoryService;
  final _supabase = Supabase.instance.client;

  SupplementLogNotifier(this.pondId, this._repo, this._inventoryService)
      : super(const AsyncValue.loading()) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    if (pondId.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final dbLogs = await _repo.fetchLogsByPond(pondId);
      final logs = dbLogs.map(SupplementLog.fromDbLog).toList();
      state = AsyncValue.data(logs);
    } catch (e, st) {
      AppLogger.error('SupplementLogNotifier: failed to load for pond $pondId', e);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reload() => _loadFromDb();

  /// Persist an application log to the DB and update in-memory state.
  /// Returns a list of inventory warning messages (empty = all deductions OK).
  /// Callers should show these as non-blocking SnackBars so the farmer knows
  /// which supplements were NOT deducted from inventory.
  Future<List<String>> logApplication({
    required String supplementId,
    required String supplementName,
    required List<CalculatedItem> items,
    required SupplementType supplementType,
    String? farmId,
    String? feedRound,
    double? inputValue,
    String? inputUnit,
    String? remarks,
  }) async {
    final user = _supabase.auth.currentUser;
    final now = DateTime.now();

    final dbLog = SupplementScheduleLog(
      id: '',
      supplementScheduleId: supplementId,
      pondId: pondId,
      supplementName: supplementName,
      appliedDate: now,
      feedRound: feedRound,
      status: 'applied',
      remarks: remarks,
      appliedItems: items.map((i) => i.toJson()).toList(),
      inputValue: inputValue,
      inputUnit: inputUnit,
      createdBy: user?.id,
      createdAt: now,
    );

    try {
      final saved = await _repo.insertLog(dbLog);
      final uiLog = SupplementLog.fromDbLog(saved);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([uiLog, ...current]);
    } catch (e) {
      AppLogger.error('SupplementLogNotifier.logApplication failed: $e');
      rethrow;
    }

    // Best-effort inventory deduction — collect skip reasons so callers can warn.
    final warnings = <String>[];
    if (farmId != null && farmId.isNotEmpty) {
      for (final item in items) {
        final skipReason = await _inventoryService.recordSupplementConsumption(
          farmId, item.name, item.quantity, item.unit,
        );
        if (skipReason != null) warnings.add(skipReason);
      }
    }
    return warnings;
  }

  bool hasFeedLogForRoundOnDate({
    required int round,
    required DateTime date,
  }) {
    final logs = state.valueOrNull ?? [];
    return logs.any((log) =>
        log.supplementType == SupplementType.feedMix &&
        log.feedRound == round &&
        log.timestamp.year == date.year &&
        log.timestamp.month == date.month &&
        log.timestamp.day == date.day);
  }

  bool hasWaterLogForSupplementOnDate({
    required String supplementId,
    required DateTime date,
  }) {
    final logs = state.valueOrNull ?? [];
    return logs.any((log) =>
        log.supplementId == supplementId &&
        log.supplementType == SupplementType.waterMix &&
        log.timestamp.year == date.year &&
        log.timestamp.month == date.month &&
        log.timestamp.day == date.day);
  }
}

final supplementLogProvider = StateNotifierProvider.family
    .autoDispose<SupplementLogNotifier, AsyncValue<List<SupplementLog>>, String>(
  (ref, pondId) =>
      SupplementLogNotifier(pondId, ScheduleRepository(), InventoryService()),
);

/// ---------------------------------------------------
/// 🎮 IN-MEMORY PLAN NOTIFIER (for active session plans)
/// ---------------------------------------------------

class SupplementNotifier extends StateNotifier<List<Supplement>> {
  SupplementNotifier() : super([]);

  DateTime _sortAnchor(Supplement supplement) {
    return supplement.scheduleAnchorDate ??
        DateTime(2000, 1, 1).add(Duration(days: supplement.startDoc));
  }

  List<Supplement> _sorted(List<Supplement> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final dateCompare = _sortAnchor(a).compareTo(_sortAnchor(b));
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  List<Supplement> getByPond(String pondId) {
    return state.where((e) => e.appliesToPond(pondId)).toList();
  }

  List<Map<String, dynamic>> toJsonList() {
    return state.map((supplement) => supplement.toJson()).toList();
  }

  void replaceAll(List<Supplement> supplements) {
    state = _sorted(supplements);
  }

  void hydrateFromJson(List<dynamic> records) {
    replaceAll(
      records
          .map((record) =>
              Supplement.fromJson(Map<String, dynamic>.from(record as Map)))
          .toList(),
    );
  }

  void addSupplement(Supplement supplement) {
    state = _sorted([...state, supplement]);
  }

  void editSupplement(Supplement updated) {
    state = _sorted([
      for (final s in state)
        if (s.id == updated.id) updated else s
    ]);
  }

  void togglePause(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(isPaused: !s.isPaused) else s
    ];
  }

  void deleteSupplement(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  void removeSupplement(String id) {
    deleteSupplement(id);
  }

  void clearForPond(String pondId) {
    final updated = <Supplement>[];

    for (final supplement in state) {
      if (!supplement.appliesToPond(pondId)) {
        updated.add(supplement);
        continue;
      }

      if (supplement.pondIds.contains('ALL')) {
        updated.add(supplement);
        continue;
      }

      final remainingPonds =
          supplement.pondIds.where((id) => id != pondId).toList();

      if (remainingPonds.isEmpty) {
        continue;
      }

      updated.add(supplement.copyWith(pondIds: remainingPonds));
    }

    state = _sorted(updated);
  }
}

/// ---------------------------------------------------
/// 🌐 PROVIDER
/// ---------------------------------------------------

final supplementProvider =
    StateNotifierProvider<SupplementNotifier, List<Supplement>>((ref) {
  return SupplementNotifier();
});
