/// Shrimp pricing model for AquaRythu
/// Represents different count ranges and their corresponding prices
class ShrimpPricing {
  final int count;
  final double price;
  final DateTime? lastUpdated;
  final String? updatedBy;

  const ShrimpPricing({
    required this.count,
    required this.price,
    this.lastUpdated,
    this.updatedBy,
  });

  factory ShrimpPricing.fromJson(Map<String, dynamic> json) {
    return ShrimpPricing(
      count: json['count'] as int,
      price: (json['price'] as num).toDouble(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'price': price,
      'last_updated': lastUpdated?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  ShrimpPricing copyWith({
    int? count,
    double? price,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return ShrimpPricing(
      count: count ?? this.count,
      price: price ?? this.price,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShrimpPricing &&
        other.count == count &&
        other.price == price;
  }

  @override
  int get hashCode => count.hashCode ^ price.hashCode;

  @override
  String toString() {
    return 'ShrimpPricing(count: $count, price: $price)';
  }
}

/// Complete shrimp pricing configuration
class ShrimpPricingConfig {
  final List<ShrimpPricing> pricingTiers;
  final bool enabled;
  final String currency;
  final DateTime? lastUpdated;
  final String? updatedBy;

  const ShrimpPricingConfig({
    required this.pricingTiers,
    this.enabled = true,
    this.currency = 'INR',
    this.lastUpdated,
    this.updatedBy,
  });

  factory ShrimpPricingConfig.fromJson(Map<String, dynamic> json) {
    final pricingList = (json['pricing_tiers'] as List<dynamic>?)
            ?.map((e) => ShrimpPricing.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ShrimpPricingConfig(
      pricingTiers: pricingList,
      enabled: json['enabled'] as bool? ?? true,
      currency: json['currency'] as String? ?? 'INR',
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pricing_tiers': pricingTiers.map((e) => e.toJson()).toList(),
      'enabled': enabled,
      'currency': currency,
      'last_updated': lastUpdated?.toIso8601String(),
      'updated_by': updatedBy,
    };
  }

  /// Get default shrimp pricing configuration
  factory ShrimpPricingConfig.defaultConfig() {
    return ShrimpPricingConfig(
      pricingTiers: [
        const ShrimpPricing(count: 100, price: 270),
        const ShrimpPricing(count: 90, price: 280),
        const ShrimpPricing(count: 80, price: 300),
        const ShrimpPricing(count: 70, price: 310),
        const ShrimpPricing(count: 60, price: 320),
        const ShrimpPricing(count: 50, price: 340),
        const ShrimpPricing(count: 45, price: 350),
        const ShrimpPricing(count: 40, price: 370),
        const ShrimpPricing(count: 35, price: 380),
        const ShrimpPricing(count: 30, price: 480),
        const ShrimpPricing(count: 25, price: 540),
      ],
      enabled: true,
      currency: 'INR',
    );
  }

  /// Find price for a specific count (or closest lower tier)
  double? getPriceForCount(int count) {
    if (!enabled) return null;

    // Sort tiers by count (descending) to find the closest match
    final sortedTiers = List.from(pricingTiers)
      ..sort((a, b) => b.count.compareTo(a.count));

    for (final tier in sortedTiers) {
      if (count >= tier.count) {
        return tier.price;
      }
    }

    return null; // No pricing tier available
  }

  /// Get all pricing tiers sorted by count
  List<ShrimpPricing> get sortedTiers {
    final sorted = List<ShrimpPricing>.from(pricingTiers);
    sorted.sort((a, b) => b.count.compareTo(a.count));
    return sorted;
  }

  ShrimpPricingConfig copyWith({
    List<ShrimpPricing>? pricingTiers,
    bool? enabled,
    String? currency,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return ShrimpPricingConfig(
      pricingTiers: pricingTiers ?? this.pricingTiers,
      enabled: enabled ?? this.enabled,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() {
    return 'ShrimpPricingConfig(pricingTiers: ${pricingTiers.length}, enabled: $enabled, currency: $currency)';
  }
}

/// Shrimp pricing validation utilities
class ShrimpPricingValidator {
  static const List<int> validCounts = [
    100,
    90,
    80,
    70,
    60,
    50,
    45,
    40,
    35,
    30,
    25
  ];
  static const double minPrice = 0;
  static const double maxPrice = 10000;

  static String? validateCount(int? count) {
    if (count == null) return 'Count is required';
    if (!validCounts.contains(count)) {
      return 'Invalid count. Valid counts: ${validCounts.join(', ')}';
    }
    return null;
  }

  static String? validatePrice(String? price) {
    if (price == null || price.isEmpty) return 'Price is required';

    final priceValue = double.tryParse(price);
    if (priceValue == null) return 'Invalid price format';

    if (priceValue < minPrice) {
      return 'Price must be at least $minPrice';
    }

    if (priceValue > maxPrice) {
      return 'Price must not exceed $maxPrice';
    }

    return null;
  }

  static String? validatePricingTiers(List<ShrimpPricing>? tiers) {
    if (tiers == null || tiers.isEmpty) {
      return 'At least one pricing tier is required';
    }

    // Check for duplicate counts
    final counts = tiers.map((t) => t.count).toList();
    final uniqueCounts = counts.toSet();
    if (counts.length != uniqueCounts.length) {
      return 'Duplicate counts found in pricing tiers';
    }

    // Validate each tier
    for (final tier in tiers) {
      final countError = validateCount(tier.count);
      if (countError != null) return countError;

      if (tier.price < minPrice || tier.price > maxPrice) {
        return 'Invalid price for count ${tier.count}: ${tier.price}';
      }
    }

    // MANDATORY ORDER RULE: Count must decrease, Price must increase
    for (int i = 0; i < tiers.length - 1; i++) {
      final current = tiers[i];
      final next = tiers[i + 1];

      // Rule 1: Count must decrease (100 -> 90 -> 80)
      if (current.count <= next.count) {
        return 'Counts must be in descending order (100 -> 90 -> 80)';
      }

      // Rule 2: Price must increase as count decreases
      if (current.price >= next.price) {
        return 'Price must increase as count decreases (Count: ${current.count} -> ${next.count}, Price: ${current.price} -> ${next.price})';
      }
    }

    return null;
  }
}
