import '../../features/pond/enums/seed_type.dart';

class FeedPlan {
  final int docStart;
  final int docEnd;
  final double feedKgPer100k;

  const FeedPlan(this.docStart, this.docEnd, this.feedKgPer100k);
}

// DOC 1–25 feed table for hatchery (small shrimp)
const List<FeedPlan> hatcheryFeedTable = [
  FeedPlan(1, 3, 1.5),
  FeedPlan(4, 6, 1.6),
  FeedPlan(7, 9, 1.7),
  FeedPlan(10, 12, 1.8),
  FeedPlan(13, 15, 1.9),
  FeedPlan(16, 18, 2.0),
  FeedPlan(19, 21, 2.2),
  FeedPlan(22, 25, 2.4),
];

// DOC 1–20 feed table for nursery (big shrimp)
const List<FeedPlan> nurseryFeedTable = [
  FeedPlan(1, 2, 2.5),
  FeedPlan(3, 4, 2.7),
  FeedPlan(5, 6, 2.9),
  FeedPlan(7, 8, 3.1),
  FeedPlan(9, 10, 3.3),
  FeedPlan(11, 12, 3.5),
  FeedPlan(13, 15, 3.8),
  FeedPlan(16, 20, 4.2),
];

List<FeedPlan> feedTableFor(SeedType seedType) {
  switch (seedType) {
    case SeedType.hatcherySmall:
      return hatcheryFeedTable;
    case SeedType.nurseryBig:
      return nurseryFeedTable;
  }
}

/// Returns the max DOC covered by the table for this seed type.
int maxTableDoc(SeedType seedType) {
  final table = feedTableFor(seedType);
  return table.isEmpty ? 0 : table.last.docEnd;
}
