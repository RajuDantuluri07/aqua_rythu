class FeedMasterProduct {
  final String id;
  final String brand;
  final String? productCode;
  final String productName;
  final String? cultureType;
  final String? stage;
  final String? pelletSizeMm;
  final double? proteinPercent;
  final double? bagWeightKg;
  final String? feedType;
  final bool active;

  const FeedMasterProduct({
    required this.id,
    required this.brand,
    this.productCode,
    required this.productName,
    this.cultureType,
    this.stage,
    this.pelletSizeMm,
    this.proteinPercent,
    this.bagWeightKg,
    this.feedType,
    this.active = true,
  });

  String get displayName => '$brand $productName';

  factory FeedMasterProduct.fromJson(Map<String, dynamic> json) {
    return FeedMasterProduct(
      id: json['id'] as String,
      brand: json['brand'] as String,
      productCode: json['product_code'] as String?,
      productName: json['product_name'] as String,
      cultureType: json['culture_type'] as String?,
      stage: json['stage'] as String?,
      pelletSizeMm: json['pellet_size_mm'] as String?,
      proteinPercent: (json['protein_percent'] as num?)?.toDouble(),
      bagWeightKg: (json['bag_weight_kg'] as num?)?.toDouble(),
      feedType: json['feed_type'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'product_code': productCode,
        'product_name': productName,
        'culture_type': cultureType,
        'stage': stage,
        'pellet_size_mm': pelletSizeMm,
        'protein_percent': proteinPercent,
        'bag_weight_kg': bagWeightKg,
        'feed_type': feedType,
        'active': active,
      };
}
