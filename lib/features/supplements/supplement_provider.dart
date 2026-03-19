import 'package:flutter_riverpod/flutter_riverpod.dart';

class Supplement {
  final String name;
  final int docFrom;
  final int docTo;
  final List<bool> rounds;
  final List<Map<String, String>> items;

  Supplement({
    required this.name,
    required this.docFrom,
    required this.docTo,
    required this.rounds,
    required this.items,
  });
}

class SupplementNotifier extends StateNotifier<List<Supplement>> {
  SupplementNotifier() : super([]);

  void addSupplement(Supplement s) {
    state = [...state, s];
  }
}

final supplementProvider =
    StateNotifierProvider.family<SupplementNotifier, List<Supplement>, String>(
        (ref, pondId) => SupplementNotifier());