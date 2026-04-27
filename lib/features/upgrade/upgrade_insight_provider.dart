import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../systems/feed/engine_constants.dart';
import '../../systems/feed/feed_calculations.dart';
import '../farm/farm_provider.dart';
import '../feed/feed_history_provider.dart';
import '../tray/enums/tray_status.dart';

class UpgradeExperimentFlags {
  final bool showLossProjection;
  final bool highlightPopularPlan;
  final bool stickyCtaEnabled;
  final bool autoScrollToPricing;

  const UpgradeExperimentFlags({
    this.showLossProjection = true,
    this.highlightPopularPlan = true,
    this.stickyCtaEnabled = true,
    this.autoScrollToPricing = true,
  });
}

const upgradeExperimentFlags = UpgradeExperimentFlags();

class UpgradeLossInsight {
  final double actualFeed;
  final double expectedFeed;
  final double feedCostPerKg;
  final double trayFactor;
  final double smartFactor;
  final double finalFactor;
  final double abw;
  final int doc;
  final bool hasTrayData;
  final bool hasRealFeedData;
  final bool isSimulated;
  final String pondName;

  const UpgradeLossInsight({
    required this.actualFeed,
    required this.expectedFeed,
    required this.feedCostPerKg,
    required this.trayFactor,
    required this.smartFactor,
    required this.finalFactor,
    required this.abw,
    required this.doc,
    required this.hasTrayData,
    required this.hasRealFeedData,
    required this.isSimulated,
    required this.pondName,
  });

  factory UpgradeLossInsight.simulated({int doc = 35}) {
    return UpgradeLossInsight(
      actualFeed: 10.0,
      expectedFeed: 9.2,
      feedCostPerKg: 65.0,
      trayFactor: 0.92,
      smartFactor: 0.92,
      finalFactor: 0.92,
      abw: getExpectedABW(doc),
      doc: doc < 1 ? 1 : doc,
      hasTrayData: false,
      hasRealFeedData: false,
      isSimulated: true,
      pondName: 'Your pond',
    );
  }

  double get extraFeed => math.max(0.0, actualFeed - expectedFeed);
  double get moneyLoss => extraFeed * feedCostPerKg;
  int get roundedLoss => moneyLoss.round();
  int get remainingDays => math.max(1, 120 - doc);
  double get projectedCropLoss => moneyLoss * remainingDays;

  double get overfeedPercent {
    if (expectedFeed <= 0) return 0;
    return (extraFeed / expectedFeed) * 100;
  }

  int get correctionPercent => ((finalFactor - 1.0) * 100).round();

  String get riskLabel {
    if (moneyLoss >= 50 || overfeedPercent >= 8) return 'HIGH';
    if (moneyLoss > 0 || overfeedPercent >= 3) return 'MEDIUM';
    return 'LOW';
  }

  String get insightMode {
    if (isSimulated || doc < 30) return 'Basic insight';
    return hasTrayData ? 'Tray-backed insight' : 'Smart insight';
  }

  String get correctionLabel {
    if (correctionPercent == 0) return '0%';
    return correctionPercent > 0
        ? '+$correctionPercent%'
        : '$correctionPercent%';
  }

  String get lossTodayLabel => formatCurrency(moneyLoss);
  String get actualFeedLabel => '${_oneDecimal(actualFeed)} kg';
  String get expectedFeedLabel => '${_oneDecimal(expectedFeed)} kg';
  String get extraFeedLabel => '${_oneDecimal(extraFeed)} kg';

  String get cropLossRangeLabel {
    if (!upgradeExperimentFlags.showLossProjection || moneyLoss <= 0) {
      return '₹3,000-₹10,000 per crop';
    }

    final lower = math.max(3000.0, projectedCropLoss * 0.8);
    final upper =
        math.max(math.max(10000.0, projectedCropLoss * 1.4), lower + 1000.0);

    return '${formatCurrency(lower)}-${formatCurrency(upper)} per crop';
  }

  List<String> get explanationBullets {
    final trayLine = hasTrayData
        ? _trayExplanation
        : isSimulated
            ? 'Basic feed pattern indicates extra feed'
            : 'Feed log is above expected need';

    return [
      trayLine,
      'Overfeeding risk: $riskLabel',
      'Suggested correction: $correctionLabel',
    ];
  }

