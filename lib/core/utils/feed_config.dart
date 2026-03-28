enum FeedStage {
  beginner, // Renamed from 'blind' to match PRD
  habit, // Renamed from 'hybrid' to match PRD
  precision, // Renamed from 'strict' to match PRD
}

FeedStage getFeedStage(int doc) {
  if (doc <= 15) return FeedStage.beginner; // PRD: 1-15
  if (doc <= 30) return FeedStage.habit; // PRD: 16-30
  return FeedStage.precision; // PRD: 31+
}

class FeedConfig {
  final bool trayEnabled;
  final bool trayRequired;
  final String buttonText;

  FeedConfig({
    required this.trayEnabled,
    required this.trayRequired,
    required this.buttonText,
  });
}

FeedConfig getFeedConfig(int doc) {
  final stage = getFeedStage(doc);

  switch (stage) {
    case FeedStage.beginner:
      return FeedConfig(
        trayEnabled: false,
        trayRequired: false,
        buttonText: "MARK AS FED",
      );

    case FeedStage.habit:
      return FeedConfig(
        trayEnabled: true,
        trayRequired: false,
        buttonText:
            "MARK AS FED", // Button text is the same, but shows optional tray log after
      );

    case FeedStage.precision:
      return FeedConfig(
        trayEnabled: true,
        trayRequired: true,
        buttonText:
            "MARK AS FED", // Button text is the same, but forces tray log after
      );
  }
}
