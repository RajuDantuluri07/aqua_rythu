class FeedBrand {
  final String id;
  final String name;
  final double? defaultPricePerKg;
  final String? description;

  const FeedBrand({
    required this.id,
    required this.name,
    this.defaultPricePerKg,
    this.description,
  });

  factory FeedBrand.fromJson(Map<String, dynamic> json) {
    return FeedBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultPricePerKg: (json['default_price_per_kg'] as num?)?.toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'default_price_per_kg': defaultPricePerKg,
    'description': description,
  };

  @override
  String toString() => 'FeedBrand($name)';
}
