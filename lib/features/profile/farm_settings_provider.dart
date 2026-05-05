import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/utils/logger.dart';

class FarmSettings {
  final String farmType; // "Semi-Intensive" or "Intensive"
  final int feedsPerDay; // 2, 3, 4, or 5
  final double feedPrice; // ₹/kg
  final int blindFeedingDays; // Duration of blind feeding
  final int feedJumpThreshold; // % threshold for jump
  final List<String> feedTimes; // ["6 AM", "10 AM", "2 PM", "6 PM"]
  final double trayCalibration30_60; // % of feed for DOC 30-60
  final double trayCalibration60_90; // % of feed for DOC 60-90
  final double trayCalibration90Plus; // % of feed for DOC 90+

  FarmSettings({
    this.farmType = "Semi-Intensive",
    this.feedsPerDay = 4,
    this.feedPrice = 90.0,
    this.blindFeedingDays = 30,
    this.feedJumpThreshold = 30,
    this.feedTimes = const ["6 AM", "10 AM", "2 PM", "6 PM"],
    this.trayCalibration30_60 = 0.3,
    this.trayCalibration60_90 = 0.6,
    this.trayCalibration90Plus = 1.0,
  });

  FarmSettings copyWith({
    String? farmType,
    int? feedsPerDay,
    double? feedPrice,
    int? blindFeedingDays,
    int? feedJumpThreshold,
    List<String>? feedTimes,
    double? trayCalibration30_60,
    double? trayCalibration60_90,
    double? trayCalibration90Plus,
  }) {
    return FarmSettings(
      farmType: farmType ?? this.farmType,
      feedsPerDay: feedsPerDay ?? this.feedsPerDay,
      feedPrice: feedPrice ?? this.feedPrice,
      blindFeedingDays: blindFeedingDays ?? this.blindFeedingDays,
      feedJumpThreshold: feedJumpThreshold ?? this.feedJumpThreshold,
      feedTimes: feedTimes ?? this.feedTimes,
      trayCalibration30_60: trayCalibration30_60 ?? this.trayCalibration30_60,
      trayCalibration60_90: trayCalibration60_90 ?? this.trayCalibration60_90,
      trayCalibration90Plus: trayCalibration90Plus ?? this.trayCalibration90Plus,
    );
  }

  // Serialize for storage
  Map<String, dynamic> toJson() => {
    'farmType': farmType,
    'feedsPerDay': feedsPerDay,
    'feedPrice': feedPrice,
    'blindFeedingDays': blindFeedingDays,
    'feedJumpThreshold': feedJumpThreshold,
    'feedTimes': feedTimes,
    'trayCalibration30_60': trayCalibration30_60,
    'trayCalibration60_90': trayCalibration60_90,
    'trayCalibration90Plus': trayCalibration90Plus,
  };

  // Deserialize from storage
  factory FarmSettings.fromJson(Map<String, dynamic> json) {
    return FarmSettings(
      farmType: json['farmType'] ?? "Semi-Intensive",
      feedsPerDay: json['feedsPerDay'] ?? 4,
      feedPrice: (json['feedPrice'] ?? 90.0).toDouble(),
      blindFeedingDays: json['blindFeedingDays'] ?? 30,
      feedJumpThreshold: json['feedJumpThreshold'] ?? 30,
      feedTimes: List<String>.from(json['feedTimes'] ?? ["6 AM", "10 AM", "2 PM", "6 PM"]),
      trayCalibration30_60: (json['trayCalibration30_60'] ?? 0.3).toDouble(),
      trayCalibration60_90: (json['trayCalibration60_90'] ?? 0.6).toDouble(),
      trayCalibration90Plus: (json['trayCalibration90Plus'] ?? 1.0).toDouble(),
    );
  }
}

// Global variable to hold SharedPreferences instance
SharedPreferences? _sharedPreferences;

void initializeFarmSettings(SharedPreferences prefs) {
  _sharedPreferences = prefs;
}

class FarmSettingsNotifier extends StateNotifier<FarmSettings> {
  static const String _storageKey = 'farm_settings';

  FarmSettingsNotifier() : super(FarmSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_sharedPreferences == null) return;
    try {
      final jsonString = _sharedPreferences!.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        state = FarmSettings.fromJson(json);
      }
    } catch (e) {
      AppLogger.error('Error loading farm settings', e);
    }
  }

  Future<void> _saveSettings() async {
    if (_sharedPreferences == null) return;
    try {
      await _sharedPreferences!.setString(_storageKey, jsonEncode(state.toJson()));
    } catch (e) {
      AppLogger.error('Error saving farm settings', e);
    }
  }

  void setFarmType(String type) async {
    state = state.copyWith(farmType: type);
    await _saveSettings();
  }

  void setFeedsPerDay(int count) async {
    state = state.copyWith(feedsPerDay: count);
    await _saveSettings();
  }

  void setFeedPrice(double price) async {
    state = state.copyWith(feedPrice: price);
    await _saveSettings();
  }

  void setBlindFeedingDays(int days) async {
    state = state.copyWith(blindFeedingDays: days);
    await _saveSettings();
  }

  void setFeedJumpThreshold(int threshold) async {
    state = state.copyWith(feedJumpThreshold: threshold);
    await _saveSettings();
  }

  void setFeedTimes(List<String> times) async {
    state = state.copyWith(feedTimes: times);
    await _saveSettings();
  }

  void setTrayCalibration({
    double? doc30_60,
    double? doc60_90,
    double? doc90Plus,
  }) async {
    state = state.copyWith(
      trayCalibration30_60: doc30_60,
      trayCalibration60_90: doc60_90,
      trayCalibration90Plus: doc90Plus,
    );
    await _saveSettings();
  }

  Future<void> saveAllSettings({
    required String farmType,
    required int feedsPerDay,
    required double feedPrice,
    required int blindFeedingDays,
    required int feedJumpThreshold,
    required List<String> feedTimes,
    required double trayCalibration30_60,
    required double trayCalibration60_90,
    required double trayCalibration90Plus,
  }) async {
    state = FarmSettings(
      farmType: farmType,
      feedsPerDay: feedsPerDay,
      feedPrice: feedPrice,
      blindFeedingDays: blindFeedingDays,
      feedJumpThreshold: feedJumpThreshold,
      feedTimes: feedTimes,
      trayCalibration30_60: trayCalibration30_60,
      trayCalibration60_90: trayCalibration60_90,
      trayCalibration90Plus: trayCalibration90Plus,
    );
    await _saveSettings();
  }
}

// Simple StateNotifierProvider
final farmSettingsProvider =
    StateNotifierProvider<FarmSettingsNotifier, FarmSettings>((ref) {
  return FarmSettingsNotifier();
});

