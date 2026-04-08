import 'package:flutter/material.dart';

/// Simple inline translation map — no code generation needed.
/// Add new keys here as the app grows.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _en = <String, String>{
    'pond': 'Pond',
    'feed': 'Feed',
    'mark_as_fed': 'Mark as Fed',
    'today_feed': "Today's Feed",
    'on_track': 'On Track',
    'next_round': 'Next Round',
    'sampling': 'Sampling',
    'water_test': 'Water Test',
    'harvest': 'Harvest',
    'history': 'History',
    'add_pond': 'Add Pond',
    'add_pond_btn': '+ ADD POND',
    'add_first_pond': 'Add First Pond',
    'change_language': 'Change Language',
    'ponds': 'Ponds',
    'no_farms': 'No farms created',
    'no_ponds': 'No ponds found',
    'create_farm_first': 'Create a farm first to add ponds',
    'create_pond_to_start': 'Create a new pond to get started',
    'feed_schedule': 'Feed Schedule',
    'supplement_mix': 'Supplement Mix',
    'tank_operations': 'TANK OPERATIONS',
    'no_feed_plan': 'No feed plan for today',
    'delete_pond': 'Delete Pond?',
    'delete_pond_confirm': "Are you sure you want to delete",
    'delete_pond_warning': 'This action cannot be undone.',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'select_farm': 'Select Farm',
    'add_new_farm': 'Add New Farm',
    'create_farm': 'Create Farm',
    'farm_name': 'Farm Name',
    'farm_created': 'Farm created successfully',
    'species': 'SPECIES',
    'doc': 'DOC',
    'survival': 'SURVIVAL',
    'days': 'Days',
    'extended_culture': 'Extended Culture Mode (DOC > 120). Efficiency may reduce - increase sampling frequency.',
    'sampling_locked': 'Sampling is locked for completed ponds',
    'water_test_locked': 'Water test is locked for completed ponds',
  };

  static const _te = <String, String>{
    'pond': 'చెరువు',
    'feed': 'ఆహారం',
    'mark_as_fed': 'ఆహారం వేసాను',
    'today_feed': 'ఈరోజు ఆహారం',
    'on_track': 'సరిగ్గా జరుగుతోంది',
    'next_round': 'తర్వాతి రౌండ్',
    'sampling': 'గ్రోత్ చెక్',
    'water_test': 'నీటి పరీక్ష',
    'harvest': 'పట్టుబడి',
    'history': 'చరిత్ర',
    'add_pond': 'చెరువు జోడించండి',
    'add_pond_btn': '+ చెరువు జోడించు',
    'add_first_pond': 'మొదటి చెరువు జోడించండి',
    'change_language': 'భాష మార్చండి',
    'ponds': 'చెరువులు',
    'no_farms': 'ఫార్మ్‌లు లేవు',
    'no_ponds': 'చెరువులు కనుగొనబడలేదు',
    'create_farm_first': 'చెరువులు జోడించడానికి ముందు ఫార్మ్ సృష్టించండి',
    'create_pond_to_start': 'ప్రారంభించడానికి కొత్త చెరువు సృష్టించండి',
    'feed_schedule': 'ఫీడ్ షెడ్యూల్',
    'supplement_mix': 'సప్లిమెంట్ మిక్స్',
    'tank_operations': 'టాంక్ కార్యకలాపాలు',
    'no_feed_plan': 'ఈరోజు ఆహార ప్రణాళిక లేదు',
    'delete_pond': 'చెరువు తొలగించాలా?',
    'delete_pond_confirm': 'మీరు ఖచ్చితంగా తొలగించాలనుకుంటున్నారా',
    'delete_pond_warning': 'ఈ చర్యను రద్దు చేయడం సాధ్యం కాదు.',
    'cancel': 'రద్దు',
    'delete': 'తొలగించు',
    'select_farm': 'ఫార్మ్ ఎంచుకోండి',
    'add_new_farm': 'కొత్త ఫార్మ్ జోడించండి',
    'create_farm': 'ఫార్మ్ సృష్టించు',
    'farm_name': 'ఫార్మ్ పేరు',
    'farm_created': 'ఫార్మ్ విజయవంతంగా సృష్టించబడింది',
    'species': 'జాతి',
    'doc': 'డాక్',
    'survival': 'మనుగడ',
    'days': 'రోజులు',
    'extended_culture': 'పొడిగించిన సాగు మోడ్ (DOC > 120). సామర్థ్యం తగ్గవచ్చు - శాంపిలింగ్ పెంచండి.',
    'sampling_locked': 'పూర్తయిన చెరువులకు శాంపిలింగ్ లాక్ చేయబడింది',
    'water_test_locked': 'పూర్తయిన చెరువులకు నీటి పరీక్ష లాక్ చేయబడింది',
  };

  String t(String key) {
    final map = locale.languageCode == 'te' ? _te : _en;
    return map[key] ?? _en[key] ?? key;
  }
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'te'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}
