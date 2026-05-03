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
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final sub = Subscription.fromJson(response);
      // T23: Client-side expiry guard — treats end_date < now as expired
      // even if the DB row hasn't been swept yet by expire_subscriptions().
      if (!sub.isActive) return null;
      return sub;
    } catch (e) {
      throw Exception('Failed to get subscription: $e');
    }
  }

  // Create new subscription
  Future<Subscription> createSubscription({
    required String farmId,
    required PlanType planType,
    required double price,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final now = DateTime.now();
      final subscriptionData = {
        'user_id': user.id,
        'farm_id': farmId,
        'plan_type': planType.name,
        'start_date': now.toIso8601String(),
        'status': 'active',
        'price': price,
        'currency': 'INR',
        'created_at': now.toIso8601String(),
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

  // Check if user has active PRO subscription for specific farm
  Future<bool> hasActiveProSubscription(String farmId) async {
    try {
      final subscription = await getCurrentSubscription();
      return subscription?.isPro == true && subscription?.farmId == farmId;
    } catch (e) {
      return false;
    }
  }

  // Validate subscription access for feature
  Future<bool> canAccessFeature(String featureId, {String? farmId}) async {
    try {
      final subscription = await getCurrentSubscription();
      if (subscription == null || !subscription.isActive) {
        return false;
      }

      final feature = PlanFeatures.getFeatureById(featureId);
      if (feature == null) return true; // Unknown features allowed

      if (!feature.isProFeature) return true; // Free features always allowed

      // PRO features require active PRO subscription
      return subscription.isPro && (farmId == null || subscription.farmId == farmId);
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
          .select('plan_type, status, price, created_at')
          .eq('user_id', user.id);

      final subscriptions = (response as List)
          .map((data) => Subscription.fromJson(data as Map<String, dynamic>))
          .toList();

      final activeSubscriptions = subscriptions.where((s) => s.isActive).toList();
      final totalSpent = subscriptions.fold<double>(0.0, (sum, s) => sum + s.price);

      return {
        'total_subscriptions': subscriptions.length,
        'active_subscriptions': activeSubscriptions.length,
        'total_spent': totalSpent,
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
