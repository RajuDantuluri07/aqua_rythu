const double _feedPricePerKg = 65.0;

class PondCardData {
  final String pondId;
  final String pondName;
  final double size;       // acres
  final int doc;
  final double density;    // lakh/acre
  final double survival;   // 0–100 %
  final double todayFeed;  // kg (scheduled base)
  final double abw;        // grams
  final double fcr;
  final bool hasSampling;
  final bool hasTray;
  final double trayFactor;    // ratio: 0.85 = -15%, 1.10 = +10%
  final double growthFactor;  // ratio: actual/expected ABW
  final double finalFactor;   // (suggestedFeed/todayFeed) - 1.0
  final double suggestedFeed; // kg (after smart factors)
  final double percentChange;  // clamped to [-30, +30]
  final double moneySaved;    // ₹ positive=saved, negative=extra cost
  final String status;        // 'Good' | 'Attention' | 'Risk'
  final String confidence;    // 'High' | 'Medium' | 'Low'
  final bool isSmartMode;
  final String trayResult;    // 'Leftover' | 'Empty' | 'Normal' | '—'
  final String growthLabel;   // 'Good' | 'Slow' | 'Fast' | '—'
  final String feedStage;     // 'blind' | 'transitional' | 'intelligent'

  const PondCardData({
    required this.pondId,
    required this.pondName,
    required this.size,
    required this.doc,
    required this.density,
    required this.survival,
    required this.todayFeed,
    required this.abw,
    required this.fcr,
    required this.hasSampling,
    required this.hasTray,
    required this.trayFactor,
    required this.growthFactor,
    required this.finalFactor,
    required this.suggestedFeed,
    required this.percentChange,
    required this.moneySaved,
    required this.status,
    required this.confidence,
    required this.isSmartMode,
    required this.trayResult,
    required this.growthLabel,
    required this.feedStage,
  });

  String get suggestionText {
    if (!isSmartMode) return 'Follow schedule';
    final abs = percentChange.abs();
    if (percentChange < -1) {
      return 'Reduce by ${abs.toStringAsFixed(0)}% (overfeeding detected)';
    }
    if (percentChange > 1) {
      return 'Increase by ${abs.toStringAsFixed(0)}% (growth lagging)';
    }
    return 'Maintain current feed';
  }

  String get moneySavedLabel {
    if (!isSmartMode || moneySaved == 0) return 'No optimization yet';
    if (moneySaved > 0) return 'Saved: ₹${moneySaved.toStringAsFixed(0)}';
    return 'Extra: ₹${moneySaved.abs().toStringAsFixed(0)}';
  }

  static double get feedPrice => _feedPricePerKg;
}
