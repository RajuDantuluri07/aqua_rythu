import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WaterLog {
  final String id;
  final String pondId;
  final DateTime date;
  final int doc;
  final double ph;
  final double dissolvedOxygen;
  final double salinity;
  final double ammonia;
  final double nitrite;
  final double alkalinity;

  WaterLog({
    required this.id,
    required this.pondId,
    required this.date,
    required this.doc,
    required this.ph,
    required this.dissolvedOxygen,
    required this.salinity,
    required this.ammonia,
    required this.nitrite,
    required this.alkalinity,
  });

  // Health Score calculation
  int get healthScore {
    int score = 100;
    
    // Dissolved Oxygen (0-20 points)
    if (dissolvedOxygen < 4) {
      score -= 20;
    } else if (dissolvedOxygen < 5) {
      score -= 10;
    }

    // pH (0-10 points)
    if (ph < 7.5 || ph > 8.5) score -= 10;

    // Ammonia (0-20 points)
    if (ammonia > 0.3) {
      score -= 20;
    } else if (ammonia > 0.1) {
      score -= 10;
    }

    // Nitrite (0-20 points)
    if (nitrite > 0.3) {
      score -= 20;
    } else if (nitrite > 0.1) {
      score -= 10;
    }

    // Salinity (0-10 points)
    if (salinity < 10 || salinity > 25) score -= 10;

    // Alkalinity (0-10 points)
    if (alkalinity < 100 || alkalinity > 200) score -= 10;

    return score.clamp(0, 100);
  }

  String get healthStatus {
    if (healthScore >= 80) return "Excellent";
    if (healthScore >= 60) return "Moderate";
    return "Critical";
  }

  Color get healthColor {
    if (healthScore >= 80) return Colors.green;
    if (healthScore >= 60) return Colors.orange;
    return Colors.red;
  }

  List<String> get recommendations {
    final List<String> recs = [];
    if (ph < 7.5) recs.add("Add agricultural lime to raise pH");
    if (ph > 8.5) recs.add("Stop lime application, add organic matter");
    if (dissolvedOxygen < 4.0) recs.add("CRITICAL: Increase aeration, reduce feeding");
    else if (dissolvedOxygen < 5.0) recs.add("Monitor aeration, slight improvement needed");
    if (salinity < 10.0) recs.add("Increase salt or brackish water inflow");
    if (salinity > 25.0) recs.add("Add fresh water to dilute salinity");
    if (alkalinity < 100.0) recs.add("Add sodium bicarbonate or lime");
    if (alkalinity > 200.0) recs.add("Reduce lime application");
    if (ammonia > 0.1) recs.add(ammonia > 0.3 ? "CRITICAL: Reduce feeding by 50%, increase aeration, add probiotics" : "Reduce feeding by 20%, increase aeration");
    if (nitrite > 0.1) recs.add(nitrite > 0.3 ? "CRITICAL: Salt treatment (1-2 ppt), reduce feeding" : "Add salt (0.5-1 ppt), reduce feeding");
    return recs;
  }
}

class WaterNotifier extends StateNotifier<List<WaterLog>> {
  final String pondId;
  WaterNotifier(this.pondId) : super([]);

  void addLog({
    required int doc,
    required double ph,
    required double dissolvedOxygen,
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
      salinity: salinity,
      ammonia: ammonia,
      nitrite: nitrite,
      alkalinity: alkalinity,
    );

    state = [newLog, ...state];
  }

  void clearLogs() {
    state = [];
  }
}

final waterProvider =
    StateNotifierProvider.family<WaterNotifier, List<WaterLog>, String>(
        (ref, pondId) {
  return WaterNotifier(pondId);
});