class Harvest {
  final String? id;
  final String cropId;
  final double totalWeight;
  final double pricePerKg;
  final DateTime date;
  final DateTime? createdAt;

  Harvest({
    this.id,
    required this.cropId,
    required this.totalWeight,
    required this.pricePerKg,
    required this.date,
    this.createdAt,
  });

  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id']?.toString(),
      cropId: map['crop_id']?.toString() ?? '',
      totalWeight: (map['total_weight'] as num?)?.toDouble() ?? 0.0,
      pricePerKg: (map['price_per_kg'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'crop_id': cropId,
      'total_weight': totalWeight,
      'price_per_kg': pricePerKg,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Calculate revenue from this harvest
  double get revenue => totalWeight * pricePerKg;

  Harvest copyWith({
    String? id,
    String? cropId,
    double? totalWeight,
    double? pricePerKg,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return Harvest(
      id: id ?? this.id,
      cropId: cropId ?? this.cropId,
      totalWeight: totalWeight ?? this.totalWeight,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProfitCalculation {
  final double feedCost;
  final double otherCost;
  final double totalCost;
  final double revenue;
  final double profit;
  final bool isFinal; // true for final profit, false for estimated

  ProfitCalculation({
    required this.feedCost,
    required this.otherCost,
    required this.totalCost,
    required this.revenue,
    required this.profit,
    required this.isFinal,
  });

  factory ProfitCalculation.estimated({
    required double feedCost,
    required double otherCost,
    required double revenue,
  }) {
    final totalCost = feedCost + otherCost;
    return ProfitCalculation(
      feedCost: feedCost,
      otherCost: otherCost,
      totalCost: totalCost,
      revenue: revenue,
      profit: revenue - totalCost,
      isFinal: false,
    );
  }

  factory ProfitCalculation.final_({
    required double feedCost,
    required double otherCost,
    required double revenue,
  }) {
    final totalCost = feedCost + otherCost;
    return ProfitCalculation(
      feedCost: feedCost,
      otherCost: otherCost,
      totalCost: totalCost,
      revenue: revenue,
      profit: revenue - totalCost,
      isFinal: true,
    );
  }

  String get profitType => isFinal ? 'Final' : 'Estimated';

  Map<String, dynamic> toMap() {
    return {
      'feed_cost': feedCost,
      'other_cost': otherCost,
      'total_cost': totalCost,
      'revenue': revenue,
      'profit': profit,
      'is_final': isFinal,
      'profit_type': profitType,
    };
  }
}
