/// Feed recommendation model for smart feeding suggestions.
class FeedRecommendation {
  final String pondId;
  final int doc;
  final double baselineFeed;
  final double adjustedFeedAmount;
  final double adjustmentFactor;
  final List<String> factors;
  final String confidence;
  final DateTime createdAt;

  const FeedRecommendation({
    required this.pondId,
    required this.doc,
    required this.baselineFeed,
    required this.adjustedFeedAmount,
    required this.adjustmentFactor,
    required this.factors,
    required this.confidence,
    required this.createdAt,
  });

  factory FeedRecommendation.fromJson(Map<String, dynamic> json) {
    final adjustedFeed = (json['adjusted_feed_amount'] as num?)?.toDouble() ??
        (json['actual_feed'] as num?)?.toDouble() ??
        (json['recommended_feed'] as num?)?.toDouble() ??
        0.0;

    return FeedRecommendation(
      pondId: json['pond_id'] as String,
      doc: json['doc'] as int,
      baselineFeed: (json['baseline_feed'] as num?)?.toDouble() ??
          (json['base_feed'] as num?)?.toDouble() ??
          (json['recommended_feed'] as num?)?.toDouble() ??
          adjustedFeed,
      adjustedFeedAmount: adjustedFeed,
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
      'baseline_feed': baselineFeed,
      'adjusted_feed_amount': adjustedFeedAmount,
      'adjustment_factor': adjustmentFactor,
      'factors': factors,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
