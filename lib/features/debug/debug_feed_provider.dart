import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';

class DebugLog {
  final String id;
  final int doc;
  final String mode;
  final double baseFeed;
  final double trayFactor;
  final double smartFactor;
  final double samplingFactor;
  final double? abw;
  final double? expectedAbw;
  final double finalFactor;
  final double finalFeed;
  final String? reason;
  final DateTime createdAt;

  DebugLog({
    required this.id,
    required this.doc,
    required this.mode,
    required this.baseFeed,
    required this.trayFactor,
    required this.smartFactor,
    required this.samplingFactor,
    this.abw,
    this.expectedAbw,
    required this.finalFactor,
    required this.finalFeed,
    this.reason,
    required this.createdAt,
  });

  factory DebugLog.fromMap(Map<String, dynamic> m) {
    return DebugLog(
      id: m['id'] as String,
      doc: m['doc'] as int,
      mode: m['mode'] as String,
      baseFeed: (m['base_feed'] as num).toDouble(),
      trayFactor: (m['tray_factor'] as num).toDouble(),
      smartFactor: (m['smart_factor'] as num).toDouble(),
      samplingFactor: (m['sampling_factor'] as num?)?.toDouble() ?? 1.0,
      abw: (m['abw'] as num?)?.toDouble(),
      expectedAbw: (m['expected_abw'] as num?)?.toDouble(),
      finalFactor: (m['final_factor'] as num).toDouble(),
      finalFeed: (m['final_feed'] as num).toDouble(),
      reason: m['reason'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  /// Raw combined factor before safety guards (tray × smart × sampling).
  double get rawFactor => trayFactor * smartFactor * samplingFactor;

  /// Feed change as a signed percentage string e.g. "+5%" / "-8%".
  String get changeLabel {
    final pct = ((finalFactor - 1.0) * 100).round();
    return pct >= 0 ? '+$pct%' : '$pct%';
  }

  // ── Decision flags ────────────────────────────────────────────────────────

  bool get isTrayApplied => (trayFactor - 1.0).abs() > 0.005;
  bool get isSmartApplied => (smartFactor - 1.0).abs() > 0.005;

  /// True when safety guards changed the raw factor.
  bool get isClamped => (rawFactor - finalFactor).abs() > 0.005;

  /// True when engine held feed at 1.0 despite raw factor being > 1.0
  /// (overfeeding protection rule).
  bool get isOverfeedingHold =>
      (finalFactor - 1.0).abs() < 0.005 && rawFactor > 1.005;

  /// True when decrease streak cap fired (3 consecutive decreases → hold).
  bool get isDecreaseStreakLimited =>
      (finalFactor - 1.0).abs() < 0.005 && rawFactor < 0.995;
}

class TrayDay {
  final String label; // "Day -1", "Day -2", "Day -3"
  final String status; // "Empty" / "Partial" / "Full"
  final int pct; // leftover %

  TrayDay({required this.label, required this.status, required this.pct});
}

class DebugState {
  final List<DebugLog> logs;
  final List<TrayDay> trayDays;
  final bool isLoading;
  final String? error;

  DebugState({
    this.logs = const [],
    this.trayDays = const [],
    this.isLoading = false,
    this.error,
  });

  DebugLog? get latest => logs.isEmpty ? null : logs.first;

  DebugState copyWith({
    List<DebugLog>? logs,
    List<TrayDay>? trayDays,
    bool? isLoading,
    String? error,
  }) {
    return DebugState(
      logs: logs ?? this.logs,
      trayDays: trayDays ?? this.trayDays,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class DebugFeedNotifier extends StateNotifier<DebugState> {
  final _supabase = Supabase.instance.client;

  DebugFeedNotifier() : super(DebugState());

  Future<void> load(String pondId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _fetchLogs(pondId),
        _fetchTrayDays(pondId),
      ]);

      state = state.copyWith(
        logs: results[0] as List<DebugLog>,
        trayDays: results[1] as List<TrayDay>,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('DebugFeedNotifier.load failed', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<DebugLog>> _fetchLogs(String pondId) async {
    final rows = await _supabase
        .from('feed_debug_logs')
        .select()
        .eq('pond_id', pondId)
        .order('created_at', ascending: false)
        .limit(20);
    return rows.map((r) => DebugLog.fromMap(r)).toList();
  }

  Future<List<TrayDay>> _fetchTrayDays(String pondId) async {
    final since = DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String()
        .split('T')[0];
    final rows = await _supabase
        .from('tray_logs')
        .select('date, tray_statuses')
        .eq('pond_id', pondId)
        .gte('date', since)
        .order('date', ascending: false)
        .limit(3);

    final days = <TrayDay>[];
    for (int i = 0; i < rows.length; i++) {
      final statuses =
          List<String>.from(rows[i]['tray_statuses'] as List? ?? []);
      final (status, pct) = _resolveStatus(statuses);
      days.add(TrayDay(label: 'Day -${i + 1}', status: status, pct: pct));
    }
    return days;
  }

  (String, int) _resolveStatus(List<String> statuses) {
    if (statuses.isEmpty) return ('Empty', 0);
    int full = 0, empty = 0;
    for (final s in statuses) {
      if (s == 'full') full++;
      if (s == 'empty') empty++;
    }
    final majority = statuses.length / 2;
    if (full > majority) return ('Full', 70);
    if (empty > majority) return ('Empty', 0);
    return ('Partial', 30);
  }
}

final debugFeedProvider =
    StateNotifierProvider.family<DebugFeedNotifier, DebugState, String>(
  (ref, pondId) => DebugFeedNotifier(),
);
