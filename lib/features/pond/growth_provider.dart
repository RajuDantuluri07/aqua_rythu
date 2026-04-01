final growthProvider = StateNotifierProvider.family<
    GrowthNotifier,
    List<SamplingLog>,
    String>((ref, pondId) {
  return GrowthNotifier();
});