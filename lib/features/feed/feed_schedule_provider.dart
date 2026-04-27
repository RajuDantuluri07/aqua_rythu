import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/core/services/feed_service.dart';
import '../../core/utils/logger.dart';
import '../../systems/planning/feed_plan_constants.dart';
import 'feed_history_provider.dart';

class FeedDayPlan {
  final int doc;
  final List<double> rounds; // always 4 elements

  /// Engine-calculated total feed for this DOC (sum of base_feed from DB).
  /// Used as the redistribution target. Falls back to planned_amount sum.
  final double engineTotal;

  /// Per-round manual override flags. true = farmer set this round explicitly.
  /// Auto-redistribution only touches rounds where this flag is false.
  final List<bool> isRoundManual; // always 4 elements

  FeedDayPlan({
    required this.doc,
    required this.rounds,
    this.engineTotal = 0.0,
    List<bool>? isRoundManual,
  }) : isRoundManual = isRoundManual ?? List.filled(4, false);

  /// True when at least one round carries a farmer-set value.
  bool get isAnyManual => isRoundManual.any((m) => m);

  double get total => rounds.fold(0.0, (sum, qty) => sum + qty);

  /// Number of rounds with a positive quantity.
  int get activeRounds => rounds.where((r) => r > 0).length;

  /// Quantities for rounds that are actually used (qty > 0).
  List<double> get activeFeeds => rounds.where((r) => r > 0).toList();

  FeedDayPlan copyWith({
    List<double>? rounds,
    List<bool>? isRoundManual,
  }) {
    return FeedDayPlan(
      doc: doc,
      rounds: rounds ?? List.from(this.rounds),
      engineTotal: engineTotal,
      isRoundManual: isRoundManual ?? List.from(this.isRoundManual),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doc': doc,
      'r1': rounds[0],
      'r2': rounds.length > 1 ? rounds[1] : 0.0,
      'r3': rounds.length > 2 ? rounds[2] : 0.0,
      'r4': rounds.length > 3 ? rounds[3] : 0.0,
      'total': total,
    };
  }

  factory FeedDayPlan.fromJson(Map<String, dynamic> json) {
    return FeedDayPlan(
      doc: json['doc'],
      rounds: [
        (json['r1'] as num?)?.toDouble() ?? 0.0,
        (json['r2'] as num?)?.toDouble() ?? 0.0,
        (json['r3'] as num?)?.toDouble() ?? 0.0,
        (json['r4'] as num?)?.toDouble() ?? 0.0,
      ],
    );
  }
}

