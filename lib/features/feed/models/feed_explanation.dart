import '../../pond/enums/seed_type.dart';

class FeedExplanation {
  final double baseFeed;
  final double trayImpact;  // additive factor, e.g. -0.10 means -10%
  final double smartImpact; // additive factor, e.g. +0.05 means +5%
  final double finalFeed;
  final String message;
  final SeedType seedType;
  final int doc;
  final bool isSeedTablePhase; // true when DOC is within the seed table range
  final double? savingsRupees; // estimated rupee savings from tray reduction

  const FeedExplanation({
    required this.baseFeed,
    required this.trayImpact,
    required this.smartImpact,
    required this.finalFeed,
    required this.message,
    required this.seedType,
    required this.doc,
    required this.isSeedTablePhase,
    this.savingsRupees,
  });

  double get trayFactorPercent => trayImpact * 100;
  double get smartFactorPercent => smartImpact * 100;

  String get trayLabel {
    if (trayImpact < 0) return 'Tray leftover → reduced by ${(-trayImpact * 100).round()}%';
    if (trayImpact > 0) return 'Tray empty fast → increased by ${(trayImpact * 100).round()}%';
    return 'Tray normal → no adjustment';
  }

  String get smartLabel {
    if (smartImpact < 0) return 'Conservative phase → reduced by ${(-smartImpact * 100).round()}%';
    if (smartImpact > 0) return 'Growth push → increased by ${(smartImpact * 100).round()}%';
    return 'Smart factor → no adjustment';
  }
}
