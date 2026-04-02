import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pond_service.dart';
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
  final PondService _pondService;

  FeedScheduleNotifier(this._pondService) : super(FeedScheduleState(days: []));

  Future<void> loadFeedSchedule(String pondId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Generate default 30-day feed plan
      final days = List.generate(30, (index) {
        final doc = index + 1;
        final baseAmount = _calculateBaseFeed(doc);
        return FeedDayPlan(
          doc: doc,
          rounds: [baseAmount, baseAmount, baseAmount, baseAmount],
        );
      });

      // Try to load existing schedule from database
      try {
        final existingData = await _pondService.getFeedSchedule(pondId);
        if (existingData.isNotEmpty) {
          final loadedDays = existingData.map((json) => FeedDayPlan.fromJson(json)).toList();
          state = state.copyWith(days: loadedDays, isLoading: false);
          return;
        }
      } catch (e) {
        AppLogger.error('No existing feed schedule found, using defaults', e);
      }

      state = state.copyWith(days: days, isLoading: false);
    } catch (e) {
      AppLogger.error('Failed to load feed schedule', e);
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load feed schedule: $e',
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
      final scheduleData = state.days.map((day) => day.toJson()).toList();
      await _pondService.saveFeedSchedule(pondId, scheduleData);
      
      state = state.copyWith(isSaving: false);
    } catch (e) {
      AppLogger.error('Failed to save feed schedule', e);
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save feed schedule: $e',
      );
      rethrow;
    }
  }

  double _calculateBaseFeed(int doc) {
    // Simple base feed calculation - can be made more sophisticated
    if (doc <= 10) {
      return 2.0 + (doc * 0.1); // 2.1 to 3.0
    } else if (doc <= 20) {
      return 3.0 + ((doc - 10) * 0.2); // 3.2 to 5.0
    } else {
      return 5.0 + ((doc - 20) * 0.3); // 5.3 to 8.0
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final feedScheduleProvider = StateNotifierProvider<FeedScheduleNotifier, FeedScheduleState>((ref) {
  final pondService = PondService();
  return FeedScheduleNotifier(pondService);
});
