import 'package:flutter/foundation.dart';

/// Feature flags for launch mode gating.
///
/// Set to false to hide secondary features for a simplified launch experience.
/// Set enableAllFeaturesForDev to true in debug mode to test all features.
class FeatureFlags {
  // ─── SECONDARY FEATURES (GATED FOR LAUNCH) ────────────────────────────────
  
  /// Inventory management (stock tracking, purchase history)
  static const bool inventoryEnabled = false;
  
  /// Expense tracking (daily expenses, summaries)
  static const bool expenseEnabled = false;
  
  /// Profit calculation and analytics
  static const bool profitEnabled = false;
  
  /// Water quality testing
  static const bool waterEnabled = false;
  
  /// Supplement mixing and management
  static const bool supplementsEnabled = false;
  
  /// Harvest management (logging, records, summaries)
  static const bool harvestEnabled = false;
  
  /// Upgrade/Subscription screen (keep visible for monetization)
  static const bool upgradeEnabled = true;

  // ─── CORE FEATURES (ALWAYS ENABLED) ────────────────────────────────────────
  
  /// Pond dashboard (main daily operations hub)
  static const bool pondDashboardEnabled = true;
  
  /// Feed schedule and feed done functionality
  static const bool feedScheduleEnabled = true;
  
  /// Feed history tracking
  static const bool feedHistoryEnabled = true;
  
  /// Tray logging (critical for feed adjustments)
  static const bool trayLogEnabled = true;
  
  /// Sampling/growth tracking
  static const bool samplingEnabled = true;
  
  /// Farm and pond setup
  static const bool farmSetupEnabled = true;
  
  /// Home dashboard
  static const bool homeDashboardEnabled = true;
  
  /// Profile and settings
  static const bool profileEnabled = true;

  // ─── DEVELOPMENT OVERRIDES ─────────────────────────────────────────────────
  
  /// Set to true to enable all features in debug mode for testing.
  /// In production, this should always be false.
  static const bool enableAllFeaturesForDev = true;

  // ─── HELPER METHODS ───────────────────────────────────────────────────────
  
  /// Returns true if inventory feature should be visible.
  static bool get isInventoryVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return inventoryEnabled;
  }
  
  /// Returns true if expense feature should be visible.
  static bool get isExpenseVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return expenseEnabled;
  }
  
  /// Returns true if profit feature should be visible.
  static bool get isProfitVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return profitEnabled;
  }
  
  /// Returns true if water testing feature should be visible.
  static bool get isWaterVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return waterEnabled;
  }
  
  /// Returns true if supplements feature should be visible.
  static bool get isSupplementsVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return supplementsEnabled;
  }
  
  /// Returns true if harvest feature should be visible.
  static bool get isHarvestVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return harvestEnabled;
  }
  
  /// Returns true if upgrade screen should be visible.
  static bool get isUpgradeVisible {
    if (kDebugMode && enableAllFeaturesForDev) return true;
    return upgradeEnabled;
  }
}
