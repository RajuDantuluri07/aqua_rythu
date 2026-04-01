import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../farm/farm_provider.dart';
import 'sampling_log.dart'; // Import the new SamplingLog model

class GrowthNotifier extends StateNotifier<List<SamplingLog>> {
  GrowthNotifier() : super([]);

  /// 📏 ADD SAMPLING LOG
  void addLog(SamplingLog log) {
    state = [log, ...state]; // Add to the beginning to keep newest first
  }

  void clearLogs() {
    state = [];
  }
}


final growthProvider =
    StateNotifierProvider.family<GrowthNotifier, List<SamplingLog>, String>(
        (ref, pondId) {
  return GrowthNotifier();
});
