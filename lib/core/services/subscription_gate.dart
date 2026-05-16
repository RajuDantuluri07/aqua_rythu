// Sync access gate for subscription state.
//
// Static services (MasterFeedEngine, TrayDecisionEngine, etc.) can't read
// Riverpod providers directly, so this singleton mirrors the current PRO/FREE
// state and is updated by SubscriptionNotifier whenever the plan changes.
//
// Reads are sync and cheap. Defaults to FREE on cold boot until the
// SubscriptionNotifier hydrates from the backend.
//
// Boot-race protection: await [hydrationFuture] before making PRO/FREE
// decisions in async entry points. The completer is resolved by
// SubscriptionNotifier._initializeFromBackend() after the first backend fetch.

import 'dart:async';

class SubscriptionGate {
  static bool _isPro = false;
  static bool _isHydrated = false;
  static final Completer<void> _hydrationCompleter = Completer<void>();

  /// Effective PRO state.
  static bool get isPro => _isPro;
  static bool get isFree => !isPro;

  /// True once the first backend entitlement check has completed.
  static bool get isHydrated => _isHydrated;

  /// Awaitable future that resolves when the subscription state has been
  /// fetched from the backend at least once. Use this in async engine entry
  /// points to avoid the cold-boot race where isPro defaults to false.
  static Future<void> get hydrationFuture => _hydrationCompleter.future;

  /// Real-subscription setter. Called by SubscriptionNotifier on every
  /// state change to keep the gate in sync.
  static void setPro(bool value) {
    _isPro = value;
  }

  /// Called by SubscriptionNotifier after the first backend hydration.
  /// Resolves [hydrationFuture] so waiting engines can proceed.
  static void setHydrated() {
    if (_isHydrated) return;
    _isHydrated = true;
    if (!_hydrationCompleter.isCompleted) {
      _hydrationCompleter.complete();
    }
  }
}
