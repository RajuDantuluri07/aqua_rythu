import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/farm_settings_provider.dart';

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

  // Health Score calculation with calibration-aware thresholds
  int getHealthScore(FarmSettings settings) {
    int score = 100;

    // Get farm-specific ranges for critical values
    final isSemiIntensive = settings.farmType == "Semi-Intensive";

    // Dissolved Oxygen (0-20 points) - More lenient for semi-intensive
    final doThreshold = isSemiIntensive ? 3.5 : 4.0;
    final doWarning = isSemiIntensive ? 4.5 : 5.0;
    
    if (dissolvedOxygen < doThreshold) {
      score -= 20;
    } else if (dissolvedOxygen < doWarning) {
      score -= 10;
    }

    // pH (0-10 points) - Standard range
    if (ph < 7.5 || ph > 8.5) {
      score -= 10;
    }

    // Ammonia (0-20 points) - More critical for intensive systems
    final ammThreshold = isSemiIntensive ? 0.4 : 0.3;
    final ammWarning = isSemiIntensive ? 0.15 : 0.1;
    
    if (ammonia > ammThreshold) {
      score -= 20;
    } else if (ammonia > ammWarning) {
      score -= 10;
    }

    // Nitrite (0-20 points) - Similar to ammonia
    final nitriteThreshold = isSemiIntensive ? 0.4 : 0.3;
    final nitriteWarning = isSemiIntensive ? 0.15 : 0.1;
    
    if (nitrite > nitriteThreshold) {
      score -= 20;
    } else if (nitrite > nitriteWarning) {
      score -= 10;
    }

    // Salinity (0-10 points) - Range based on farm type
    final salMin = isSemiIntensive ? 8.0 : 10.0;
    final salMax = isSemiIntensive ? 28.0 : 25.0;
    
    if (salinity < salMin || salinity > salMax) {
      score -= 10;
    }

    // Alkalinity (0-10 points) - Standard range
    if (alkalinity < 100 || alkalinity > 200) {
      score -= 10;
    }

    return score.clamp(0, 100);
  }

  int get healthScore {
    int score = 100;

    if (ph < 7 || ph > 9) score -= 20;
    if (dissolvedOxygen < 5) score -= 25;
    if (salinity < 5 || salinity > 35) score -= 15;

    return score.clamp(0, 100);
  }

  String get healthStatus {
    if (healthScore >= 80) return "good";
    if (healthScore >= 60) return "warning";
    return "danger";
  }

  Color get healthColor {
    switch (healthStatus) {
      case "good":
        return Colors.green;
      case "warning":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  List<String> get recommendations {
    final List<String> list = [];

    if (dissolvedOxygen < 5) {
      list.add("Increase aeration immediately");
    }

    if (ph < 7) {
      list.add("Apply lime to increase pH");
    }

    if (ph > 9) {
      list.add("Reduce pH (check algae bloom)");
    }

    return list;
  }

  List<String> getRecommendations(FarmSettings settings) {
    final List<String> recs = [];
    final isSemiIntensive = settings.farmType == "Semi-Intensive";

    // pH recommendations
    if (ph < 7.5) {
      recs.add("Add agricultural lime to raise pH");
    }
    if (ph > 8.5) {
      recs.add("Stop lime application, add organic matter");
    }

    // Dissolved Oxygen
    final doThreshold = isSemiIntensive ? 3.5 : 4.0;
    if (dissolvedOxygen < doThreshold) {
      recs.add("🔴 CRITICAL: Increase aeration immediately, reduce feeding");
    } else if (dissolvedOxygen < 5.0) {
      recs.add("Monitor aeration, improvement needed");
    }

    // Salinity
    if (salinity < 8.0) {
      recs.add("Increase salt or brackish water inflow");
    }
    if (salinity > 28.0) {
      recs.add("Add fresh water to dilute salinity");
    }

    // Alkalinity
    if (alkalinity < 100.0) {
      recs.add("Add sodium bicarbonate or lime");
    }
    if (alkalinity > 200.0) {
      recs.add("Reduce lime application");
    }

    // Ammonia
    final ammWarning = isSemiIntensive ? 0.15 : 0.1;
    if (ammonia > ammWarning) {
      recs.add(ammonia > 0.3
          ? "🔴 CRITICAL: Reduce feeding by 50%, increase aeration, add probiotics"
          : "Reduce feeding by 20%, increase aeration");
    }

    // Nitrite
    final nitriteWarning = isSemiIntensive ? 0.15 : 0.1;
    if (nitrite > nitriteWarning) {
      recs.add(nitrite > 0.3
          ? "🔴 CRITICAL: Salt treatment (1-2 ppt), reduce feeding"
          : "Add salt (0.5-1 ppt), reduce feeding");
    }

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

// Provider that returns water health status with farm settings calibration
final waterHealthProvider = Provider.family<(int, String, Color, List<String>), String>((ref, pondId) {
  final waterLogs = ref.watch(waterProvider(pondId));
  final farmSettings = ref.watch(farmSettingsProvider);

  if (waterLogs.isEmpty) {
    return (0, "No Data", Colors.grey, ["No water quality readings yet"]);
  }

  final lastLog = waterLogs.first; // Newest first
  final score = lastLog.getHealthScore(farmSettings);
  final status = score >= 80 ? "Excellent" : (score >= 60 ? "Moderate" : "Critical");
  final color = score >= 80 ? Colors.green : (score >= 60 ? Colors.orange : Colors.red);
  final recommendations = lastLog.getRecommendations(farmSettings);

  return (score, status, color, recommendations);
});
