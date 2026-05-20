import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../analytics/analytics_buffer.dart';
import '../analytics/analytics_events.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;
  final String _sessionId = _makeSessionId();
  SharedPreferences? _prefs;

  static String _makeSessionId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  // Call once from main.dart after SharedPreferences is ready.
  void init(SharedPreferences prefs) => _prefs = prefs;

  String get sessionId => _sessionId;

  // ── Once-per-device guard ─────────────────────────────────────────────────
  // Returns true the first time the key is encountered, then false forever.
  Future<bool> _once(String key) async {
    final p = _prefs;
    if (p == null) return false;
    if (p.getBool(key) == true) return false;
    await p.setBool(key, true);
    return true;
  }

  // ── Acquisition ───────────────────────────────────────────────────────────
  Future<void> logAppOpen({required bool isFirstOpen}) =>
      _log(AnalyticsEvents.appOpen, {'is_first_open': isFirstOpen ? 1 : 0});

  Future<void> logOnboardingCompleted({required int slidesSeen}) =>
      _log(AnalyticsEvents.onboardingCompleted, {'slides_seen': slidesSeen});

  Future<void> logOtpSent() =>
      _log(AnalyticsEvents.otpSent);

  Future<void> logOtpVerified() =>
      _log(AnalyticsEvents.otpVerified);

  Future<void> logAccountCreated({required String signUpMethod}) =>
      _log(AnalyticsEvents.accountCreated, {'sign_up_method': signUpMethod});

  // ── Activation ────────────────────────────────────────────────────────────
  Future<void> logStockingAdded({
    required String pondId,
    required String seedType,
    int? seedCount,
    double? plSizeMm,
    required int doc,
  }) =>
      _log(AnalyticsEvents.stockingAdded, {
        'pond_id': pondId,
        'seed_type': seedType,
        if (seedCount != null) 'seed_count': seedCount,
        if (plSizeMm != null) 'pl_size_mm': plSizeMm.toStringAsFixed(1),
        'doc': doc,
      });

  Future<void> logFeedSetupCompleted({
    required String pondId,
    required String seedType,
  }) =>
      _log(AnalyticsEvents.feedSetupCompleted, {
        'pond_id': pondId,
        'seed_type': seedType,
      });

  // Fires only once per device (guards repeated calls after reinstall won't double-fire).
  Future<void> logFirstFeedLog({
    required String pondId,
    required int doc,
    required double qty,
  }) async {
    if (!await _once(AnalyticsEvents.onceFirstFeedLog)) return;
    await _log(AnalyticsEvents.firstFeedLog, {
      'pond_id': pondId,
      'doc': doc,
      'qty_kg': qty.toStringAsFixed(2),
    });
  }

  Future<void> logFirstTrayCompleted({
    required String pondId,
    required int doc,
  }) async {
    if (!await _once(AnalyticsEvents.onceFirstTrayCompleted)) return;
    await _log(AnalyticsEvents.firstTrayCompleted, {
      'pond_id': pondId,
      'doc': doc,
    });
  }

  Future<void> logSmartFeedInitialized({
    required String pondId,
    required int doc,
  }) =>
      _log(AnalyticsEvents.smartFeedInitialized, {
        'pond_id': pondId,
        'doc': doc,
      });

  Future<void> logSmartFeedRecommendationViewed({
    required String pondId,
    required int doc,
    required double recommendedKg,
    required String confidence,
  }) =>
      _log(AnalyticsEvents.smartFeedRecViewed, {
        'pond_id': pondId,
        'doc': doc,
        'recommended_kg': recommendedKg.toStringAsFixed(2),
        'confidence': confidence,
      });

  // ── Trust ─────────────────────────────────────────────────────────────────
  Future<void> logRecommendationGenerated({
    required String pondId,
    required int doc,
    required double recommendedKg,
    required String confidence,
    required String stage,
  }) =>
      _log(AnalyticsEvents.recommendationGenerated, {
        'pond_id': pondId,
        'doc': doc,
        'recommended_kg': recommendedKg.toStringAsFixed(2),
        'confidence': confidence,
        'stage': stage,
      });

  Future<void> logRecommendationViewed({
    required String pondId,
    required int doc,
    required double recommendedKg,
  }) =>
      _log(AnalyticsEvents.recommendationViewed, {
        'pond_id': pondId,
        'doc': doc,
        'recommended_kg': recommendedKg.toStringAsFixed(2),
      });

  // delta_pct = (logged - recommended) / recommended * 100
  Future<void> logRecommendationAccepted({
    required String pondId,
    required int doc,
    required double recommendedKg,
    required double loggedKg,
  }) {
    final pct = recommendedKg > 0
        ? ((loggedKg - recommendedKg) / recommendedKg * 100)
        : 0.0;
    return _log(AnalyticsEvents.recommendationAccepted, {
      'pond_id': pondId,
      'doc': doc,
      'recommended_kg': recommendedKg.toStringAsFixed(2),
      'logged_kg': loggedKg.toStringAsFixed(2),
      'delta_pct': pct.toStringAsFixed(1),
    });
  }

  Future<void> logRecommendationOverridden({
    required String pondId,
    required int doc,
    required double recommendedKg,
    required double loggedKg,
  }) {
    final pct = recommendedKg > 0
        ? ((loggedKg - recommendedKg) / recommendedKg * 100)
        : 0.0;
    return _log(AnalyticsEvents.recommendationOverridden, {
      'pond_id': pondId,
      'doc': doc,
      'recommended_kg': recommendedKg.toStringAsFixed(2),
      'logged_kg': loggedKg.toStringAsFixed(2),
      'delta_pct': pct.toStringAsFixed(1),
    });
  }

  Future<void> logFeedAdjustmentApplied({
    required String pondId,
    required int doc,
    required double trayFactor,
    required String action,
  }) =>
      _log(AnalyticsEvents.feedAdjustmentApplied, {
        'pond_id': pondId,
        'doc': doc,
        'tray_factor': trayFactor.toStringAsFixed(2),
        'action': action,
      });

  // ── Monetization ─────────────────────────────────────────────────────────
  Future<void> logPaywallViewed({required String triggerSource}) =>
      _log(AnalyticsEvents.paywallViewed, {'trigger_source': triggerSource});

  // ── Existing events (unchanged signatures) ────────────────────────────────
  Future<void> logPondCreated({required String pondId}) =>
      _log(AnalyticsEvents.pondCreated, {'pond_id': pondId});

  Future<void> logFeedRoundCompleted({
    required String pondId,
    required int doc,
    required int round,
    required double qty,
  }) =>
      _log(AnalyticsEvents.feedRoundCompleted, {
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'qty_kg': qty.toStringAsFixed(2),
      });

  Future<void> logFeedSyncQueueDrained({required int opCount}) =>
      _log(AnalyticsEvents.feedSyncQueueDrained, {'op_count': opCount});

  Future<void> logMidCropModeEntered({
    required String pondId,
    required int doc,
    required String seedType,
  }) =>
      _log(AnalyticsEvents.midCropModeEntered, {
        'pond_id': pondId,
        'doc': doc,
        'seed_type': seedType,
      });

  Future<void> logManualFeedRoundConfirmed({
    required String pondId,
    required int doc,
    required int round,
    required double qty,
  }) =>
      _log(AnalyticsEvents.manualFeedRoundConfirmed, {
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'qty_kg': qty.toStringAsFixed(2),
      });

  Future<void> logMidCropInitCompleted({
    required String pondId,
    required int doc,
    required int totalRounds,
  }) =>
      _log(AnalyticsEvents.midCropInitCompleted, {
        'pond_id': pondId,
        'doc': doc,
        'total_rounds': totalRounds,
      });

  Future<void> logSamplingAdded({
    required String pondId,
    required int doc,
    required double abwG,
  }) =>
      _log(AnalyticsEvents.samplingAdded, {
        'pond_id': pondId,
        'doc': doc,
        'abw_g': abwG.toStringAsFixed(1),
      });

  Future<void> logWaterLogAdded({
    required String pondId,
    required int doc,
  }) =>
      _log(AnalyticsEvents.waterLogAdded, {'pond_id': pondId, 'doc': doc});

  Future<void> logSubscriptionUpgradeTapped({required String planId}) =>
      _log(AnalyticsEvents.subscriptionUpgradeTapped, {'plan_id': planId});

  Future<void> logSubscriptionPurchased({
    required String planId,
    required double price,
  }) =>
      _log(AnalyticsEvents.subscriptionPurchased, {
        'plan_id': planId,
        'price_inr': price.toStringAsFixed(0),
      });

  Future<void> logCropCycleClosed({required String pondId}) =>
      _log(AnalyticsEvents.cropCycleClosed, {'pond_id': pondId});

  Future<void> logAppErrorShown({
    required String pondId,
    required String error,
  }) =>
      _log(AnalyticsEvents.appErrorShown, {
        'pond_id': pondId,
        'error_summary': error.length > 100 ? error.substring(0, 100) : error,
      });

  Future<void> logAuthLoginSuccess() => _log(AnalyticsEvents.authLoginSuccess);
  Future<void> logAuthLogout() => _log(AnalyticsEvents.authLogout);
  Future<void> logSessionRestored() => _log(AnalyticsEvents.sessionRestored);

  Future<void> logFarmCreated({required String farmId}) =>
      _log(AnalyticsEvents.farmCreated, {'farm_id': farmId});

  Future<void> logCropCycleStarted({required String pondId}) =>
      _log(AnalyticsEvents.cropCycleStarted, {'pond_id': pondId});

  Future<void> logHarvestSaved({
    required String pondId,
    required int doc,
    required String type,
    required double quantityKg,
  }) =>
      _log(AnalyticsEvents.harvestSaved, {
        'pond_id': pondId,
        'doc': doc,
        'type': type,
        'quantity_kg': quantityKg.toStringAsFixed(1),
      });

  Future<void> logExpenseAdded({
    required String farmId,
    required String category,
    required double amount,
  }) =>
      _log(AnalyticsEvents.expenseAdded, {
        'farm_id': farmId,
        'category': category,
        'amount': amount.toStringAsFixed(0),
      });

  Future<void> logExpenseDeleted() => _log(AnalyticsEvents.expenseDeleted);

  Future<void> logTraySaveStarted({
    required String pondId,
    required int doc,
    required int round,
    required bool hasObservations,
  }) =>
      _log(AnalyticsEvents.traySaveStarted, {
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'has_observations': hasObservations ? 1 : 0,
      });

  Future<void> logTraySaveSuccess({
    required String pondId,
    required int doc,
    required int round,
  }) =>
      _log(AnalyticsEvents.traySaveSuccess, {
        'pond_id': pondId,
        'doc': doc,
        'round': round,
      });

  Future<void> logTraySaveFailed({
    required String pondId,
    required int doc,
    required int round,
    required String reason,
  }) =>
      _log(AnalyticsEvents.traySaveFailed, {
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'reason': reason.length > 100 ? reason.substring(0, 100) : reason,
      });

  Future<void> logTrayProviderInvalidated({
    required String pondId,
    required String trigger,
  }) =>
      _log(AnalyticsEvents.trayProviderInvalidated, {
        'pond_id': pondId,
        'trigger': trigger,
      });

  // ── User properties ───────────────────────────────────────────────────────
  Future<void> setUserProperties({required String subscriptionTier}) async {
    if (kDebugMode) return;
    await _analytics.setUserProperty(
        name: 'subscription_tier', value: subscriptionTier);
  }

  Future<void> setUserProperty(String name, String value) async {
    if (kDebugMode) return;
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (_) {}
  }

  Future<void> setUserId(String? userId) async {
    if (kDebugMode) return;
    try {
      await _analytics.setUserId(id: userId);
    } catch (_) {}
  }

  // ── Generic public API ────────────────────────────────────────────────────
  Future<void> track(String eventName, {Map<String, Object?>? params}) =>
      _log(eventName, params?.cast<String, Object>());

  Future<void> trackScreen(String screenName) async {
    if (kDebugMode) return;
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  // ── Internal ─────────────────────────────────────────────────────────────
  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) return;
    unawaited(_firebaseLog(name, params));
    unawaited(_supabaseLog(name, params));
  }

  Future<void> _firebaseLog(String name, Map<String, Object>? params) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> _supabaseLog(String name, Map<String, Object>? params) async {
    final p = _prefs;
    if (p == null) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final row = <String, dynamic>{
        'user_id': userId,
        'session_id': _sessionId,
        'event_name': name,
        'properties': params ?? {},
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Extract relational IDs for indexed columns
      final pond = params?['pond_id'];
      final farm = params?['farm_id'];
      if (pond is String) row['pond_id'] = pond;
      if (farm is String) row['farm_id'] = farm;

      try {
        await Supabase.instance.client.from('analytics_events').insert(row);
      } catch (_) {
        // Offline or auth error — queue for later drain
        await AnalyticsBuffer.enqueue(p, row);
      }
    } catch (_) {}
  }
}
