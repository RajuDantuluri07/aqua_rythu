/// Single source of truth for subscription plan definitions.
/// Replaces hardcoded pricing and plan ID strings scattered across the codebase.
class SubscriptionPlan {
  /// Unique plan identifier sent to backend (planType parameter in Razorpay/Supabase calls)
  final String id;

  /// Razorpay amount in paise (₹ × 100)
  final int amountPaise;

  /// Price in Indian Rupees (stored in pending_payments.price)
  final double price;

  /// Subscription validity period in days
  final int durationDays;

  /// Display name shown in UI
  final String displayName;

  /// Description used in Razorpay checkout
  final String description;

  const SubscriptionPlan({
    required this.id,
    required this.amountPaise,
    required this.price,
    required this.durationDays,
    required this.displayName,
    required this.description,
  });
}

/// All available subscription plans. Central registry for pricing and durations.
class SubscriptionPlans {
  /// Full Crop Plan: ₹999 per crop, valid for 120 days (one crop cycle)
  static const fullCrop = SubscriptionPlan(
    id: 'full_crop',
    amountPaise: 99900,
    price: 999.0,
    durationDays: 120,
    displayName: 'Full Crop Plan',
    description: 'PRO Subscription (Per Crop)',
  );

  /// Yearly PRO Plan: ₹2999/year, valid for 365 days
  static const yearly = SubscriptionPlan(
    id: 'yearly_pro',
    amountPaise: 299900,
    price: 2999.0,
    durationDays: 365,
    displayName: 'Yearly PRO Plan',
    description: 'PRO Subscription (Yearly)',
  );

  /// All available plans for iteration
  static const all = [fullCrop, yearly];

  /// Look up plan by ID; defaults to fullCrop if not found
  static SubscriptionPlan fromId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => fullCrop);
}
