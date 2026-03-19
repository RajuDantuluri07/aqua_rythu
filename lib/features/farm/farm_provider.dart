import 'package:flutter_riverpod/flutter_riverpod.dart';

class Pond {
  final String id;
  final String name;
  final double area;
  final DateTime stockingDate;
  final int seedCount;

  Pond({
    required this.id,
    required this.name,
    required this.area,
    required this.stockingDate,
    this.seedCount = 100000,
  });

  /// Dynamically calculates the Day of Culture.
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
                  stockingDate: DateTime.now().subtract(const Duration(days: 21)),
                  seedCount: 100000,
                ), // DOC: 22
                Pond(
                  id: 'Pond 2',
                  name: 'Pond 2',
                  area: 3.0,
                  stockingDate: DateTime.now().subtract(const Duration(days: 41)),
                ), // DOC: 42
              ],
            ),
            Farm(
              id: '2',
              name: 'Krishna Farm',
              location: 'Bhimavaram',
              ponds: [
                Pond(
                  id: 'Pond 3',
                  name: 'Pond 3',
                  area: 1.5,
                  stockingDate: DateTime.now().subtract(const Duration(days: 89)),
                ), // DOC: 90
              ]),
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
      ponds: [], // New farms start with no ponds
    );
    state = state.copyWith(
      farms: [...state.farms, newFarm],
      selectedId: newFarm.id,
    );
  }

  void addPond(String farmId, String name, double area) {
    state = state.copyWith(
      farms: state.farms.map((f) {
        if (f.id == farmId) {
          return Farm(
            id: f.id,
            name: f.name,
            location: f.location,
            ponds: [
              ...f.ponds,
              Pond(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                area: area,
                stockingDate: DateTime.now(),
                seedCount: 100000, // Default seed count
              )
            ],
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
}

final farmProvider = StateNotifierProvider<FarmNotifier, FarmState>((ref) {
  return FarmNotifier();
});

/// A simple provider to get the DOC for a specific pond.
/// This avoids repetitive logic in the UI.
final docProvider = Provider.family<int, String>((ref, pondId) {
  final farmState = ref.watch(farmProvider);
  // This assumes ponds across all farms have unique IDs for simplicity.
  for (var farm in farmState.farms) {
    try {
      final pond = farm.ponds.firstWhere((p) => p.id == pondId);
      return pond.doc;
    } catch (e) {
      // Continue searching in the next farm
    }
  }
  return 1; // Return a default if not found
});