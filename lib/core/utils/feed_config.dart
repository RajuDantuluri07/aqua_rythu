enum FeedStage {
  blind,
  hybrid,
  strict,
}

FeedStage getFeedStage(int doc) {
  if (doc < 15) return FeedStage.blind;
  if (doc <= 30) return FeedStage.hybrid;
  return FeedStage.strict;
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
    case FeedStage.blind:
      return FeedConfig(
        trayEnabled: false,
        trayRequired: false,
        buttonText: "MARK AS FED",
      );

    case FeedStage.hybrid:
      return FeedConfig(
        trayEnabled: true,
        trayRequired: false,
        buttonText: "LOG TRAY & FEED",
      );

    case FeedStage.strict:
      return FeedConfig(
        trayEnabled: true,
        trayRequired: true,
        buttonText: "LOG TRAY (REQUIRED)",
      );
  }
}
