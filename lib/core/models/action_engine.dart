import 'package:flutter/material.dart';
import '../../features/farm/farm_provider.dart';
import '../../features/growth/sampling_log.dart';

// ── Action types in priority order (lower index = higher priority) ────────────
enum ActionType {
  sampling,       // priority 1
  waterAlert,     // priority 2
  partialHarvest, // priority 3
  profit,         // priority 4
  smartAdjust,    // priority 5
  finalHarvest,   // priority 6
  feed,           // priority 7
}

extension ActionTypeX on ActionType {
  int get priority => index + 1;

  String get label {
    switch (this) {
      case ActionType.sampling:       return 'Sampling Required';
      case ActionType.waterAlert:     return 'Water Alert';
      case ActionType.partialHarvest: return 'Partial Harvest';
      case ActionType.profit:         return 'Profit Opportunity';
      case ActionType.smartAdjust:    return 'Smart Feed Adjustment';
      case ActionType.finalHarvest:   return 'Ready for Harvest';
      case ActionType.feed:           return 'Feed Reminder';
    }
  }

  IconData get icon {
    switch (this) {
      case ActionType.sampling:       return Icons.science_outlined;
      case ActionType.waterAlert:     return Icons.water_drop_outlined;
      case ActionType.partialHarvest: return Icons.moving_outlined;
      case ActionType.profit:         return Icons.trending_up_rounded;
      case ActionType.smartAdjust:    return Icons.auto_fix_high_rounded;
      case ActionType.finalHarvest:   return Icons.agriculture_outlined;
      case ActionType.feed:           return Icons.set_meal_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ActionType.sampling:       return const Color(0xFF1565C0);
      case ActionType.waterAlert:     return const Color(0xFF0097A7);
      case ActionType.partialHarvest: return const Color(0xFFE65100);
      case ActionType.profit:         return const Color(0xFF14613B);
      case ActionType.smartAdjust:    return const Color(0xFF6A1B9A);
      case ActionType.finalHarvest:   return const Color(0xFF1B8A4C);
      case ActionType.feed:           return const Color(0xFF4A5560);
    }
  }
}

// ── Action model ──────────────────────────────────────────────────────────────

class FarmAction {
  final ActionType type;
  final Pond pond;
  final String title;
  final String message;
  final String? impact;

  const FarmAction({
    required this.type,
    required this.pond,
    required this.title,
    required this.message,
    this.impact,
  });

  int get priority => type.priority;
}

// ── Engine ────────────────────────────────────────────────────────────────────

class ActionEngine {
  static const _densityThreshold = 50000.0; // shrimp per acre
  static const _partialHarvestAbw = 15.0;   // grams
  static const _partialHarvestDoc = 55;
  static const _finalHarvestAbw = 25.0;     // grams
  static const _samplingIntervalDays = 10;
  static const _plateauGrowthGrams = 1.0;   // < 1g in 10 days = plateau

  /// Evaluate all ponds and return top 1–2 prioritised actions.
  static List<FarmAction> evaluate({
    required List<Pond> ponds,
    required Map<String, List<SamplingLog>> growthData,
  }) {
    final actions = <FarmAction>[];

    for (final pond in ponds) {
      final abw = pond.currentAbw ?? 0.0;
      final stockCount = pond.stockCount ?? pond.seedCount;
      final densityPerAcre = pond.area > 0 ? stockCount / pond.area : 0.0;
      final logs = growthData[pond.id] ?? [];

      // 2.3 Sampling (highest priority – checked first)
      if (_needsSampling(pond)) {
        final daysSince = pond.latestSampleDate != null
            ? DateTime.now().difference(pond.latestSampleDate!).inDays
            : null;
        final isPostHarvest = pond.harvestStage == 'partial';
        actions.add(FarmAction(
          type: ActionType.sampling,
          pond: pond,
          title: 'Sampling Required',
          message: isPostHarvest
              ? 'Post-harvest sampling needed to recalibrate feed plan.'
              : daysSince != null
                  ? 'Last sampled $daysSince days ago — growth data stale.'
                  : 'No sampling recorded. Add first sample to activate smart feed.',
        ));
      }

      // 2.2 Final harvest (check before partial — higher urgency if ABW is very high)
      if (_isFinalHarvestReady(abw, logs) &&
          pond.harvestStage != 'completed') {
        actions.add(FarmAction(
          type: ActionType.finalHarvest,
          pond: pond,
          title: 'Ready for Final Harvest',
          message: abw >= _finalHarvestAbw
              ? 'ABW ${abw.toStringAsFixed(1)}g — optimal market size reached.'
              : 'Growth plateau detected. Harvest now to maximise profit.',
          impact: '~₹${_estimateRevenue(stockCount, abw)}',
        ));
      }

      // 2.1 Partial harvest
      if (pond.doc >= _partialHarvestDoc &&
          densityPerAcre > _densityThreshold &&
          abw >= _partialHarvestAbw &&
          pond.harvestStage != 'completed') {
        actions.add(FarmAction(
          type: ActionType.partialHarvest,
          pond: pond,
          title: 'Partial Harvest Recommended',
          message: 'High density (${densityPerAcre.toStringAsFixed(0)}/acre). '
              'Remove 30–40% stock to boost growth rate.',
          impact: 'Density relief + feed savings',
        ));
      }
    }

    // Sort by priority (ascending) and return top 2
    actions.sort((a, b) => a.priority.compareTo(b.priority));
    return actions.take(2).toList();
  }

  static bool _needsSampling(Pond pond) {
    if (pond.hasSampling == false) return true;
    if (pond.harvestStage == 'partial') return true;
    if (pond.latestSampleDate == null) return true;
    return DateTime.now()
            .difference(pond.latestSampleDate!)
            .inDays >=
        _samplingIntervalDays;
  }

  static bool _isFinalHarvestReady(double abw, List<SamplingLog> logs) {
    if (abw >= _finalHarvestAbw) return true;
    return _growthPlateau(logs);
  }

  static bool _growthPlateau(List<SamplingLog> logs) {
    if (logs.length < 2) return false;
    final recent = logs
        .where((l) =>
            DateTime.now().difference(l.date).inDays <= _samplingIntervalDays)
        .toList();
    if (recent.length < 2) return false;
    return (recent.first.abw - recent.last.abw).abs() < _plateauGrowthGrams;
  }

  static String _estimateRevenue(int stockCount, double abw) {
    final biomassKg = (stockCount * 0.85 * abw) / 1000;
    final revenue = biomassKg * 300;
    if (revenue >= 100000) return '${(revenue / 100000).toStringAsFixed(1)}L';
    return '${(revenue / 1000).toStringAsFixed(0)}K';
  }
}
