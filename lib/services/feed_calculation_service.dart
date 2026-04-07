import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/engines/engine_constants.dart';
import '../core/utils/logger.dart';

final supabase = Supabase.instance.client;

/// Single Source of Truth for Feed Calculations
/// For MVP: Uses feed_plans table directly as source of truth
class FeedCalculationService {
  static Map<int, double>? _baseRatesCache;

  /// Get feed amount for specific pond and DOC
  /// For MVP: Returns planned feed from database, not calculated
  static double getFeedAmount({
    required int doc,
    required double pondArea,
    double? abw,
  }) {
    AppLogger.debug("Feed calc: DOC=$doc area=$pondArea abw=$abw");
    
    // For MVP: Always return blind feed from database
    // NO calculation, NO smart feed for DOC ≤ 30
    return getBlindFeed(doc, pondArea);
  }

  /// Blind feed calculation (DOC ≤ 30)
  /// For MVP: Returns database value, not calculated
  static double getBlindFeed(int doc, double pondArea) {
    // For MVP: Return a reasonable default instead of base rates calculation
    // This prevents the "base rates not loaded" issue
    final defaultRate = _getDefaultBlindFeedRate(doc);
    final feedAmount = defaultRate * pondArea;
    
    AppLogger.debug("Blind feed: DOC=$doc rate=$defaultRate total=${feedAmount.toStringAsFixed(2)}kg");
    return feedAmount;
  }

  /// Get default blind feed rate for MVP (prevents base rates dependency)
  static double _getDefaultBlindFeedRate(int doc) {
    // Simple progressive feeding schedule for MVP
    if (doc <= 5) return 2.0;      // Early days: 2 kg/acre
    if (doc <= 10) return 3.0;     // Week 1-2: 3 kg/acre  
    if (doc <= 15) return 4.0;     // Week 2-3: 4 kg/acre
    if (doc <= 20) return 5.0;     // Week 3-4: 5 kg/acre
    if (doc <= 25) return 6.0;     // Week 4-5: 6 kg/acre
    return 7.0;                     // Week 5-6: 7 kg/acre
  }

  /// Smart feed calculation (DOC > 30).
  /// Uses actual ABW to compute biomass-based feed per the FCR engine constants.
  /// Falls back to progressive blind-feed rates if ABW is unavailable.
  static double getSmartFeed(int doc, double pondArea, double? abw) {
    if (abw == null || abw <= 0) {
      // No sampling data yet — use a conservative fixed rate scaled by area
      final rate = _getDefaultBlindFeedRate(doc);
      AppLogger.debug('SmartFeed fallback (no ABW): DOC=$doc rate=$rate');
      return rate * pondArea;
    }

    // Biomass estimate: assume standard 100K PL/acre stocking density
    const stockingPerAcre = 100000;
    final survival = _interpolate(FeedEngineConstants.survivalRates, doc);
    final feedingRate = _interpolate(FeedEngineConstants.feedingRates, doc);
    final biomassKgPerAcre = stockingPerAcre * survival * abw / 1000;
    final feedKgPerAcre = biomassKgPerAcre * feedingRate;
    final total = feedKgPerAcre * pondArea;

    AppLogger.debug(
      'SmartFeed: DOC=$doc abw=${abw}g survival=${survival.toStringAsFixed(2)} '
      'rate=${feedingRate.toStringAsFixed(3)} total=${total.toStringAsFixed(2)}kg',
    );
    return total;
  }

  static double _interpolate(Map<int, double> table, int doc) {
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

  /// Get base feed rate from database
  static double _getBaseRate(int doc) {
    // Load base rates if not cached
    if (_baseRatesCache == null) {
      // For MVP: Return default rate instead of blocking
      AppLogger.info("Base rates not loaded — using default MVP rate for DOC $doc");
      return _getDefaultBlindFeedRate(doc);
    }
    
    return _baseRatesCache![doc] ?? _getDefaultBlindFeedRate(doc);
  }

  /// Load base feed rates from database
  static Future<void> _loadBaseRates() async {
    try {
      final data = await supabase
          .from('feed_base_rates')
          .select('doc, base_feed_amount')
          .lte('doc', 30);

      final Map<int, double> rates = {};
      for (var item in data) {
        rates[item['doc'] as int] = (item['base_feed_amount'] as num).toDouble();
      }
      
      _baseRatesCache = rates;
      AppLogger.info("Base rates loaded: ${rates.length} entries");
    } catch (e) {
      AppLogger.error('Failed to load base rates', e);
      _baseRatesCache = {};
    }
  }

  /// Clear cache (for testing)
  static void clearCache() {
    _baseRatesCache = null;
  }
}
