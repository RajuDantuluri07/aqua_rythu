enum UpgradeStage {
  early, // DOC < 25
  transition, // DOC 25–30
  smart, // DOC > 30
}

class UpgradeStageCalculator {
  static UpgradeStage calculateStage(int doc) {
    if (doc < 25) {
      return UpgradeStage.early;
    } else if (doc >= 25 && doc < 30) {
      return UpgradeStage.transition;
    } else {
      return UpgradeStage.smart;
    }
  }

  static UpgradeHeaderMessage getHeaderMessage(
      int doc, SmartValueData? smartValueData) {
    final stage = calculateStage(doc);

    switch (stage) {
      case UpgradeStage.early:
        return UpgradeHeaderMessage(
          title: "Smart feeding unlocks after DOC 30",
          subtitle: "You're in early growth phase. Upgrade to activate later.",
        );

      case UpgradeStage.transition:
        final daysUntilSmart = 30 - doc;
        return UpgradeHeaderMessage(
          title: "Smart feeding starts in $daysUntilSmart days",
          subtitle: "Most feed waste begins after DOC 30",
        );

      case UpgradeStage.smart:
        if (smartValueData != null) {
          return UpgradeHeaderMessage(
            title: "You could save ₹${smartValueData.savingsAmount} today",
            subtitle:
                "Reduce feed by ${smartValueData.reductionPercent}% based on tray",
          );
        } else {
          return UpgradeHeaderMessage(
            title: "Smart feeding is now available",
            subtitle: "Reduce waste with tray-based corrections",
          );
        }
    }
  }
}

class UpgradeHeaderMessage {
  final String title;
  final String subtitle;

  UpgradeHeaderMessage({
    required this.title,
    required this.subtitle,
  });
}

class SmartValueData {
  final int savingsAmount;
  final int reductionPercent;
  final String confidenceLevel;
  final String reason;

  SmartValueData({
    required this.savingsAmount,
    required this.reductionPercent,
    required this.confidenceLevel,
    required this.reason,
  });

  factory SmartValueData.fromFeedEngine(Map<String, dynamic> feedData) {
    // Extract data from feed engine calculations
    final reductionPercent =
        (feedData['reduction_percent'] as num?)?.toInt() ?? 0;
    final dailyFeedCost =
        (feedData['daily_feed_cost'] as num?)?.toDouble() ?? 0.0;
    final savingsAmount = (dailyFeedCost * reductionPercent / 100).round();

    return SmartValueData(
      savingsAmount: savingsAmount,
      reductionPercent: reductionPercent,
      confidenceLevel: feedData['confidence_level'] as String? ?? 'medium',
      reason: feedData['reason'] as String? ?? 'Tray analysis',
    );
  }
}
