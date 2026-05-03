import 'package:flutter/foundation.dart';

/// Controls which screens are LAUNCHED (visible to users at all).
///
/// These are LAUNCH flags — they answer "is this screen ready to ship?"
/// They are NOT subscription gates. A screen can be launched (flag = true)
/// and still require PRO via [FeatureGate] / [isProProvider].
///
/// PRO enforcement lives in:
///   - lib/features/upgrade/feature_gate.dart  (UI checks)
///   - lib/core/services/subscription_gate.dart (engine checks)
///
/// Turning [enableAllFeaturesForDev] on in debug lets engineers test
/// screens that haven't shipped yet — subscription gating still applies.
class FeatureFlags {
  // ─── NOT YET LAUNCHED ────────────────────────────────────────────────────
  // Flip to true when the screen is production-ready and QA-signed-off.
  // Subscription gating on these screens is enforced independently.

  static const bool inventoryEnabled   = false;
  static const bool expenseEnabled     = false;
  static const bool profitEnabled      = false;
  static const bool waterEnabled       = false;
  static const bool supplementsEnabled = false;
  static const bool harvestEnabled     = false;

  // ─── ALWAYS LAUNCHED ─────────────────────────────────────────────────────

  static const bool upgradeEnabled       = true;
  static const bool pondDashboardEnabled = true;
  static const bool feedScheduleEnabled  = true;
  static const bool feedHistoryEnabled   = true;
  static const bool trayLogEnabled       = true;
  static const bool samplingEnabled      = true;
  static const bool farmSetupEnabled     = true;
  static const bool homeDashboardEnabled = true;
  static const bool profileEnabled       = true;

  // ─── DEV OVERRIDE ────────────────────────────────────────────────────────
  // Lets engineers reach unlaunched screens in debug builds.
  // Subscription gating (FeatureGate / SubscriptionGate) is NOT bypassed.

  static const bool enableAllFeaturesForDev = true;

  // ─── ACCESSORS ───────────────────────────────────────────────────────────

  static bool get isInventoryVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return inventoryEnabled;
  }

  static bool get isExpenseVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return expenseEnabled;
  }

  static bool get isProfitVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return profitEnabled;
  }

  static bool get isWaterVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return waterEnabled;
  }

  static bool get isSupplementsVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return supplementsEnabled;
  }

  static bool get isHarvestVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return harvestEnabled;
  }

  static bool get isUpgradeVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return upgradeEnabled;
  }
}
