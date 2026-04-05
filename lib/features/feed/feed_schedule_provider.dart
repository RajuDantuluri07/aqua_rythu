import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/feed_service.dart';
import '../../core/utils/logger.dart';

class FeedDayPlan {
  final int doc;
  final List<double> rounds;

  FeedDayPlan({required this.doc, required this.rounds});

  double get total => rounds.fold(0.0, (sum, qty) => sum + qty);

  FeedDayPlan copyWith({List<double>? rounds}) {
    return FeedDayPlan(
      doc: doc,
      rounds: rounds ?? this.rounds,
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

  double get totalProjectedFeed => days.fold(0.0, (sum, day) => sum + day.total);

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

  FeedScheduleNotifier(this._feedService) : super(FeedScheduleState(days: [], isLoading: true));

  Future<void> loadFeedSchedule(String pondId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final existingData = await _feedService.getFeedPlans(pondId);

      if (existingData.isEmpty) {
        // No scary error - just return empty state
        state = state.copyWith(isLoading: false);
        return;
      }

      final Map<int, List<double>> groupedData = {};

      for (final item in existingData) {
        final doc = item['doc'] as int;
        final round = item['round'] as int;
        final feedAmount = (item['planned_amount'] as num).toDouble();

        groupedData.putIfAbsent(doc, () => [0.0, 0.0, 0.0, 0.0]);

        if (round >= 1 && round <= 4) {
          groupedData[doc]![round - 1] = feedAmount;
        }
      }

      final loadedDays = groupedData.entries
          .map((entry) => FeedDayPlan(
                doc: entry.key,
                rounds: entry.value,
              ))
          .toList()
        ..sort((a, b) => a.doc.compareTo(b.doc));

      state = state.copyWith(days: loadedDays, isLoading: false);
      print("✅ Loaded feed schedule from DB: ${loadedDays.length} days");
    } catch (e) {
      AppLogger.error('Failed to load feed schedule', e);
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
    }
  }

  void updateFeed(int docIndex, int roundIndex, double value) {
    if (docIndex < 0 || docIndex >= state.days.length) return;
    
    final updatedDays = List<FeedDayPlan>.from(state.days);
    final day = updatedDays[docIndex];
    final updatedRounds = List<double>.from(day.rounds);
    updatedRounds[roundIndex] = value;
    
    updatedDays[docIndex] = day.copyWith(rounds: updatedRounds);
    
    state = state.copyWith(days: updatedDays);
  }

  Future<void> saveFeedSchedule(String pondId) async {
    state = state.copyWith(isSaving: true, error: null);
    
    try {
      await _feedService.saveFeedPlans(pondId, state.days);
      
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
final feedScheduleProvider = StateNotifierProvider<FeedScheduleNotifier, FeedScheduleState>((ref) {
  final feedService = FeedService();
  return FeedScheduleNotifier(feedService);
});
