class SupplementItem {
  final String name;
  final double quantity;
  final String unit;
  final String type; // "feed" or "water"
  final bool isMandatory;
  final double dosePerKg;

  SupplementItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.type,
    this.isMandatory = true,
    this.dosePerKg = 0,
  });

  factory SupplementItem.fromJson(Map<String, dynamic> json) {
    return SupplementItem(
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      type: json['type'] ?? 'feed',
      isMandatory: json['isMandatory'] ?? true,
      dosePerKg: (json['dosePerKg'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'type': type,
      'isMandatory': isMandatory,
      'dosePerKg': dosePerKg,
    };
  }
}