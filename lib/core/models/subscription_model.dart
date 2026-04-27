enum PlanType {
  FREE,
  PRO,
}

enum SubscriptionStatus {
  ACTIVE,
  EXPIRED,
  CANCELLED,
  PENDING,
}

class Subscription {
  final String id;
  final String userId;
  final String farmId;
  final PlanType planType;
  final DateTime startDate;
  final DateTime? endDate;
  final SubscriptionStatus status;
  final double price;
  final String currency;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.farmId,
    required this.planType,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.price,
    this.currency = 'INR',
    required this.createdAt,
    this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      farmId: json['farm_id'] as String,
      planType: PlanType.values.firstWhere(
        (e) => e.name == json['plan_type'],
        orElse: () => PlanType.FREE,
      ),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.PENDING,
      ),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'farm_id': farmId,
      'plan_type': planType.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status.name,
      'price': price,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isActive => status == SubscriptionStatus.ACTIVE &&
      (endDate == null || endDate!.isAfter(DateTime.now()));

  bool get isPro => planType == PlanType.PRO && isActive;

  Subscription copyWith({
    String? id,
    String? userId,
    String? farmId,
    PlanType? planType,
    DateTime? startDate,
    DateTime? endDate,
    SubscriptionStatus? status,
    double? price,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      farmId: farmId ?? this.farmId,
      planType: planType ?? this.planType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      price: price ?? this.price,
      currency: currency ?? this.currency,
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
