import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;
  AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;

  // ── Pond ─────────────────────────────────────────────────────────────────
  Future<void> logPondCreated({required String pondId}) =>
      _log('pond_created', {'pond_id': pondId});

  // ── Feed ─────────────────────────────────────────────────────────────────
  Future<void> logFeedRoundCompleted({
    required String pondId,
    required int doc,
    required int round,
    required double qty,
  }) =>
      _log('feed_round_completed', {
        'pond_id': pondId,
        'doc': doc,
        'round': round,
        'qty_kg': qty.toStringAsFixed(2),
      });

  Future<void> logFeedSyncQueueDrained({required int opCount}) =>
      _log('feed_sync_queue_drained', {'op_count': opCount});

  // ── Sampling ─────────────────────────────────────────────────────────────
  Future<void> logSamplingAdded({
    required String pondId,
    required int doc,
    required double abwG,
  }) =>
      _log('sampling_added', {
        'pond_id': pondId,
        'doc': doc,
        'abw_g': abwG.toStringAsFixed(1),
      });

  // ── Water log ────────────────────────────────────────────────────────────
  Future<void> logWaterLogAdded({
    required String pondId,
    required int doc,
  }) =>
      _log('water_log_added', {'pond_id': pondId, 'doc': doc});

  // ── Subscription ─────────────────────────────────────────────────────────
  Future<void> logSubscriptionUpgradeTapped({required String planId}) =>
      _log('subscription_upgrade_tapped', {'plan_id': planId});

  Future<void> logSubscriptionPurchased({
    required String planId,
    required double price,
  }) =>
      _log('subscription_purchased', {
        'plan_id': planId,
        'price_inr': price.toStringAsFixed(0),
      });

  // ── Crop cycle ───────────────────────────────────────────────────────────
  Future<void> logCropCycleClosed({required String pondId}) =>
      _log('crop_cycle_closed', {'pond_id': pondId});

  // ── Errors ───────────────────────────────────────────────────────────────
  Future<void> logAppErrorShown({
    required String pondId,
    required String error,
  }) =>
      _log('app_error_shown', {
        'pond_id': pondId,
        'error_summary': error.length > 100 ? error.substring(0, 100) : error,
      });

  // ── User properties ───────────────────────────────────────────────────────
  Future<void> setUserProperties({
    required String subscriptionTier,
  }) async {
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

  // ── Generic public API (ticket spec) ─────────────────────────────────────
  Future<void> track(String eventName, {Map<String, Object?>? params}) =>
      _log(eventName, params?.cast<String, Object>());

  Future<void> trackScreen(String screenName) async {
    if (kDebugMode) return;
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (_) {}
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  Future<void> logAuthLoginSuccess() => _log('auth_login_success');

  Future<void> logAuthLogout() => _log('auth_logout');

  Future<void> logSessionRestored() => _log('session_restored');

  // ── Farm ─────────────────────────────────────────────────────────────────
  Future<void> logFarmCreated({required String farmId}) =>
      _log('farm_created', {'farm_id': farmId});

  // ── Crop cycle ───────────────────────────────────────────────────────────
  Future<void> logCropCycleStarted({required String pondId}) =>
      _log('crop_cycle_started', {'pond_id': pondId});

  // ── Harvest ──────────────────────────────────────────────────────────────
  Future<void> logHarvestSaved({
    required String pondId,
    required int doc,
    required String type,
    required double quantityKg,
  }) =>
      _log('harvest_saved', {
        'pond_id': pondId,
        'doc': doc,
        'type': type,
        'quantity_kg': quantityKg.toStringAsFixed(1),
      });

  // ── Expense ──────────────────────────────────────────────────────────────
  Future<void> logExpenseAdded({
    required String farmId,
    required String category,
    required double amount,
  }) =>
      _log('expense_added', {
        'farm_id': farmId,
        'category': category,
        'amount': amount.toStringAsFixed(0),
      });

  Future<void> logExpenseDeleted() => _log('expense_deleted');

  // ── Internal ─────────────────────────────────────────────────────────────
  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) return; // keep dashboard clean during development
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}
