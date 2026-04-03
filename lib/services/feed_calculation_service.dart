import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Single Source of Truth for Feed Calculations
/// Ensures consistent feed amounts across dashboard and feed cards
class FeedCalculationService {
  static Map<int, double>? _baseRatesCache;

  /// Get feed amount for specific pond and DOC
  static double getFeedAmount({
    required int doc,
    required double pondArea,
    double? abw,
  }) {
    print("🧮 FEED CALC: DOC: $doc | Area: $pondArea | ABW: $abw");
    
    if (doc <= 30) {
      return getBlindFeed(doc, pondArea);
    } else {
      return getSmartFeed(doc, pondArea, abw);
    }
  }

  /// Blind feed calculation (DOC ≤ 30)
  static double getBlindFeed(int doc, double pondArea) {
    final baseRate = _getBaseRate(doc);
    final feedAmount = baseRate * pondArea;
    
    print("🟡 BLIND FEED: DOC: $doc | Base: $baseRate | Total: ${feedAmount.toStringAsFixed(2)} kg");
    return feedAmount;
  }

  /// Smart feed calculation (DOC > 30) - placeholder for now
  static double getSmartFeed(int doc, double pondArea, double? abw) {
    // TODO: Implement smart feed calculation using ABW, water quality, etc.
    // For now, use blind feed as fallback
    return getBlindFeed(doc, pondArea);
  }

  /// Get base feed rate from database
  static double _getBaseRate(int doc) {
    // Load base rates if not cached
    if (_baseRatesCache == null) {
      // For now, return default value to avoid blocking
      // TODO: Implement proper async loading
      print("⚠️ Base rates not loaded, using default");
      return 0.0;
    }
    
    return _baseRatesCache![doc] ?? 0.0;
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
    } catch (e) {
      print('❌ Failed to load base rates: $e');
      _baseRatesCache = {};
    }
  }

  /// Clear cache (for testing)
  static void clearCache() {
    _baseRatesCache = null;
  }
}
