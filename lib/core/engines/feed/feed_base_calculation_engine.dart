import './engine_constants.dart';
import '../../utils/logger.dart';

/// Pure feed math for base and smart feed calculations.
/// Keeps service classes free of arithmetic and interpolation logic.
class FeedBaseCalculationEngine {
  static const int _stockingPerAcre = 100000;

  double getFeedAmount({
    required int doc,
    required double pondArea,
    double? abw,
  }) {
    if (doc <= 30) return getBlindFeed(doc, pondArea);
    return getSmartFeed(doc, pondArea, abw);
  }

  double getBlindFeed(int doc, double pondArea) {
    final defaultRate = _getDefaultBlindFeedRate(doc);
    final feedAmount = defaultRate * pondArea;
    AppLogger.debug(
      'FeedBaseCalculationEngine blind feed: DOC=$doc rate=$defaultRate total=${feedAmount.toStringAsFixed(2)}kg',
    );
    return feedAmount;
  }

  double getSmartFeed(int doc, double pondArea, double? abw) {
    if (abw == null || abw <= 0) {
      return getBlindFeed(doc, pondArea);
    }

    final survival = _interpolate(FeedEngineConstants.survivalRates, doc);
    final feedingRate = _interpolate(FeedEngineConstants.feedingRates, doc);
    final biomassKgPerAcre = _stockingPerAcre * survival * abw / 1000;
    final feedKgPerAcre = biomassKgPerAcre * feedingRate;
    final total = feedKgPerAcre * pondArea;

    AppLogger.debug(
      'FeedBaseCalculationEngine smart feed: DOC=$doc abw=${abw}g survival=${survival.toStringAsFixed(2)} '
      'rate=${feedingRate.toStringAsFixed(3)} total=${total.toStringAsFixed(2)}kg',
    );
    return total;
  }

  double _getDefaultBlindFeedRate(int doc) {
    if (doc <= 5) return 2.0;
    if (doc <= 10) return 3.0;
    if (doc <= 15) return 4.0;
    if (doc <= 20) return 5.0;
    if (doc <= 25) return 6.0;
    return 7.0;
  }

  double _interpolate(Map<int, double> table, int doc) {
    final keys = table.keys.toList()..sort();
    if (doc <= keys.first) return table[keys.first]!;
    if (doc >= keys.last) return table[keys.last]!;

    for (int i = 0; i < keys.length - 1; i++) {
      final k1 = keys[i], k2 = keys[i + 1];
      if (doc >= k1 && doc <= k2) {
        final t = (doc - k1) / (k2 - k1);
        return table[k1]! + t * (table[k2]! - table[k1]!);
      }
    }

    return table[keys.last]!;
  }

  static double sumRounds(List<double> rounds) =>
      rounds.fold(0.0, (sum, round) => sum + round);

  static int oneBasedIndex(int zeroBased) => zeroBased + 1;

  static int futureDocFor(int doc, int offset) => doc + offset;

  static int nextDoc(int doc) => doc + 1;

  static double adjustedFeed(double base, double factor) =>
      (base * factor).clamp(base * 0.70, base * 1.30);

  static int factorPct(double factor) =>
      ((factor - 1.0) * 100).round();
}
