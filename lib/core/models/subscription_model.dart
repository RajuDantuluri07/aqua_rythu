enum PlanType {
  free,
  pro,
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  pending,
}

class Subscription {
  final String id;
  final String userId;
  final PlanType planType;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final SubscriptionStatus status;
  final String? paymentStatus;
  final String? razorpaySubscriptionId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.planType,
    this.activatedAt,
    this.expiresAt,
    required this.status,
    this.paymentStatus,
    this.razorpaySubscriptionId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planType: PlanType.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['plan'] as String?)?.toLowerCase(),
        orElse: () => PlanType.free,
      ),
      activatedAt: json['activated_at'] != null ? DateTime.parse(json['activated_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status'] as String?)?.toLowerCase(),
        orElse: () => SubscriptionStatus.pending,
      ),
      paymentStatus: json['payment_status'] as String?,
      razorpaySubscriptionId: json['razorpay_subscription_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan': planType.name.toLowerCase(),
      'activated_at': activatedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'status': status.name.toLowerCase(),
      'payment_status': paymentStatus,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == SubscriptionStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get isPro => planType == PlanType.pro && isActive;

  Subscription copyWith({
    String? id,
    String? userId,
    PlanType? planType,
    DateTime? activatedAt,
    DateTime? expiresAt,
    SubscriptionStatus? status,
    String? paymentStatus,
    String? razorpaySubscriptionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planType: planType ?? this.planType,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      razorpaySubscriptionId: razorpaySubscriptionId ?? this.razorpaySubscriptionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FeatureAccess {
  final String featureId;
  final String name;
  final String description;
  final bool isProFeature;
  final String? upgradeMessage;

  const FeatureAccess({
    required this.featureId,
    required this.name,
    required this.description,
    required this.isProFeature,
    this.upgradeMessage,
  });
}

class PlanFeatures {
  static const List<FeatureAccess> allFeatures = [
    FeatureAccess(
      featureId: 'feed_schedule_basic',
      name: 'Feed schedule (DOC <30)',
      description: 'Basic feeding schedule for first 30 days',
      isProFeature: false,
    ),
    FeatureAccess(
      featureId: 'smart_feed_engine',
      name: 'Smart feed engine',
      description: '6-factor intelligent feeding calculations',
      isProFeature: true,
      upgradeMessage: 'Upgrade to PRO for full precision feeding',
    ),
    FeatureAccess(
      featureId: 'tray_based_correction',
      name: 'Tray-based correction',
      description: 'Adjust feeding based on tray monitoring',
      isProFeature: true,
      upgradeMessage: 'PRO unlocks tray-based optimization',
    ),
    FeatureAccess(
      featureId: 'growth_intelligence',
      name: 'Growth intelligence (ABW)',
      description: 'Advanced growth tracking and insights',
      isProFeature: true,
      upgradeMessage: 'Get advanced ABW insights with PRO',
    ),
    FeatureAccess(
      featureId: 'profit_tracking',
      name: 'Profit tracking',
      description: 'Track profitability in real-time',
      isProFeature: true,
      upgradeMessage: 'Know your profit before harvest with PRO',
    ),
    FeatureAccess(
      featureId: 'multi_pond_comparison',
      name: 'Multi-pond comparison',
      description: 'Compare performance across ponds',
      isProFeature: true,
      upgradeMessage: 'Compare ponds efficiently with PRO',
    ),
    FeatureAccess(
      featureId: 'crop_report',
      name: 'Crop report (PDF)',
      description: 'Generate detailed crop reports',
      isProFeature: true,
      upgradeMessage: 'Export professional reports with PRO',
    ),
    FeatureAccess(
      featureId: 'worker_roles',
      name: 'Worker / Supervisor roles',
      description: 'Team management and access control',
      isProFeature: true,
      upgradeMessage: 'Manage your team with PRO',
    ),
  ];

  static FeatureAccess? getFeatureById(String featureId) {
    try {
      return allFeatures.firstWhere((feature) => feature.featureId == featureId);
    } catch (e) {
      return null;
    }
  }

  static List<FeatureAccess> getProFeatures() {
    return allFeatures.where((feature) => feature.isProFeature).toList();
  }

  static List<FeatureAccess> getFreeFeatures() {
    return allFeatures.where((feature) => !feature.isProFeature).toList();
  }
}
