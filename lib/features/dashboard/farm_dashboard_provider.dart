import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supplements/supplement_provider.dart';
import '../../systems/supplements/water_task_engine.dart';
import '../farm/farm_provider.dart';
import '../../core/utils/logger.dart';

/// State for the Farm Dashboard Metrics
/// Now only aggregates data from pond controllers - no calculations
class FarmDashboardState {
  final double totalFeed;
  final double totalBiomass;
  final double avgGrowth;
  final double fcr;
  final String healthIndicator; // "Healthy", "Caution", "Critical"
  final bool isLoading;
  final String? error;

  const FarmDashboardState({
    this.totalFeed = 0,
    this.totalBiomass = 0,
    this.avgGrowth = 0,
    this.fcr = 0,
    this.healthIndicator = "Healthy",
    this.isLoading = false,
    this.error,
  });
}

/// DEPRECATED: Use pond_dashboard_controller directly for each pond
/// This provider now only aggregates data from controllers - no calculations
final farmDashboardProvider = Provider<FarmDashboardState>((ref) {
  AppLogger.debug("🔥 FARM DASHBOARD PROVIDER RUNNING (AGGREGATION ONLY) 🔥");

  final farmState = ref.watch(farmProvider);
  final currentFarm = farmState.currentFarm;

  if (currentFarm == null) {
    return const FarmDashboardState();
  }

  // This provider should NOT do calculations - only aggregate from controllers
  // Individual pond data should come from pond_dashboard_controller
  // This is kept for backward compatibility only

  return const FarmDashboardState(
    totalFeed: 0,
    totalBiomass: 0,
    avgGrowth: 0,
    fcr: 0,
    healthIndicator: "Healthy",
  );
});

/// 💧 Water Task Provider for Daily Tasks UI
final waterTasksProvider = Provider<List<WaterTask>>((ref) {
  final plans = ref.watch(supplementProvider);

  return WaterTaskEngine.generateWaterTasks(
    today: DateTime.now(),
    plans: plans,
  );
});
