import 'package:aqua_rythu/systems/feed_intelligence_engine.dart';

class FarmScenario {
  final String name;
  final double trayFactor;
  final double growthFactor;
  final double environmentFactor;
  final double fcrFactor;
  final FeedStatus intelligenceStatus;
  final bool hasActualData;
  final bool isCriticalStop;
  final String expectedAction;

  const FarmScenario({
    required this.name,
    required this.trayFactor,
    required this.growthFactor,
    required this.environmentFactor,
    required this.fcrFactor,
    required this.intelligenceStatus,
    required this.hasActualData,
    required this.isCriticalStop,
    required this.expectedAction,
  });
}
