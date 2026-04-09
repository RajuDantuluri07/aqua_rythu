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
    // Pond & Farm
    'pond': 'Pond',
    'ponds': 'Ponds',
    'add_pond': 'Add Pond',
    'add_pond_btn': '+ ADD POND',
    'add_first_pond': 'Add First Pond',
    'no_ponds': 'No ponds found',
    'create_pond_to_start': 'Create a new pond to get started',
    'delete_pond': 'Delete Pond?',
    'delete_pond_confirm': 'Are you sure you want to delete',
    'delete_pond_warning': 'This action cannot be undone.',
    'select_farm': 'Select Farm',
    'add_new_farm': 'Add New Farm',
    'create_farm': 'Create Farm',
    'farm_name': 'Farm Name',
    'farm_created': 'Farm created successfully',
    'no_farms': 'No farms created',
    'create_farm_first': 'Create a farm first to add ponds',
    // Feed
    'feed': 'Feed',
    'mark_as_fed': 'Mark as Fed',
    'today_feed': "Today's Feed",
    'on_track': 'On Track',
    'next_round': 'Next Round',
    'feed_schedule': 'Feed Schedule',
    'no_feed_plan': 'No feed plan for today',
    'feed_given': 'Feed Given',
    'total_feed': 'Total Feed',
    'fcr': 'FCR',
    'feed_rounds': 'Feed Rounds',
    // Operations
    'sampling': 'Sampling',
    'water_test': 'Water Test',
    'harvest': 'Harvest',
    'history': 'History',
    'supplement_mix': 'Supplement Mix',
    'tank_operations': 'TANK OPERATIONS',
    // Pond stats
    'species': 'SPECIES',
    'doc': 'DOC',
    'survival': 'SURVIVAL',
    'days': 'Days',
    'abw': 'ABW (g)',
    'biomass': 'Biomass',
    'stocking': 'Stocking',
    'area': 'Area (Acres)',
    'seed_count': 'Seed Count',
    // Status & messages
    'extended_culture': 'Extended Culture Mode (DOC > 120). Efficiency may reduce - increase sampling frequency.',
    'sampling_locked': 'Sampling is locked for completed ponds',
    'water_test_locked': 'Water test is locked for completed ponds',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'save': 'Save',
    'confirm': 'Confirm',
    'loading': 'Loading...',
    'error_try_again': 'Something went wrong. Please try again.',
    'no_internet': 'No internet connection',
    // Auth
    'login': 'Login',
    'logout': 'Logout',
    'phone_number': 'Phone Number',
    'enter_otp': 'Enter OTP',
    'send_otp': 'Send OTP',
    'verify': 'Verify',
    'resend_otp': 'Resend OTP',
    'otp_sent': 'OTP sent to your phone',
    // Profile
    'profile': 'Profile',
    'my_farms': 'MY FARMS',
    'change_language': 'Change Language',
    'privacy_policy': 'Privacy Policy',
    'terms': 'Terms & Conditions',
    'about': 'About AquaRythu',
    // Harvest
    'harvest_complete': 'Harvest Complete',
    'total_harvest': 'Total Harvest (kg)',
    'selling_price': 'Selling Price (₹/kg)',
    'net_profit': 'Net Profit',
    // Water test
    'ph': 'pH',
    'do_level': 'DO (mg/L)',
    'ammonia': 'Ammonia',
    'salinity': 'Salinity',
    'temperature': 'Temperature',
  };

  static const _te = <String, String>{
    // Pond & Farm
    'pond': 'చెరువు',
    'ponds': 'చెరువులు',
    'add_pond': 'చెరువు జోడించండి',
    'add_pond_btn': '+ చెరువు జోడించు',
    'add_first_pond': 'మొదటి చెరువు జోడించండి',
    'no_ponds': 'చెరువులు కనుగొనబడలేదు',
    'create_pond_to_start': 'ప్రారంభించడానికి కొత్త చెరువు సృష్టించండి',
    'delete_pond': 'చెరువు తొలగించాలా?',
    'delete_pond_confirm': 'మీరు ఖచ్చితంగా తొలగించాలనుకుంటున్నారా',
    'delete_pond_warning': 'ఈ చర్యను రద్దు చేయడం సాధ్యం కాదు.',
    'select_farm': 'ఫార్మ్ ఎంచుకోండి',
    'add_new_farm': 'కొత్త ఫార్మ్ జోడించండి',
    'create_farm': 'ఫార్మ్ సృష్టించు',
    'farm_name': 'ఫార్మ్ పేరు',
    'farm_created': 'ఫార్మ్ విజయవంతంగా సృష్టించబడింది',
    'no_farms': 'ఫార్మ్‌లు లేవు',
    'create_farm_first': 'చెరువులు జోడించడానికి ముందు ఫార్మ్ సృష్టించండి',
    // Feed
    'feed': 'ఆహారం',
    'mark_as_fed': 'ఆహారం వేసాను',
    'today_feed': 'ఈరోజు ఆహారం',
    'on_track': 'సరిగ్గా జరుగుతోంది',
    'next_round': 'తర్వాతి రౌండ్',
    'feed_schedule': 'ఫీడ్ షెడ్యూల్',
    'no_feed_plan': 'ఈరోజు ఆహార ప్రణాళిక లేదు',
    'feed_given': 'వేసిన ఆహారం',
    'total_feed': 'మొత్తం ఆహారం',
    'fcr': 'FCR',
    'feed_rounds': 'ఫీడ్ రౌండ్లు',
    // Operations
    'sampling': 'గ్రోత్ చెక్',
    'water_test': 'నీటి పరీక్ష',
    'harvest': 'పట్టుబడి',
    'history': 'చరిత్ర',
    'supplement_mix': 'సప్లిమెంట్ మిక్స్',
    'tank_operations': 'టాంక్ కార్యకలాపాలు',
    // Pond stats
    'species': 'జాతి',
    'doc': 'డాక్',
    'survival': 'మనుగడ',
    'days': 'రోజులు',
    'abw': 'ABW (గ్రా)',
    'biomass': 'బయోమాస్',
    'stocking': 'స్టాకింగ్',
    'area': 'విస్తీర్ణం (ఎకరాలు)',
    'seed_count': 'సీడ్ కౌంట్',
    // Status & messages
    'extended_culture': 'పొడిగించిన సాగు మోడ్ (DOC > 120). సామర్థ్యం తగ్గవచ్చు - శాంపిలింగ్ పెంచండి.',
    'sampling_locked': 'పూర్తయిన చెరువులకు శాంపిలింగ్ లాక్ చేయబడింది',
    'water_test_locked': 'పూర్తయిన చెరువులకు నీటి పరీక్ష లాక్ చేయబడింది',
    'cancel': 'రద్దు',
    'delete': 'తొలగించు',
    'save': 'సేవ్ చేయి',
    'confirm': 'నిర్ధారించు',
    'loading': 'లోడ్ అవుతోంది...',
    'error_try_again': 'ఏదో తప్పు జరిగింది. మళ్ళీ ప్రయత్నించండి.',
    'no_internet': 'ఇంటర్నెట్ కనెక్షన్ లేదు',
    // Auth
    'login': 'లాగిన్',
    'logout': 'లాగ్ అవుట్',
    'phone_number': 'ఫోన్ నంబర్',
    'enter_otp': 'OTP నమోదు చేయండి',
    'send_otp': 'OTP పంపండి',
    'verify': 'నిర్ధారించు',
    'resend_otp': 'OTP మళ్ళీ పంపండి',
    'otp_sent': 'మీ ఫోన్‌కు OTP పంపబడింది',
    // Profile
    'profile': 'ప్రొఫైల్',
    'my_farms': 'నా ఫార్మ్‌లు',
    'change_language': 'భాష మార్చండి',
    'privacy_policy': 'గోప్యతా విధానం',
    'terms': 'నిబంధనలు & షరతులు',
    'about': 'AquaRythu గురించి',
    // Harvest
    'harvest_complete': 'పట్టుబడి పూర్తయింది',
    'total_harvest': 'మొత్తం పట్టుబడి (కేజీ)',
    'selling_price': 'విక్రయ ధర (₹/కేజీ)',
    'net_profit': 'నికర లాభం',
    // Water test
    'ph': 'pH',
    'do_level': 'DO (mg/L)',
    'ammonia': 'అమ్మోనియా',
    'salinity': 'లవణీయత',
    'temperature': 'ఉష్ణోగ్రత',
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