class FeedScheduleState {
  final List<FeedDayPlan> days;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  FeedScheduleState({
    required this.days,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  double get totalProjectedFeed =>
      days.fold(0.0, (sum, day) => sum + day.total);

  FeedScheduleState copyWith({
    List<FeedDayPlan>? days,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return FeedScheduleState(
      days: days ?? this.days,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error ?? this.error,
    );
  }
}

class FeedScheduleNotifier extends StateNotifier<FeedScheduleState> {
  final FeedService _feedService;
  final Ref _ref;

  FeedScheduleNotifier(this._feedService, this._ref)
      : super(FeedScheduleState(days: [], isLoading: true));

  Future<void> loadFeedSchedule(String pondId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final existingData = await _feedService.getFeedPlans(pondId);

      if (existingData.isEmpty) {
        // No scary error - just return empty state
        state = state.copyWith(isLoading: false);
        return;
      }

      // Always build 4-slot lists per DOC. Rounds missing from DB stay 0.0.
      final Map<int, List<double>> groupedData = {};
      // Sum base_feed per DOC → engine-calculated total for redistribution.
      // Falls back to planned_amount when base_feed is null (older rows).
      final Map<int, double> engineTotals = {};

      for (final item in existingData) {
        final doc = item['doc'] as int;
        final round = item['round'] as int;
        final feedAmount = (item['planned_amount'] as num).toDouble();
        final baseFeed = (item['base_feed'] as num?)?.toDouble() ?? feedAmount;

        groupedData.putIfAbsent(doc, () => [0.0, 0.0, 0.0, 0.0]);

        if (round >= 1 && round <= 4) {
          groupedData[doc]![round - 1] = feedAmount;
          engineTotals[doc] = (engineTotals[doc] ?? 0.0) + baseFeed;
        }
      }

      // Guarantee exactly 4 slots even if DB had fewer rows
      for (final entry in groupedData.entries) {
        while (entry.value.length < 4) {
          entry.value.add(0.0);
        }
      }

      // Zero out any amounts stored in rounds that are inactive for their DOC.
      // This keeps the provider state clean so the schedule screen shows 0.0
      // for disabled cells, and Save cannot re-persist stale inactive amounts.
      final loadedDays = groupedData.entries.map((entry) {
        final doc = entry.key;
        final config = getFeedConfig(doc);
        final rounds = List<double>.from(entry.value);
        for (int i = 0; i < rounds.length; i++) {
          if (i >= config.splits.length || config.splits[i] == 0.0) {
            rounds[i] = 0.0;
          }
        }
        // Use base_feed sum as engineTotal; fall back to planned_amount sum.
        final eTotal =
            engineTotals[doc] ?? rounds.fold<double>(0.0, (s, r) => s + r);
        return FeedDayPlan(doc: doc, rounds: rounds, engineTotal: eTotal);
      }).toList()
        ..sort((a, b) => a.doc.compareTo(b.doc));

      state = state.copyWith(days: loadedDays, isLoading: false);
      AppLogger.info("Loaded feed schedule from DB: ${loadedDays.length} days");
    } catch (e) {
      AppLogger.error('Failed to load feed schedule', e);
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
    }
  }

  /// Updates one round value and runs smart redistribution.
  ///
  /// Returns null on success, or a non-null error string when the manual
  /// input would exceed the engine total (caller must show this to the farmer).
  String? updateFeed(int docIndex, int roundIndex, double value) {
    if (docIndex < 0 || docIndex >= state.days.length) return null;

    final updatedDays = List<FeedDayPlan>.from(state.days);
    final day = updatedDays[docIndex];
    final rounds = List<double>.from(day.rounds);
    final manual = List<bool>.from(day.isRoundManual);

    if (value <= 0) {
      // Deactivating a round — clear its manual flag
      rounds[roundIndex] = 0.0;
      manual[roundIndex] = false;
    } else {
      // Specific value → mark this round as manual
      manual[roundIndex] = true;
      rounds[roundIndex] = value;

      // Guard: manual sum must not exceed engine total
      if (day.engineTotal > 0) {
        final manualSum = _manualSum(rounds, manual);
        if (manualSum > day.engineTotal + 0.01) {
          return 'Manual feed (${manualSum.toStringAsFixed(1)} kg) exceeds '
              'recommended total (${day.engineTotal.toStringAsFixed(1)} kg)';
        }
      }
    }

    _redistribute(rounds, manual, day.engineTotal);

    updatedDays[docIndex] = day.copyWith(rounds: rounds, isRoundManual: manual);
    state = state.copyWith(days: updatedDays);
    return null;
  }

  /// Clears all manual flags, detects currently active rounds, and re-applies
  /// smart distribution from engineTotal.  Does NOT restore deactivated rounds.
  void resetToRecommended(int docIndex) {
    if (docIndex < 0 || docIndex >= state.days.length) return;

    final updatedDays = List<FeedDayPlan>.from(state.days);
    final day = updatedDays[docIndex];
    final total = day.engineTotal > 0 ? day.engineTotal : day.total;
    final manual = List<bool>.filled(4, false);
    final rounds = List<double>.from(day.rounds);

    final activeIdx = <int>[
      for (int i = 0; i < rounds.length; i++)
        if (rounds[i] > 0) i
    ];

    if (activeIdx.isEmpty) {
      // All zeroed — restore all 4 rounds equally
      final per = _round1dp(total / 4);
      for (int i = 0; i < 3; i++) {
        rounds[i] = per;
      }
      rounds[3] = _round1dp(total - per * 3);
    } else {
      final dist = _getSmartDistribution(activeIdx.length);
      for (int j = 0; j < activeIdx.length; j++) {
        rounds[activeIdx[j]] = _round1dp(total * dist[j]);
      }
      _fixRoundingDrift(rounds, manual, total);
    }

    updatedDays[docIndex] = day.copyWith(rounds: rounds, isRoundManual: manual);
    state = state.copyWith(days: updatedDays);
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Distribute remaining (engineTotal − manualSum) across non-manual active rounds.
  static void _redistribute(
      List<double> rounds, List<bool> manual, double engineTotal) {
    if (engineTotal <= 0) return;

    final remaining =
        (engineTotal - _manualSum(rounds, manual)).clamp(0.0, engineTotal);

    final autoIdx = <int>[
      for (int i = 0; i < rounds.length; i++)
        if (!manual[i] && rounds[i] > 0) i
    ];
    if (autoIdx.isEmpty) return;

    final dist = _getSmartDistribution(autoIdx.length);
    for (int j = 0; j < autoIdx.length; j++) {
      rounds[autoIdx[j]] = _round1dp(remaining * dist[j]);
    }

    _fixRoundingDrift(rounds, manual, engineTotal);
  }

  /// Percentages for smart distribution by active-round count.
  static List<double> _getSmartDistribution(int count) {
    switch (count) {
      case 1:
        return [1.0];
      case 2:
        return [0.5, 0.5];
      case 3:
        return [0.3, 0.3, 0.4];
      case 4:
        return [0.25, 0.25, 0.25, 0.25];
      default:
        return [];
    }
  }

  /// Corrects sub-0.05 kg rounding drift by adjusting the last non-manual
  /// active round so the grand total exactly matches engineTotal.
  static void _fixRoundingDrift(
      List<double> rounds, List<bool> manual, double engineTotal) {
    final diff = engineTotal - rounds.fold(0.0, (s, v) => s + v);
    if (diff.abs() < 0.05) return;
    for (int i = rounds.length - 1; i >= 0; i--) {
      if (!manual[i] && rounds[i] > 0) {
        rounds[i] = _round1dp(rounds[i] + diff);
        break;
      }
    }
  }

  static double _manualSum(List<double> rounds, List<bool> manual) => [
        for (int i = 0; i < rounds.length; i++)
          if (manual[i]) rounds[i]
      ].fold(0.0, (s, v) => s + v);

  /// Round to 1 decimal place, avoiding floating-point drift.
  static double _round1dp(double v) => (v * 10).round() / 10;

  Future<void> saveFeedSchedule(String pondId) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      await _feedService.saveFeedPlans(pondId, state.days);

      // Invalidate related caches to ensure fresh data
      _ref.invalidate(feedHistoryProvider);
      _ref.invalidate(feedScheduleProvider);

      state = state.copyWith(isSaving: false);
    } catch (e) {
      AppLogger.error('Failed to save feed plans', e);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save feed plans: $e',
      );
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final feedScheduleProvider =
    StateNotifierProvider<FeedScheduleNotifier, FeedScheduleState>((ref) {
  final feedService = FeedService();
  return FeedScheduleNotifier(feedService, ref);
});
