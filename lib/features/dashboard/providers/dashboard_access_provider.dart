import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/subscription/subscription_access_service.dart';

/// Exposes subscription access checks scoped to the dashboard.
/// All metric visibility decisions go through this provider so the
/// dashboard never duplicates isPro reads from unrelated providers.
final dashboardAccessProvider = Provider<SubscriptionAccessService>((ref) {
  return ref.watch(subscriptionAccessServiceProvider);
});
