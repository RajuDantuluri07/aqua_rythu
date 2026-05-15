import 'package:aqua_rythu/core/models/subscription_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  final SupabaseClient _client;
  static const String _table = 'subscriptions';

  SubscriptionService() : _client = Supabase.instance.client;

  // Get current user's subscription.
  // Client SELECT is allowed by RLS; writes are blocked — only edge functions
  // using service_role can create or update subscriptions.
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
      // Client-side expiry guard — treats expires_at < now as expired even if
      // the DB row hasn't been swept by expire_subscriptions() yet.
      if (!sub.isActive) return null;
      return sub;
    } catch (e) {
      throw Exception('Failed to get subscription: $e');
    }
  }

  // Server-authoritative entitlement via SECURITY DEFINER RPC.
  //
  // Unlike getCurrentSubscription(), this bypasses client-side RLS and
  // evaluates expiry on the Postgres server — the result is the canonical
  // truth used for feature-gate decisions. Returns null when FREE or expired.
  Future<Map<String, dynamic>?> getActiveEntitlement() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client.rpc('get_active_entitlement');
      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;
      return rows.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // Check if user has active PRO subscription (client-side fast path).
  Future<bool> hasActiveProSubscription() async {
    try {
      final subscription = await getCurrentSubscription();
      return subscription?.isPro == true;
    } catch (e) {
      return false;
    }
  }

  // Validate subscription access for feature (client-side fast path).
  // For server-authoritative validation use getActiveEntitlement().
  Future<bool> canAccessFeature(String featureId) async {
    try {
      final subscription = await getCurrentSubscription();
      if (subscription == null || !subscription.isActive) {
        return false;
      }

      final feature = PlanFeatures.getFeatureById(featureId);
      if (feature == null) return false;
      if (!feature.isProFeature) return true;

      return subscription.isPro;
    } catch (e) {
      return false;
    }
  }

  // Get subscription history for user.
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

  // Get subscription statistics.
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

  // NOTE: createSubscription(), updateSubscriptionStatus(), and cancelSubscription()
  // have been intentionally removed. Subscriptions are exclusively created and
  // updated by server-side edge functions (verify-razorpay-payment,
  // razorpay-webhook) using the service_role key. RLS blocks all client writes
  // to the subscriptions table, making these methods non-functional and a
  // potential attack vector for fake PRO activation.
}
