import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/upgrade/subscription_provider.dart';

const _proMetrics = {
  'revenue_potential',
  'feed_cost',
  'production_cost',
  'estimated_profit',
  'profit_margin',
};

class SubscriptionAccessService {
  final bool _isPro;
  const SubscriptionAccessService(this._isPro);

  bool get isProUser => _isPro;

  bool canAccessMetric(String metricKey) {
    if (_isPro) return true;
    return !_proMetrics.contains(metricKey);
  }
}

final subscriptionAccessServiceProvider = Provider<SubscriptionAccessService>((ref) {
  final isPro = ref.watch(subscriptionProvider).isPro;
  return SubscriptionAccessService(isPro);
});
