// Canonical event name constants — use these everywhere instead of raw strings.
// Firebase Analytics requires event names ≤ 40 chars, snake_case, no spaces.
abstract final class AnalyticsEvents {
  // ── Acquisition ────────────────────────────────────────────────────────────
  static const appOpen               = 'app_open';
  static const onboardingCompleted   = 'onboarding_completed';
  static const otpSent               = 'otp_sent';
  static const otpVerified           = 'otp_verified';
  static const accountCreated        = 'account_created';

  // ── Activation ────────────────────────────────────────────────────────────
  static const farmCreated           = 'farm_created';
  static const pondCreated           = 'pond_created';
  static const stockingAdded         = 'stocking_added';
  static const feedSetupCompleted    = 'feed_setup_completed';
  static const firstFeedLog          = 'first_feed_log';
  static const firstTrayCompleted    = 'first_tray_completed';
  static const smartFeedInitialized  = 'smart_feed_initialized';
  static const smartFeedRecViewed    = 'smart_feed_recommendation_viewed';

  // ── Daily engagement ──────────────────────────────────────────────────────
  static const feedRoundCompleted    = 'feed_round_completed';
  static const traySaveSuccess       = 'tray_save_success';
  static const recommendationViewed  = 'recommendation_viewed';
  static const samplingAdded         = 'sampling_added';
  static const waterLogAdded         = 'water_log_added';

  // ── Trust ────────────────────────────────────────────────────────────────
  static const recommendationGenerated  = 'recommendation_generated';
  static const recommendationAccepted   = 'recommendation_accepted';
  static const recommendationOverridden = 'recommendation_overridden';
  static const feedAdjustmentApplied    = 'feed_adjustment_applied';

  // ── Retention ────────────────────────────────────────────────────────────
  static const cropCycleStarted     = 'crop_cycle_started';
  static const cropCycleClosed      = 'crop_cycle_closed';
  static const harvestSaved         = 'harvest_saved';

  // ── Monetization ─────────────────────────────────────────────────────────
  static const paywallViewed            = 'paywall_viewed';
  static const subscriptionUpgradeTapped = 'subscription_upgrade_tapped';
  static const subscriptionPurchased    = 'subscription_purchased';

  // ── Auth ─────────────────────────────────────────────────────────────────
  static const authLoginSuccess      = 'auth_login_success';
  static const authLogout            = 'auth_logout';
  static const sessionRestored       = 'session_restored';

  // ── Mid-crop operational mode ─────────────────────────────────────────────
  static const midCropModeEntered        = 'mid_crop_mode_entered';
  static const manualFeedRoundConfirmed  = 'manual_feed_round_confirmed';
  static const midCropInitCompleted      = 'mid_crop_init_completed';

  // ── Operations ───────────────────────────────────────────────────────────
  static const expenseAdded          = 'expense_added';
  static const expenseDeleted        = 'expense_deleted';
  static const traySaveStarted       = 'tray_save_started';
  static const traySaveFailed        = 'tray_save_failed';
  static const trayProviderInvalidated = 'tray_provider_invalidated';
  static const feedSyncQueueDrained  = 'feed_sync_queue_drained';
  static const appErrorShown         = 'app_error_shown';

  // ── Once-per-device SharedPreferences flags ──────────────────────────────
  // These keys are stored in SharedPreferences to guard one-time events.
  static const onceFirstFeedLog      = '_ae_once_first_feed_log';
  static const onceFirstTrayCompleted = '_ae_once_first_tray_completed';
  static const onceFirstOpen         = '_ae_once_first_open';
}
