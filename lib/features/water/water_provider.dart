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
  final double ammonia; // As per PRD 4.8
  final double nitrite; // As per PRD 4.8
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
    required this.ammonia,
    required this.nitrite,
    required this.alkalinity,
  });

  // Health Score calculation as per PRD 4.8
  int get healthScore {
    int score = 100;
    if (dissolvedOxygen < 4) score -= 20;
    else if (dissolvedOxygen < 5) score -= 10;

    if (ph < 7.5 || ph > 8.5) score -= 10;

    if (ammonia > 0.3) score -= 20;
    else if (ammonia > 0.1) score -= 10;

    if (nitrite > 0.3) score -= 20;
    else if (nitrite > 0.1) score -= 10;
    return score;
  }
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
    required double ammonia,
    required double nitrite,
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
      ammonia: ammonia,
      nitrite: nitrite,
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