import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLanguageKey = 'language_code';
const _kDefaultLocale = 'te'; // Default: Telugu

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale(_kDefaultLocale));

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLanguageKey) ?? _kDefaultLocale;
    state = Locale(code);
  }

  Future<void> change(String languageCode) async {
    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, languageCode);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  final notifier = LanguageNotifier();
  notifier.loadSaved();
  return notifier;
});
