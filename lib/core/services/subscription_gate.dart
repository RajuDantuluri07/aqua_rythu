// Sync access gate for subscription state.
//
// Static services (MasterFeedEngine, TrayDecisionEngine, etc.) can't read
// Riverpod providers directly, so this singleton mirrors the current PRO/FREE
// state and is updated by SubscriptionNotifier whenever the plan changes.
//
// Reads are sync and cheap. Defaults to FREE on cold boot until the
// SubscriptionNotifier hydrates from the backend.

class SubscriptionGate {
  static bool _isPro = false;

  /// Effective PRO state.
  static bool get isPro => _isPro;
  static bool get isFree => !isPro;

  /// Real-subscription setter. Called by SubscriptionNotifier on every
  /// state change to keep the gate in sync.
  static void setPro(bool value) {
    _isPro = value;
  }
}
