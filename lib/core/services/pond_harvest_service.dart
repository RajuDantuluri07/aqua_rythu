import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import '../models/crop_cycle.dart';
import 'crop_cycle_service.dart';

class PondHarvestLog {
  final String id;
  final String pondId;
  final String harvestType;
  final double quantityKg;
  final int? estimatedCount;
  final double? abwAtHarvest;
  final DateTime createdAt;

  const PondHarvestLog({
    required this.id,
    required this.pondId,
    required this.harvestType,
    required this.quantityKg,
    this.estimatedCount,
    this.abwAtHarvest,
    required this.createdAt,
  });

  factory PondHarvestLog.fromJson(Map<String, dynamic> j) => PondHarvestLog(
        id: j['id'] as String,
        pondId: j['pond_id'] as String,
        harvestType: j['harvest_type'] as String,
        quantityKg: (j['quantity_kg'] as num).toDouble(),
        estimatedCount: j['estimated_count'] as int?,
        abwAtHarvest: (j['abw_at_harvest'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PondHarvestService {
  final _db = Supabase.instance.client;

  /// Log a harvest and recalibrate pond stock + feed percentage.
  /// Pass [cropCycleId] to keep harvest_logs linked to the farm crop cycle
  /// and to trigger crop cycle status sync afterwards.
  Future<({int newStockCount, double activeStockPct})> logHarvest({
    required String pondId,
    required String harvestType, // 'partial' | 'full'
    required double quantityKg,
    int? estimatedCount,
    double? abwAtHarvest,
    required int currentStockCount,
    required int initialStockCount,
    String? cropCycleId,
    DateTime? harvestDate,
    int? doc,
    int? countPerKg,
    double? pricePerKg,
    double? harvestExpenses,
    String? notes,
  }) async {
    int removedCount;
    if (estimatedCount != null) {
      removedCount = estimatedCount;
    } else if (abwAtHarvest != null && abwAtHarvest > 0) {
      removedCount = (quantityKg / abwAtHarvest * 1000).round();
    } else {
      removedCount = (currentStockCount * 0.35).round();
    }

    final newStockCount = harvestType == 'full'
        ? 0
        : (currentStockCount - removedCount).clamp(0, currentStockCount);

    final activeStockPct = initialStockCount > 0
        ? (newStockCount / initialStockCount).clamp(0.0, 1.0)
        : 0.0;

    final newHarvestStage = harvestType == 'full' ? 'completed' : 'partial';
    final newHarvestStatus = harvestType == 'full'
        ? HarvestStatus.completed.dbValue
        : HarvestStatus.partial.dbValue;
    final newPondStatus = harvestType == 'full'
        ? PondLifecycleStatus.harvested.dbValue
        : PondLifecycleStatus.partialHarvest.dbValue;

    try {
      final harvestRow = <String, dynamic>{
        'pond_id': pondId,
        'harvest_type': harvestType,
        'quantity': quantityKg,
        'estimated_count': removedCount,
        'abw_at_harvest': abwAtHarvest,
        'date': (harvestDate ?? DateTime.now()).toIso8601String().split('T')[0],
        if (doc != null) 'doc': doc,
        if (countPerKg != null) 'count_per_kg': countPerKg,
        if (pricePerKg != null) 'price': pricePerKg,
        if (harvestExpenses != null) 'expenses': harvestExpenses,
        if (notes != null) 'notes': notes,
        if (cropCycleId != null) 'crop_cycle_id': cropCycleId,
      };

      final pondUpdate = <String, dynamic>{
        'stock_count': newStockCount,
        'active_stock_pct': activeStockPct,
        'harvest_stage': newHarvestStage,
        'harvest_status': newHarvestStatus,
        'pond_status': newPondStatus,
        'last_harvest_date': DateTime.now().toIso8601String(),
        'last_harvest_qty': quantityKg,
        'has_sampling': false,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Full harvest: detach pond from crop cycle.
      if (harvestType == 'full') {
        pondUpdate['active_crop_id'] = null;
        pondUpdate['harvested_at'] = DateTime.now().toIso8601String();
        pondUpdate['status'] = 'completed';
      }

      await Future.wait([
        _db.from('harvest_logs').insert(harvestRow),
        _db.from('ponds').update(pondUpdate).eq('id', pondId),
      ]);

      // Sync crop cycle status after pond harvest.
      if (cropCycleId != null) {
        await CropCycleService().syncCycleStatus(cropCycleId);
      }

      AppLogger.info(
          'Harvest logged: pond=$pondId type=$harvestType qty=${quantityKg}kg '
          'newStock=$newStockCount pct=${(activeStockPct * 100).toStringAsFixed(0)}%');

      return (newStockCount: newStockCount, activeStockPct: activeStockPct);
    } catch (e) {
      AppLogger.error('Failed to log harvest', e);
      rethrow;
    }
  }

  Future<List<PondHarvestLog>> getLogsForPond(String pondId) async {
    final data = await _db
        .from('harvest_logs')
        .select()
        .eq('pond_id', pondId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => PondHarvestLog.fromJson(e)).toList();
  }
}
