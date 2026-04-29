import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Confidence level for time source
enum TimeConfidence {
  high,   // Server time available
  low,    // Fallback to device time (sync issue)
}

/// Server time state with confidence indicator
class ServerTimeState {
  final DateTime? time;
  final TimeConfidence confidence;
  final bool isLoading;
  final String? errorMessage;

  const ServerTimeState({
    this.time,
    this.confidence = TimeConfidence.high,
    this.isLoading = false,
    this.errorMessage,
  });

  ServerTimeState copyWith({
    DateTime? time,
    TimeConfidence? confidence,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ServerTimeState(
      time: time ?? this.time,
      confidence: confidence ?? this.confidence,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for server time from Supabase
/// Falls back to device time if server is unavailable
final serverTimeProvider = StateNotifierProvider<ServerTimeNotifier, ServerTimeState>((ref) {
  return ServerTimeNotifier();
});

class ServerTimeNotifier extends StateNotifier<ServerTimeState> {
  final _supabase = Supabase.instance.client;

  ServerTimeNotifier() : super(const ServerTimeState(isLoading: true)) {
    _fetchServerTime();
    // Refresh server time every 5 minutes to stay synced
    _startPeriodicRefresh();
  }

  Future<void> _fetchServerTime() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final response = await _supabase.rpc('get_server_time');

      if (response == null || response is! String) {
        throw Exception('Invalid response from server');
      }

      final serverTime = DateTime.parse(response);
      
      state = ServerTimeState(
        time: serverTime,
        confidence: TimeConfidence.high,
        isLoading: false,
      );

      AppLogger.info('Server time synced: $serverTime');
    } catch (e) {
      AppLogger.error('Failed to fetch server time, using device fallback', e);
      
      // Fallback to device time with low confidence
      state = ServerTimeState(
        time: DateTime.now().toUtc(),
        confidence: TimeConfidence.low,
        isLoading: false,
        errorMessage: 'Using device time (sync issue)',
      );
    }
  }

  void _startPeriodicRefresh() {
    // Refresh every 5 minutes
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 5));
      await _fetchServerTime();
      return true;
    });
  }

  /// Manual refresh (e.g., after network reconnect)
  Future<void> refresh() async {
    await _fetchServerTime();
  }
}

/// Convenience provider to get just the DateTime (null if loading)
final serverDateTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(serverTimeProvider).time;
});

/// Convenience provider to get confidence level
final timeConfidenceProvider = Provider<TimeConfidence>((ref) {
  return ref.watch(serverTimeProvider).confidence;
});
