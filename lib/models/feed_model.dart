class FeedEntry {
  final int doc;
  final int round;
  final double quantity;
  final String feedType;
  final DateTime time;
  final bool wasAdjusted;

  FeedEntry({
    required this.doc,
    required this.round,
    required this.quantity,
    required this.feedType,
    required this.time,
    this.wasAdjusted = false,
  });
}

class FeedInput {
  final int seedCount;
  final double survivalRate;
  final double avgWeight;
  final double temperature;
  final int doc; // 🔥 ADD

  FeedInput({
    required this.seedCount,
    required this.survivalRate,
    required this.avgWeight,
    required this.temperature,
    required this.doc, // 🔥 ADD
  });
}
