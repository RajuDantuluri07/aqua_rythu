// Shared app-wide constants.
// Single source of truth — import this wherever these values are needed.

/// Feed cost per kg in ₹. Used for feed cost, profit, and engine ₹-warnings.
/// Must match FeedEngineConstants.feedCostPerKg — only change here.
const double kFeedCostPerKg = 70.0;

/// Shrimp market price per kg in ₹. Used for crop value and profit estimates.
const double kShrimpMarketPricePerKg = 220.0;
