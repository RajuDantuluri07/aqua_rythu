import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

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
  Future<({int newStockCount, double activeStockPct})> logHarvest({
    required String pondId,
    required String harvestType, // 'partial' | 'full'
    required double quantityKg,
    int? estimatedCount,
    double? abwAtHarvest,
    required int currentStockCount,
    required int initialStockCount,
  }) async {
    // Estimate removed shrimp count if not explicitly provided
    int removedCount;
    if (estimatedCount != null) {
      removedCount = estimatedCount;
    } else if (abwAtHarvest != null && abwAtHarvest > 0) {
      removedCount = (quantityKg / abwAtHarvest * 1000).round();
    } else {
      removedCount = (currentStockCount * 0.35).round(); // default 35%
    }

    final newStockCount = harvestType == 'full'
        ? 0
        : (currentStockCount - removedCount).clamp(0, currentStockCount);

    final activeStockPct = initialStockCount > 0
        ? (newStockCount / initialStockCount).clamp(0.0, 1.0)
        : 0.0;

    final newHarvestStage = harvestType == 'full' ? 'completed' : 'partial';

    try {
      await Future.wait([
        // Insert harvest log
        _db.from('harvest_logs').insert({
          'pond_id': pondId,
          'harvest_type': harvestType,
          'quantity_kg': quantityKg,
          'estimated_count': removedCount,
          'abw_at_harvest': abwAtHarvest,
        }),
        // Update pond recalibration fields
        _db.from('ponds').update({
          'stock_count': newStockCount,
          'active_stock_pct': activeStockPct,
          'harvest_stage': newHarvestStage,
          'last_harvest_date': DateTime.now().toIso8601String(),
          'last_harvest_qty': quantityKg,
          'has_sampling': false, // force re-sampling
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', pondId),
      ]);

      AppLogger.info(
          'Harvest logged: pond=$pondId type=$harvestType qty=${quantityKg}kg '
          'removed=$removedCount newStock=$newStockCount '
          'pct=${(activeStockPct * 100).toStringAsFixed(0)}%');

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
