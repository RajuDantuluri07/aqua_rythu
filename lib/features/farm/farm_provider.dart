import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:aqua_rythu/services/farm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PondStatus { active, completed }

class Pond {
  final String id;
  final String name;
  final double area;
  final DateTime stockingDate;
  final int seedCount;
  final int plSize;
  final int numTrays;
  final PondStatus status;
  final double? currentAbw;  // Latest sampled average body weight

  Pond({
    required this.id,
    required this.name,
    required this.area,
    required this.stockingDate,
    this.seedCount = 100000,
    this.plSize = 10,
    this.numTrays = 4,
    this.status = PondStatus.active,
    this.currentAbw,
  });

  Pond copyWith({
    String? id,
    String? name,
    double? area,
    DateTime? stockingDate,
    int? seedCount,
    int? plSize,
    int? numTrays,
    PondStatus? status,
    double? currentAbw,
  }) {
    return Pond(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      stockingDate: stockingDate ?? this.stockingDate,
      seedCount: seedCount ?? this.seedCount,
      plSize: plSize ?? this.plSize,
      numTrays: numTrays ?? this.numTrays,
      status: status ?? this.status,
      currentAbw: currentAbw ?? this.currentAbw,
    );
  }

  /// Calculates Day of Culture (DOC) as whole days since stocking.
  int get doc {
    return calculateDoc(DateTime.now());
  }

  int calculateDoc(DateTime now) {
    // Normalize both dates to midnight UTC to ensure consistency
    final date1 = DateTime.utc(now.year, now.month, now.day);
    final date2 = DateTime.utc(stockingDate.year, stockingDate.month, stockingDate.day);
    
    final diff = date1.difference(date2).inDays + 1;
    return diff > 0 ? diff : 1; // Default to Day 1 if date is in future
  }
}

class Farm {
  final String id;
  final String name;
  final String location;
  final List<Pond> ponds;

  Farm({
    required this.id,
    required this.name,
    required this.location,
    this.ponds = const [],
  });
}

class FarmState {
  final List<Farm> farms;
  final String selectedId;

  FarmState({
    required this.farms,
    required this.selectedId,
  });

  Farm? get currentFarm {
    if (farms.isEmpty) return null;
    try {
      return farms.firstWhere((f) => f.id == selectedId);
    } catch (_) {
      return farms.first;
    }
  }

  FarmState copyWith({
    List<Farm>? farms,
    String? selectedId,
  }) {
    return FarmState(
      farms: farms ?? this.farms,
      selectedId: selectedId ?? this.selectedId,
    );
  }
}

class FarmNotifier extends StateNotifier<FarmState> {
  FarmNotifier()
      : super(FarmState(
          farms: [],  // ✅ CLEANED: Empty list - will load from Supabase
          selectedId: '',
        ));

  void selectFarm(String id) {
    state = state.copyWith(selectedId: id);
  }

  Future<void> loadFarms({String? setAsSelectedId}) async {
    final user = Supabase.instance.client.auth.currentUser;
    print("USER ID: ${user?.id}");

    if (user == null) {
      return;
    }

    try {
      final data = await FarmService().getFarmsWithPonds();
      
      final loadedFarms = data.map((f) => Farm(
        id: f['id'].toString(),
        name: f['name'],
        location: f['location'],
        ponds: (f['ponds'] as List).map((p) => Pond(
          id: p['id'].toString(),
          name: p['name'],
          area: (p['area'] as num).toDouble(),
          stockingDate: DateTime.parse(p['stocking_date']),
          seedCount: p['seed_count'] ?? 100000,
          plSize: p['pl_size'] ?? 10,
          numTrays: p['num_trays'] ?? 4,
          status: p['status'] == 'completed' ? PondStatus.completed : PondStatus.active,
          currentAbw: p['current_abw'] != null ? (p['current_abw'] as num).toDouble() : null,
        )).toList(),
      )).toList();

      state = state.copyWith(
        farms: loadedFarms,
        selectedId: setAsSelectedId ?? (loadedFarms.isNotEmpty ? loadedFarms.first.id : ''),
      );
    } catch (e) {
      print("Error loading farms: $e");
    }
  }

  void deletePond(String farmId, String pondId) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        if (f.id == farmId) {
          return Farm(
            id: f.id,
            name: f.name,
            location: f.location,
            ponds: f.ponds.where((p) => p.id != pondId).toList(),
          );
        }
        return f;
      }).toList(),
    );
  }

  void updatePond({
    required String pondId,
    required String name,
    required double area,
    required int seedCount,
    required int plSize,
    required DateTime stockingDate,
    required int numTrays,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(
                name: name,
                area: area,
                seedCount: seedCount,
                plSize: plSize,
                stockingDate: stockingDate,
                numTrays: numTrays,
              );
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  void updatePondStatus(String pondId, PondStatus status) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(status: status);
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }

  void resetPond(
    String pondId, {
    required int seedCount,
    required int plSize,
    required DateTime stockingDate,
    int numTrays = 4,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        return Farm(
          id: f.id,
          name: f.name,
          location: f.location,
          ponds: f.ponds.map((p) {
            if (p.id == pondId) {
              return p.copyWith(
                status: PondStatus.active,
                seedCount: seedCount,
                plSize: plSize,
                stockingDate: stockingDate,
                numTrays: numTrays,
              );
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }
  void updateFarm({
    required String farmId,
    required String name,
    required String location,
  }) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        if (f.id == farmId) {
          return Farm(
            id: f.id,
            name: name,
            location: location,
            ponds: f.ponds,
          );
        }
        return f;
      }).toList(),
    );
  }

  void deleteFarm(String farmId) {
    final updatedFarms = state.farms.where((f) => f.id != farmId).toList();
    final newSelectedId = updatedFarms.isNotEmpty ? updatedFarms.first.id : '';
    
    state = state.copyWith(
      farms: updatedFarms,
      selectedId: newSelectedId,
    );
  }}

final farmProvider = StateNotifierProvider<FarmNotifier, FarmState>((ref) {
  return FarmNotifier();
});

/// A provider that returns the current date and refreshes every hour
/// to ensure DOC increments automatically at midnight.
final currentDateProvider = Provider<DateTime>((ref) {
  // Rebuild this provider every hour
  final timer = Timer(const Duration(hours: 1), () => ref.invalidateSelf());
  ref.onDispose(() => timer.cancel());
  return DateTime.now();
});

final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(currentDateProvider);
  return DateTime(now.year, now.month, now.day);
});

final oneWeekAgoProvider = Provider<DateTime>((ref) {
  final today = ref.watch(todayProvider);
  return today.subtract(const Duration(days: 7));
});

final docProvider = Provider.family<int, String>((ref, pondId) {
  final farmState = ref.watch(farmProvider);
  final now = ref.watch(currentDateProvider);

  // Optimization: Check current farm first
  final currentPonds = farmState.currentFarm?.ponds ?? [];
  final currentIdx = currentPonds.indexWhere((p) => p.id == pondId);
  if (currentIdx != -1) {
    return currentPonds[currentIdx].calculateDoc(now);
  }

  // Fallback: Check all other farms
  for (var farm in farmState.farms) {
    final pondIndex = farm.ponds.indexWhere((p) => p.id == pondId);
    if (pondIndex != -1) {
      return farm.ponds[pondIndex].calculateDoc(now);
    }
  }

  return 1;
});
