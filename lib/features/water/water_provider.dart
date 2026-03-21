import 'package:flutter_riverpod/flutter_riverpod.dart';

class WaterLog {
  final String id;
  final String pondId;
  final DateTime date;
  final int doc;
  final double ph;
  final double dissolvedOxygen;
  final double temperature;
  final double salinity;
  final double alkalinity;

  WaterLog({
    required this.id,
    required this.pondId,
    required this.date,
    required this.doc,
    required this.ph,
    required this.dissolvedOxygen,
    required this.temperature,
    required this.salinity,
    required this.alkalinity,
  });
}

class WaterNotifier extends StateNotifier<List<WaterLog>> {
  final String pondId;
  WaterNotifier(this.pondId) : super([]);

  void addLog({
    required int doc,
    required double ph,
    required double dissolvedOxygen,
    required double temperature,
    required double salinity,
    required double alkalinity,
  }) {
    final newLog = WaterLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pondId: pondId,
      date: DateTime.now(),
      doc: doc,
      ph: ph,
      dissolvedOxygen: dissolvedOxygen,
      temperature: temperature,
      salinity: salinity,
      alkalinity: alkalinity,
    );

    state = [newLog, ...state];
  }
}

final waterProvider =
    StateNotifierProvider.family<WaterNotifier, List<WaterLog>, String>(
        (ref, pondId) {
  return WaterNotifier(pondId);
});