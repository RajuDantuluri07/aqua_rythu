import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../farm/farm_provider.dart';
import '../../feed/feed_history_provider.dart';
import '../../growth/growth_provider.dart';
import '../../expense/expense_provider.dart';
import '../../inventory/inventory_provider.dart';
import '../../../core/services/farm_price_settings_service.dart';
import '../../../core/models/inventory_item.dart';
import '../models/dashboard_metrics_model.dart';

double pondSurvivalRate(int doc) {
  if (doc <= 0) return 0.85;
  if (doc <= 30) return 0.90;
  if (doc <= 60) return 0.85;
  if (doc <= 90) return 0.80;
  return 0.75;
}

final dashboardMetricsProvider =
    Provider.family<DashboardMetrics, String>((ref, farmId) {
  final farmState = ref.watch(farmProvider);
  final ponds = (farmState.currentFarm?.ponds ?? [])
      .cast<Pond>()
      .where((p) => p.status == PondStatus.active)
      .toList();

  final feedHistory = ref.watch(feedHistoryProvider);
  final priceSettings =
      ref.watch(farmPriceSettingsProvider(farmId)).valueOrNull;

  // Inventory feed item price as fallback when price settings not configured
  final inventoryItems =
      ref.watch(inventoryProvider(farmId)).valueOrNull ?? [];
  final feedInventoryItem = inventoryItems
      .where((i) => i.category == 'feed')
      .fold<InventoryItem?>(null, (prev, i) => prev ?? i);

  final feedPrice =
      priceSettings?.feedPricePerKg ?? feedInventoryItem?.pricePerUnit;
  final sellPrice = priceSettings?.sellPricePerKg;

  // Farm-level other expenses (labour, electricity, diesel, etc.)
  final otherExpensesTotal =
      ref.watch(farmExpensesTotalProvider(farmId)).valueOrNull ?? 0.0;

  final activePonds = ponds.length;

  double totalFeedKg = 0;
  for (final pond in ponds) {
    final history = feedHistory[pond.id] ?? [];
    for (final log in history) {
      totalFeedKg += log.total;
    }
  }

  double biomassKg = 0;
  double totalSurvivalFraction = 0;

  for (final pond in ponds) {
    final doc = pond.doc;
    final survival = pondSurvivalRate(doc);
    totalSurvivalFraction += survival;

    final growthLogs = ref.watch(growthProvider(pond.id));
    final abw = growthLogs.isNotEmpty
        ? growthLogs.first.abw
        : (pond.currentAbw ?? 0.0);

    if (abw > 0) {
      biomassKg += (pond.seedCount * survival * abw) / 1000;
    }
  }

  final avgSurvival =
      activePonds > 0 ? totalSurvivalFraction / activePonds : 0.0;
  final survivalPercent = (avgSurvival * 100).clamp(0.0, 100.0);

  final feedCost = feedPrice != null ? totalFeedKg * feedPrice : 0.0;
  final productionCost = feedCost + otherExpensesTotal;

  final revenuePotential =
      sellPrice != null && biomassKg > 0 ? biomassKg * sellPrice : 0.0;
  final estimatedProfit = revenuePotential - productionCost;
  final profitMargin = revenuePotential > 0
      ? (estimatedProfit / revenuePotential * 100).clamp(-999.0, 999.0)
      : 0.0;

  return DashboardMetrics(
    estimatedBiomassKg: biomassKg,
    totalFeedKg: totalFeedKg,
    survivalPercent: survivalPercent,
    revenuePotential: revenuePotential,
    feedCost: feedCost,
    productionCost: productionCost,
    estimatedProfit: estimatedProfit,
    profitMargin: profitMargin,
    activePonds: activePonds,
  );
});
