import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/farm_price_settings.dart';

class FarmPriceSettingsService {
  static const _feedKey = 'farm_feed_price_';
  static const _sellKey = 'farm_sell_price_';

  Future<FarmPriceSettings> load(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    return FarmPriceSettings(
      feedPricePerKg: prefs.getDouble('$_feedKey$farmId'),
      sellPricePerKg: prefs.getDouble('$_sellKey$farmId'),
    );
  }

  Future<void> save(String farmId, FarmPriceSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.feedPricePerKg != null) {
      await prefs.setDouble('$_feedKey$farmId', settings.feedPricePerKg!);
    } else {
      await prefs.remove('$_feedKey$farmId');
    }
    if (settings.sellPricePerKg != null) {
      await prefs.setDouble('$_sellKey$farmId', settings.sellPricePerKg!);
    } else {
      await prefs.remove('$_sellKey$farmId');
    }
  }
}

class FarmPriceSettingsNotifier
    extends StateNotifier<AsyncValue<FarmPriceSettings>> {
  final String farmId;
  final FarmPriceSettingsService _service;

  FarmPriceSettingsNotifier(this.farmId, this._service)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _service.load(farmId);
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(FarmPriceSettings settings) async {
    await _service.save(farmId, settings);
    state = AsyncValue.data(settings);
  }
}

final farmPriceSettingsProvider = StateNotifierProvider.family<
    FarmPriceSettingsNotifier, AsyncValue<FarmPriceSettings>, String>(
  (ref, farmId) =>
      FarmPriceSettingsNotifier(farmId, FarmPriceSettingsService()),
);
