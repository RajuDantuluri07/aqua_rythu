import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _client;
  static const String _table = 'subscriptions';

  SubscriptionService() : _client = Supabase.instance.client;

  // Get current user's subscription
  Future<Subscription?> getCurrentSubscription() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final sub = Subscription.fromJson(response);
      // T23: Client-side expiry guard — treats expires_at < now as expired
      // even if the DB row hasn't been swept yet.
      if (!sub.isActive) return null;
      return sub;
    } catch (e) {
      throw Exception('Failed to get subscription: $e');
    }
  }

  // Create new subscription
  Future<Subscription> createSubscription({
    required PlanType planType,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final subscriptionData = {
        'user_id': user.id,
        'plan': planType.name.toLowerCase(),
        'status': 'active',
        'activated_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
        'payment_status': 'verified',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _client.from(_table).insert(subscriptionData).select().single();

      return Subscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  // Update subscription status
  Future<Subscription> updateSubscriptionStatus(
    String subscriptionId,
    SubscriptionStatus newStatus,
  ) async {
    try {
      final response = await _client
          .from(_table)
          .update({
            'status': newStatus.name.toLowerCase(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .select()
          .single();

      return Subscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update subscription: $e');
    }
  }

  // Cancel subscription
  Future<Subscription> cancelSubscription(String subscriptionId) async {
    return updateSubscriptionStatus(subscriptionId, SubscriptionStatus.CANCELLED);
  }

  // Get subscription history for user
  Future<List<Subscription>> getSubscriptionHistory() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => Subscription.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get subscription history: $e');
    }
  }

  // Check if user has active PRO subscription
  Future<bool> hasActiveProSubscription() async {
    try {
      final subscription = await getCurrentSubscription();
      return subscription?.isPro == true;
    } catch (e) {
      return false;
    }
  }

  // Validate subscription access for feature
  Future<bool> canAccessFeature(String featureId) async {
    try {
      final subscription = await getCurrentSubscription();
      if (subscription == null || !subscription.isActive) {
        return false;
      }

      final feature = PlanFeatures.getFeatureById(featureId);
      if (feature == null) return true; // Unknown features allowed

      if (!feature.isProFeature) return true; // Free features always allowed

      // PRO features require active PRO subscription
      return subscription.isPro;
    } catch (e) {
      return false;
    }
  }

  // Get subscription statistics
  Future<Map<String, dynamic>> getSubscriptionStats() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _client
          .from(_table)
          .select('plan, status, expires_at, created_at')
          .eq('user_id', user.id);

      final subscriptions = (response as List)
          .map((data) => Subscription.fromJson(data as Map<String, dynamic>))
          .toList();

      final activeSubscriptions = subscriptions.where((s) => s.isActive).toList();

      return {
        'total_subscriptions': subscriptions.length,
        'active_subscriptions': activeSubscriptions.length,
        'current_plan': activeSubscriptions.isNotEmpty
            ? activeSubscriptions.first.planType.name
            : 'FREE',
        'has_pro': activeSubscriptions.any((s) => s.isPro),
      };
    } catch (e) {
      throw Exception('Failed to get subscription stats: $e');
    }
  }
}
