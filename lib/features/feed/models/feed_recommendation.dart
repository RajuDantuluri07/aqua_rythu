/// Feed recommendation model for smart feeding suggestions
class FeedRecommendation {
  final String pondId;
  final int doc;
  final double baseFeedAmount;
  final double adjustedFeedAmount;
  final double adjustmentFactor;
  final List<String> factors;
  final String confidence;
  final DateTime createdAt;

  const FeedRecommendation({
    required this.pondId,
    required this.doc,
    required this.baseFeedAmount,
    required this.adjustedFeedAmount,
    required this.adjustmentFactor,
    required this.factors,
    required this.confidence,
    required this.createdAt,
  });

  factory FeedRecommendation.fromJson(Map<String, dynamic> json) {
    return FeedRecommendation(
      pondId: json['pond_id'] as String,
      doc: json['doc'] as int,
      baseFeedAmount: (json['base_feed_amount'] as num?)?.toDouble() ?? 0.0,
      adjustedFeedAmount: (json['adjusted_feed_amount'] as num?)?.toDouble() ?? 0.0,
      adjustmentFactor: (json['adjustment_factor'] as num?)?.toDouble() ?? 1.0,
      factors: (json['factors'] as List<dynamic>?)?.cast<String>() ?? [],
      confidence: json['confidence'] as String? ?? 'medium',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pond_id': pondId,
      'doc': doc,
      'base_feed_amount': baseFeedAmount,
      'adjusted_feed_amount': adjustedFeedAmount,
      'adjustment_factor': adjustmentFactor,
      'factors': factors,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
