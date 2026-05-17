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

  // ── Internal ─────────────────────────────────────────────────────────────
  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) return; // keep dashboard clean during development
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (_) {}
  }
}
