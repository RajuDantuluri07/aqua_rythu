class FeedEngineConstants {
  /// Survival rate estimation (PRD 13.2)
  static const Map<int, double> survivalRates = {
    1: 0.98,
    15: 0.96,
    30: 0.93,
    60: 0.88,
    90: 0.83,
    120: 0.80,
  };

  /// Average Body Weight (ABW) targets in grams
  static const Map<int, double> abwTargets = {
    1: 0.01,
    15: 0.08,
    30: 0.5,
    45: 2.0,
    60: 5.0,
    75: 10.0,
    90: 18.0,
    105: 25.0,
    120: 32.0,
  };

  /// Feeding Rate (% body weight)
  static const Map<int, double> feedingRates = {
    1: 0.15,
    15: 0.12,
    30: 0.08,
    60: 0.05,
    90: 0.035,
    120: 0.025,
  };

  /// Meal distribution factors
  static const double firstMealFactor = 0.8;
  static const double lastMealFactor = 1.2;

  // Tray multipliers REMOVED — use FeedingEngineV1.trayFactor() instead.

  // ── Feed cost constants ───────────────────────────────────────────────────

  /// Approximate cost of shrimp feed per kg (₹).
  /// Used for ₹-framed warnings (e.g. "Feeding early wastes ₹X").
  /// Typical commercial pellet range: ₹60–90/kg. Conservative midpoint used.
  /// BUG-13 fix: was hardcoded as ₹20/kg in FeedStatusEngine.estimateFeedLoss,
  /// which under-stated the loss 3–4x. Centralised here for easy tuning.
  /// TODO V2: make this configurable per-farm (user-entered purchase price).
  static const double feedCostPerKg = 70.0;

  /// Default market price per kg of harvested L. vannamei (₹).
  /// Shared across PondValueEngine and insight calculations.
  static const double harvestPricePerKg = 150.0;
}
