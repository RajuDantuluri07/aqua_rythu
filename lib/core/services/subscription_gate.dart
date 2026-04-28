// Sync access gate for subscription state.
//
// Static services (MasterFeedEngine, TrayDecisionEngine, etc.) can't read
// Riverpod providers directly, so this singleton mirrors the current PRO/FREE
// state and is updated by SubscriptionNotifier whenever the plan changes.
//
// In debug builds, a manual override (`_debugOverride`) trumps the real plan
// — useful for QA flipping FREE/PRO without hitting payment flows. The
// override is persisted via SharedPreferences so it survives hot-restart.
//
// Reads are sync and cheap. Defaults to FREE on cold boot until the
// SubscriptionNotifier hydrates from the backend.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionGate {
  static const String _prefsKey = 'debug_subscription_override';

  static bool _isPro = false;
  static bool? _debugOverride;

  /// Effective PRO state — debug override wins when set.
  static bool get isPro => _debugOverride ?? _isPro;
  static bool get isFree => !isPro;

  /// Whether a debug override is currently active.
  static bool get hasDebugOverride => _debugOverride != null;
  static bool? get debugOverride => _debugOverride;

  /// Real-subscription setter. Called by SubscriptionNotifier on every
  /// state change to keep the gate in sync.
  static void setPro(bool value) {
    _isPro = value;
  }

  /// Set a debug override. `null` clears the override.
  /// In release builds this is a no-op so debug toggles can never leak.
  static void setDebugOverride(bool? value) {
    if (kReleaseMode) return;
    _debugOverride = value;
  }

  /// Clear any active debug override (return to real subscription).
  static void resetDebug() {
    if (kReleaseMode) return;
    _debugOverride = null;
  }

  /// Read the persisted debug override from SharedPreferences and apply it.
  /// Call once during app startup before runApp().
  /// In release builds this clears any stale persisted value to be safe.
  static Future<void> hydrateDebugOverride() async {
    if (kReleaseMode) {
      _debugOverride = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey);
      } catch (_) {
        // Swallow — release builds must never crash on a debug-only path.
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_prefsKey);
      switch (value) {
        case 'pro':
          _debugOverride = true;
          break;
        case 'free':
          _debugOverride = false;
          break;
        default:
          _debugOverride = null;
      }
    } catch (_) {
      _debugOverride = null;
    }
  }

  /// Persist the debug override choice. Use 'pro' / 'free' / 'none'.
  /// No-op in release builds.
  static Future<void> persistDebugChoice(String choice) async {
    if (kReleaseMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (choice == 'none') {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, choice);
      }
    } catch (_) {
      // Best-effort persistence; debug-only path.
    }
  }
}
