import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ================= MODEL =================
class WaterLog {
  final DateTime date;
  final int doc;
  final double ph;
  final double oxygen;
  final double temperature;
  final double ammonia;

  WaterLog({
    required this.date,
    required this.doc,
    required this.ph,
    required this.oxygen,
    required this.temperature,
    required this.ammonia,
  });
}

class WaterState {
  final double ph;           // pH level
  final double oxygen;       // Dissolved Oxygen (mg/L)
  final double temperature;  // °C
  final List<WaterLog> logs;

  const WaterState({
    this.ph = 7.5,
    this.oxygen = 5.0,
    this.temperature = 28.0,
    this.logs = const [],
  });

  WaterState copyWith({
    double? ph,
    double? oxygen,
    double? temperature,
    List<WaterLog>? logs,
  }) {
    return WaterState(
      ph: ph ?? this.ph,
      oxygen: oxygen ?? this.oxygen,
      temperature: temperature ?? this.temperature,
      logs: logs ?? this.logs,
    );
  }
}

/// ================= NOTIFIER =================
class WaterNotifier extends StateNotifier<WaterState> {
  WaterNotifier() : super(const WaterState());

  /// 🔄 UPDATE WATER VALUES
  void update({
    double? ph,
    double? oxygen,
    double? temperature,
    double? ammonia,
    required int doc,
  }) {
    final newLog = WaterLog(
      date: DateTime.now(),
      doc: doc,
      ph: ph ?? state.ph,
      oxygen: oxygen ?? state.oxygen,
      temperature: temperature ?? state.temperature,
      ammonia: ammonia ?? 0.0,
    );

    state = state.copyWith(
      ph: ph,
      oxygen: oxygen,
      temperature: temperature,
      logs: [newLog, ...state.logs],
    );
  }

  /// ================= STATUS LOGIC =================

  /// 🧠 OVERALL WATER STATUS
  String get status {
    if (state.oxygen < 3) return "Danger";
    if (state.ph < 6.5 || state.ph > 8.5) return "Warning";
    return "Good";
  }

  /// 🧪 INDIVIDUAL STATUS (optional, useful later)
  String get phStatus {
    if (state.ph < 6.5 || state.ph > 8.5) return "Warning";
    return "Good";
  }

  String get oxygenStatus {
    if (state.oxygen < 3) return "Danger";
    if (state.oxygen < 5) return "Low";
    return "Good";
  }

  String get temperatureStatus {
    if (state.temperature < 20 || state.temperature > 32) {
      return "Warning";
    }
    return "Good";
  }
}

/// ================= PROVIDER =================
final waterProvider =
    StateNotifierProvider.family<WaterNotifier, WaterState, String>(
  (ref, pondId) => WaterNotifier(),
);