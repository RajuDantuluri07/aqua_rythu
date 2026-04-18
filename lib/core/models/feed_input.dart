import '../enums/tray_status.dart';
import '../enums/stocking_type.dart';

class FeedInput {
  final int seedCount;
  final int doc;
  final double? abw;
  final StockingType stockingType;

  final double feedingScore;
  final double intakePercent;

  final double dissolvedOxygen;
  final double temperature;
  final double phChange;
  final double ammonia;

  final int mortality;

  final List<TrayStatus> trayStatuses;
  final int sampleAgeDays;
  final List<double> recentTrayLeftoverPct;

  final double? lastFcr;
  final double? actualFeedYesterday;
  final DateTime? lastFeedTime;

  // Anchor feed for DOC > 30 hybrid flow (farmer-set baseline)
  final double? anchorFeed;

  FeedInput({
    required this.seedCount,
    required this.doc,
    this.abw,
    this.stockingType = StockingType.nursery,
    required this.feedingScore,
    required this.intakePercent,
    required this.dissolvedOxygen,
    required this.temperature,
    required this.phChange,
    required this.ammonia,
    required this.mortality,
    required this.trayStatuses,
    this.sampleAgeDays = 0,
    this.recentTrayLeftoverPct = const [],
    this.lastFcr,
    this.actualFeedYesterday,
    this.lastFeedTime,
    this.anchorFeed,
  });
}
