import '../../features/pond/enums/seed_type.dart';

class FeedPlan {
  final int docStart;
  final int docEnd;
  final double feedKgPer100k;

  const FeedPlan(this.docStart, this.docEnd, this.feedKgPer100k);
}

// DOC 1–20 feed table for nursery (big shrimp) - updated to match user specs
const List<FeedPlan> nurseryFeedTable = [
  FeedPlan(1, 1, 4.0),   // d1: 4kgs
  FeedPlan(2, 2, 5.0),   // d2: 5kgs
  FeedPlan(3, 3, 6.0),   // d3: 6kgs
  FeedPlan(4, 4, 7.0),   // d4: 7kgs
  FeedPlan(5, 5, 8.0),   // d5: 8kgs
  FeedPlan(6, 6, 9.0),   // d6: 9kgs
  FeedPlan(7, 7, 10.0),  // d7: 10kgs
  FeedPlan(8, 8, 11.0),  // d8: 11kgs
  FeedPlan(9, 9, 12.0),  // d9: 12kgs
  FeedPlan(10, 10, 13.0), // d10: 13kgs
  FeedPlan(11, 20, 13.0), // d11-20: maintain 13kgs
];

// Hatchery feed calculation based on incremental formula
double _calculateHatcheryFeed(int doc) {
  if (doc < 1) return 0.0;
  if (doc == 1) return 1.5; // Starting point

  double feed = 1.5; // DOC 1
  int currentDoc = 1;

  // DOC 1–7: +0.2 kg/day
  while (currentDoc < doc && currentDoc < 7) {
    feed += 0.2;
    currentDoc++;
  }

  // DOC 8–14: +0.3 kg/day
  while (currentDoc < doc && currentDoc < 14) {
    feed += 0.3;
    currentDoc++;
  }

  // DOC 15–21: +0.4 kg/day
  while (currentDoc < doc && currentDoc < 21) {
    feed += 0.4;
    currentDoc++;
  }

  // DOC 22–30: +0.5 kg/day
  while (currentDoc < doc && currentDoc < 30) {
    feed += 0.5;
    currentDoc++;
  }

  // Beyond DOC 30: continue +0.5 kg/day
  while (currentDoc < doc) {
    feed += 0.5;
    currentDoc++;
  }

  return feed;
}

// Generate hatchery feed table dynamically
List<FeedPlan> _generateHatcheryTable() {
  final table = <FeedPlan>[];
  for (int doc = 1; doc <= 30; doc++) {
    final feed = _calculateHatcheryFeed(doc);
    table.add(FeedPlan(doc, doc, feed));
  }
  return table;
}

List<FeedPlan> feedTableFor(SeedType seedType) {
  switch (seedType) {
    case SeedType.hatcherySmall:
      return _generateHatcheryTable();
    case SeedType.nurseryBig:
      return nurseryFeedTable;
  }
}

/// Returns the max DOC covered by the table for this seed type.
int maxTableDoc(SeedType seedType) {
  final table = feedTableFor(seedType);
  return table.isEmpty ? 0 : table.last.docEnd;
}
