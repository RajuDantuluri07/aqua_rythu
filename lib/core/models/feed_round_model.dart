class FeedRound {
  final int round;
  final double recommendedFeedKg;
  final double finalFeedKg;
  final bool isManuallyEdited;
  final double? leftoverPercent;
  final double? correctionPercent;
  final double? lastFeedKg;

  FeedRound({
    required this.round,
    required this.recommendedFeedKg,
    required this.finalFeedKg,
    this.isManuallyEdited = false,
    this.leftoverPercent,
    this.correctionPercent,
    this.lastFeedKg,
  });

  FeedRound copyWith({
    int? round,
    double? recommendedFeedKg,
    double? finalFeedKg,
    bool? isManuallyEdited,
    double? leftoverPercent,
    double? correctionPercent,
    double? lastFeedKg,
  }) {
    return FeedRound(
      round: round ?? this.round,
      recommendedFeedKg: recommendedFeedKg ?? this.recommendedFeedKg,
      finalFeedKg: finalFeedKg ?? this.finalFeedKg,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
      leftoverPercent: leftoverPercent ?? this.leftoverPercent,
      correctionPercent: correctionPercent ?? this.correctionPercent,
      lastFeedKg: lastFeedKg ?? this.lastFeedKg,
    );
  }
}