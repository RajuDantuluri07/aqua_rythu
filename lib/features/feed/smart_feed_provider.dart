import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/master_feed_engine.dart';
import '../../core/engines/models/feed_input.dart';
import '../../core/engines/models/feed_output.dart';
import '../../core/enums/tray_status.dart';
import '../farm/farm_provider.dart';
import '../tray/tray_provider.dart';
import '../water/water_provider.dart';
import '../growth/mortality_provider.dart';
import 'feed_history_provider.dart';

// Import needed for distribution
import '../../core/engines/feed_calculation_engine.dart';

/// ✨ TODAY'S SMART FEED (Real-time calculation)
/// 
/// Triggers:
/// - Pond screen loads
/// - Water updated
/// - Tray updated
/// - Feed logged
/// - Day changes

class SmartFeedOutput {
  final FeedOutput engineOutput;
  final List<double> roundDistribution;
  final bool isStopFeeding;
  final String? stopReason;

  SmartFeedOutput({
    required this.engineOutput,
    required this.roundDistribution,
    this.isStopFeeding = false,
    this.stopReason,
  });
}

/// 🔍 Smart feed provider for a specific pond
final smartFeedProvider = FutureProvider.family<SmartFeedOutput?, String>((ref, pondId) async {
  try {
    final farmState = ref.watch(farmProvider);
    final currentFarm = farmState.currentFarm;
    if (currentFarm == null) return null;

    // Find the pond
    final pond = currentFarm.ponds.firstWhere(
      (p) => p.id == pondId,
      orElse: () => throw Exception("Pond not found"),
    );

    // Get current DOC
    final doc = pond.doc;

    // ✅ FIX: Get CURRENT population after mortality
    final mortalityNotifier = ref.watch(mortalityProvider);
    final currentPopulation = mortalityNotifier[pondId]
        ?.fold<int>(0, (sum, log) => sum + log.count) ?? 0;
    final livePopulation = pond.seedCount - currentPopulation;

    // Get base plan
    final feedPlanMap = {};
    final basePlan = feedPlanMap[pondId];
    if (basePlan == null) return null;

    // Get today's water quality (latest)
    final waterLogs = ref.watch(waterProvider(pondId));
    final latestWater = waterLogs.isNotEmpty ? waterLogs.last : null;

    // Get latest tray status
    final trayLogs = ref.watch(trayProvider(pondId));
    final latestTray = trayLogs.isNotEmpty ? trayLogs.last : null;

    // Get yesterday's actual feed
    final feedHistory = ref.watch(feedHistoryProvider);
    final historyLogs = feedHistory[pondId] ?? [];
    final yesterdayLogs = historyLogs.where((log) {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      return log.date.year == yesterday.year &&
          log.date.month == yesterday.month &&
          log.date.day == yesterday.day;
    });
    final yesterdayTotal = yesterdayLogs.isNotEmpty ? yesterdayLogs.first.total : null;

    // Default water values (if no data)
    final do_ = latestWater?.dissolvedOxygen ?? 6.0;
    final ammonia = latestWater?.ammonia ?? 0.05;
    final temp = latestWater?.ph ?? 7.8;

    // Get tray statuses or default to partial
    final trayStatuses = latestTray?.trays ?? 
        [TrayStatus.partial, TrayStatus.partial, TrayStatus.partial, TrayStatus.partial];

    // ✅ FIX: Support sampling data (ABW) to trigger sampling override in FeedStateEngine
    double? sampledAbw;
    if (pond.currentAbw != null && pond.currentAbw! > 0) {
      sampledAbw = pond.currentAbw;  // Use latest sampled ABW if available
    }

    // ✅ FIX: Get today's mortality for this DOC
    final todayMortality = mortalityNotifier[pondId]
        ?.where((log) => log.doc == doc)
        .fold<int>(0, (sum, log) => sum + log.count) ?? 0;

    // Create input with UPDATED population and sampling data
    final input = FeedInput(
      seedCount: livePopulation > 0 ? livePopulation : pond.seedCount,  // Use current population
      doc: doc,
      abw: sampledAbw,  // Pass sampled ABW to trigger sampling override

      feedingScore: 3.0,  // Default (could be captured from UI)
      intakePercent: 85.0,  // Default

      dissolvedOxygen: do_,
      temperature: temp,
      phChange: 0.0,
      ammonia: ammonia,

      mortality: todayMortality,  // Today's mortality count
      trayStatuses: trayStatuses,

      lastFcr: null,  // TODO: Calculate from historical data
      actualFeedYesterday: yesterdayTotal,
    );

    // Run engine
    final output = MasterFeedEngine.run(input);

    // Distribute into rounds
    final rounds = FeedCalculationEngine.distributeFeed(output.recommendedFeed, 4);

    // Check if stop feeding
    final isStop = output.isCriticalStop;

    return SmartFeedOutput(
      engineOutput: output,
      roundDistribution: rounds,
      isStopFeeding: isStop,
      stopReason: isStop ? output.alerts.first : null,
    );
  } catch (e) {
    print("Smart feed generation error: $e");
    return null;
  }
});
