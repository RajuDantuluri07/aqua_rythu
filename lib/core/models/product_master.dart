class ProductMaster {
  final String id;
  final String? brand;
  final String productName;
  final String category;
  final String? subCategory;
  final String? form;
  final String? unitType;
  final double? packageSize;
  final String? baseUnit;
  final bool active;

  const ProductMaster({
    required this.id,
    this.brand,
    required this.productName,
    required this.category,
    this.subCategory,
    this.form,
    this.unitType,
    this.packageSize,
    this.baseUnit,
    this.active = true,
  });

  String get displayName =>
      (brand != null && brand!.isNotEmpty) ? '$brand $productName' : productName;

  factory ProductMaster.fromJson(Map<String, dynamic> json) {
    return ProductMaster(
      id: json['id'] as String,
      brand: json['brand'] as String?,
      productName: json['product_name'] as String,
      category: json['category'] as String,
      subCategory: json['sub_category'] as String?,
      form: json['form'] as String?,
      unitType: json['unit_type'] as String?,
      packageSize: (json['package_size'] as num?)?.toDouble(),
      baseUnit: json['base_unit'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'product_name': productName,
        'category': category,
        'sub_category': subCategory,
        'form': form,
        'unit_type': unitType,
        'package_size': packageSize,
        'base_unit': baseUnit,
        'active': active,
      };
}

/// All valid product categories for the product_master table.
class ProductCategory {
  static const feedSupplement = 'Feed Supplement';
  static const waterSupplement = 'Water Supplement';
  static const probiotic = 'Probiotic';
  static const mineral = 'Mineral';
  static const medicine = 'Medicine';
  static const pondPreparation = 'Pond Preparation';
  static const waterTreatment = 'Water Treatment';
  static const disinfectant = 'Disinfectant';

  static const all = [
    feedSupplement,
    waterSupplement,
    probiotic,
    mineral,
    medicine,
    pondPreparation,
    waterTreatment,
    disinfectant,
  ];

  /// Categories shown for Feed Mix supplements
  static const feedMixCategories = [feedSupplement];

  /// Categories shown for Water Mix supplements
  static const waterMixCategories = [
    waterSupplement,
    probiotic,
    mineral,
    waterTreatment,
    disinfectant,
  ];
}
