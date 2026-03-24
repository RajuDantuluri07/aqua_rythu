import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';

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

  Pond({
    required this.id,
    required this.name,
    required this.area,
    required this.stockingDate,
    this.seedCount = 100000,
    this.plSize = 10,
    this.numTrays = 4,
    this.status = PondStatus.active,
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
    );
  }

  int get doc => DateTime.now().difference(stockingDate).inDays + 1;
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
          farms: [
            Farm(
              id: '1',
              name: 'Sri Rama Farm',
              location: 'Nellore',
              ponds: [
                Pond(
                  id: 'Pond 1',
                  name: 'Pond 1',
                  area: 2.5,
                  stockingDate:
                      DateTime.now().subtract(const Duration(days: 21)),
                  seedCount: 100000,
                  plSize: 10,
                ),
              ],
            ),
          ],
          selectedId: '1',
        ));

  void selectFarm(String id) {
    state = state.copyWith(selectedId: id);
  }

  void addFarm(String name, String location) {
    final newFarm = Farm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      location: location,
      ponds: [],
    );

    state = state.copyWith(
      farms: [...state.farms, newFarm],
      selectedId: newFarm.id,
    );
  }

  /// ✅ CLEAN VERSION (NO REF)
  void addPond(
    String farmId,
    String name,
    double area, {
    int seedCount = 100000,
    int plSize = 10,
    int numTrays = 4,
    DateTime? stockingDate,
  }) {
    final newPond = Pond(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      area: area,
      stockingDate: stockingDate ?? DateTime.now(),
      seedCount: seedCount,
      plSize: plSize,
      numTrays: numTrays,
    );

    state = state.copyWith(
      farms: state.farms.map((f) {
        if (f.id == farmId) {
          return Farm(
            id: f.id,
            name: f.name,
            location: f.location,
            ponds: [...f.ponds, newPond],
          );
        }
        return f;
      }).toList(),
    );
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

  void resetPond(String pondId, {
    required int seedCount,
    required int plSize,
    required DateTime stockingDate,
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
              );
            }
            return p;
          }).toList(),
        );
      }).toList(),
    );
  }
}

final farmProvider =
    StateNotifierProvider<FarmNotifier, FarmState>((ref) {
  return FarmNotifier();
});

final docProvider = Provider.family<int, String>((ref, pondId) {
  final farmState = ref.watch(farmProvider);

  for (var farm in farmState.farms) {
    try {
      final pondIndex = farm.ponds.indexWhere((p) => p.id == pondId);
      if (pondIndex != -1) {
        return farm.ponds[pondIndex].doc;
      }
    } catch (e, stack) {
      AppLogger.error("Error in docProvider for pondId: $pondId", e, stack);
    }
  }

  return 1;
});