  String get _trayExplanation {
    if (trayFactor < 0.98) return 'Tray leftover detected';
    if (trayFactor > 1.02) return 'Tray empty: appetite higher';
    return 'Tray response stable';
  }

  static String formatCurrency(num value) {
    final rounded = value.round();
    final sign = rounded < 0 ? '-' : '';
    final digits = rounded.abs().toString();
    if (digits.length <= 3) return '$sign₹$digits';

    final lastThree = digits.substring(digits.length - 3);
    var leading = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (leading.length > 2) {
      groups.insert(0, leading.substring(leading.length - 2));
      leading = leading.substring(0, leading.length - 2);
    }
    if (leading.isNotEmpty) groups.insert(0, leading);

    return '$sign₹${groups.join(',')},$lastThree';
  }

  static String _oneDecimal(double value) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}

final upgradeLossInsightProvider =
    FutureProvider<UpgradeLossInsight>((ref) async {
  final farmState = ref.watch(farmProvider);
  final history = ref.watch(feedHistoryProvider);
  final farm = farmState.currentFarm;
  final pond = _currentPond(farm);

  if (pond == null || pond.doc < 1) {
    return UpgradeLossInsight.simulated();
  }

  var feedCost = 65.0;
  try {
    feedCost = await FeedEngineConstants.getFeedCostPerKg(farmId: farm?.id);
  } catch (e) {
    debugPrint('Upgrade feed cost fallback used: $e');
  }

  final todayLog = _todayFeedLog(history[pond.id] ?? const []);
  final expectedFromEngine = _expectedFeedFromEngine(pond);
  final actualFeed = todayLog?.total ?? 0.0;
  final expectedFeed =
      (todayLog?.expected ?? 0) > 0 ? todayLog!.expected : expectedFromEngine;

  final shouldSimulate = actualFeed <= 0 || expectedFeed <= 0;
  if (shouldSimulate) {
    return UpgradeLossInsight.simulated(doc: pond.doc);
  }

  final trayStatuses =
      todayLog?.trayStatuses.whereType<TrayStatus>().toList() ??
          const <TrayStatus>[];
  final hasTrayData = trayStatuses.isNotEmpty;
  final trayFactor = hasTrayData ? calculateTrayFactor(trayStatuses) : 1.0;
  final smartFactor = actualFeed > 0
      ? (expectedFeed / actualFeed).clamp(0.70, 1.30).toDouble()
      : 1.0;
  final finalFactor = hasTrayData ? trayFactor : smartFactor;

  return UpgradeLossInsight(
    actualFeed: actualFeed,
    expectedFeed: expectedFeed,
    feedCostPerKg: feedCost,
    trayFactor: trayFactor,
    smartFactor: smartFactor,
    finalFactor: finalFactor,
    abw: pond.currentAbw ?? getExpectedABW(pond.doc),
    doc: pond.doc,
    hasTrayData: hasTrayData,
    hasRealFeedData: true,
    isSimulated: false,
    pondName: pond.name,
  );
});

Pond? _currentPond(Farm? farm) {
  if (farm == null || farm.ponds.isEmpty) return null;
  for (final pond in farm.ponds) {
    if (pond.status == PondStatus.active) return pond;
  }
  return farm.ponds.first;
}

FeedHistoryLog? _todayFeedLog(List<FeedHistoryLog> logs) {
  final now = DateTime.now();
  for (final log in logs) {
    if (log.date.year == now.year &&
        log.date.month == now.month &&
        log.date.day == now.day) {
      return log;
    }
  }
  return null;
}

double _expectedFeedFromEngine(Pond pond) {
  final expected = docFeedCurve(pond.doc) * (pond.seedCount / 100000.0);
  if (expected.isNaN || expected.isInfinite || expected <= 0) return 0.0;
  return expected;
}

class UpgradeMetrics {
  static void track(String event, Map<String, Object?> properties) {
    debugPrint('[upgrade_metric] $event $properties');
  }

  static void trackCtaClick({
    required String source,
    required String plan,
    required UpgradeLossInsight insight,
  }) {
    track('cta_click', {
      'source': source,
      'plan': plan,
      'doc': insight.doc,
      'loss_today': insight.roundedLoss,
      'projected_crop_loss': insight.projectedCropLoss.round(),
      'simulated': insight.isSimulated,
    });
  }
}
