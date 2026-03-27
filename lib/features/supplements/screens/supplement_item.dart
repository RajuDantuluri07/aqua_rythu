class SupplementItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String type; // "feed" or "water"
  final bool isMandatory;
  final double dosePerKg;

  SupplementItem({
    String? id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.type,
    this.isMandatory = true,
    this.dosePerKg = 0,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory SupplementItem.fromJson(Map<String, dynamic> json) {
    return SupplementItem(
      id: json['id'],
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
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'type': type,
      'isMandatory': isMandatory,
      'dosePerKg': dosePerKg,
    };
  }

  SupplementItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? type,
    bool? isMandatory,
    double? dosePerKg,
  }) {
    return SupplementItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      isMandatory: isMandatory ?? this.isMandatory,
      dosePerKg: dosePerKg ?? this.dosePerKg,
    );
  }
}