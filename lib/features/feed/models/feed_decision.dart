/// Feed decision model for smart feed recommendations
class FeedDecision {
  final String pondId;
  final int doc;
  final double recommendedAmount;
  final double currentAmount;
  final double adjustmentPercentage;
  final String reasoning;
  final DateTime createdAt;

  const FeedDecision({
    required this.pondId,
    required this.doc,
    required this.recommendedAmount,
    required this.currentAmount,
    required this.adjustmentPercentage,
    required this.reasoning,
    required this.createdAt,
  });

  factory FeedDecision.fromJson(Map<String, dynamic> json) {
    return FeedDecision(
      pondId: json['pond_id'] as String,
      doc: json['doc'] as int,
      recommendedAmount: (json['recommended_amount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0.0,
      adjustmentPercentage: (json['adjustment_percentage'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pond_id': pondId,
      'doc': doc,
      'recommended_amount': recommendedAmount,
      'current_amount': currentAmount,
      'adjustment_percentage': adjustmentPercentage,
      'reasoning': reasoning,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
