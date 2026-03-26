class SupplementItem {
  final String name;
  final double quantity;
  final String unit;
  final String type; // "feed" or "water"

  SupplementItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.type,
  });

  factory SupplementItem.fromJson(Map<String, dynamic> json) {
    return SupplementItem(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      type: json['type'] ?? 'feed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'type': type,
    };
  }
}