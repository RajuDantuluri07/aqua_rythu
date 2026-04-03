import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../growth/growth_provider.dart';
import '../growth/sampling_log.dart';

final growthProvider = StateNotifierProvider.family<
    GrowthNotifier,
    List<SamplingLog>,
    String>((ref, pondId) {
  return GrowthNotifier();
});