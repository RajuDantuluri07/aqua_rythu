import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subscription_provider.dart';

/// Single source of truth for all feature access decisions.
///
/// All UI checks must go through [featureGateProvider].
/// Static engines (MasterFeedEngine, TrayDecisionEngine) keep using
/// [SubscriptionGate] directly — that sync singleton is correct for them.
class FeatureGate {
  final bool isPro;
  const FeatureGate({required this.isPro});

  bool get canUseSmartFeed       => isPro;
  bool get canViewProfit         => isPro;
  bool get canViewFcr            => isPro;
  bool get canViewGrowthInsights => isPro;
  bool get canComparePonds       => isPro;
  bool get canExportReports      => isPro;
}

final featureGateProvider = Provider<FeatureGate>((ref) {
  final sub = ref.watch(subscriptionProvider);
  // Block all gated features until the subscription state has been confirmed
  // by the backend — avoids showing Pro features on a stale free-default.
  return FeatureGate(isPro: sub.isHydrated && sub.isPro);
});
