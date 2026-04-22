import '../utils/logger.dart';

class FeedSafetyService {
  static final FeedSafetyService _instance = FeedSafetyService._internal();
  factory FeedSafetyService() => _instance;
  FeedSafetyService._internal();

  // Safe feed limits
  static const double _minFeedPerPond = 0.0; // kg
  static const double _maxFeedPerPond = 10000.0; // kg
  static const double _minFeedMultiplier = 0.1;
  static const double _maxFeedMultiplier = 5.0;
  static const double _minFeedPrice = 0.0; // per kg
  static const double _maxFeedPrice = 500.0; // per kg

  /// Clamp feed amount to safe range
  double clampFeedAmount(double feedAmount, String pondId) {
    final clamped = feedAmount.clamp(_minFeedPerPond, _maxFeedPerPond);
    
    if (clamped != feedAmount) {
      AppLogger.warn(
        'Feed amount clamped for pond $pondId: ${feedAmount.toStringAsFixed(2)}kg -> ${clamped.toStringAsFixed(2)}kg'
      );
    }
    
    return clamped;
  }

  /// Clamp feed multiplier to safe range
  double clampFeedMultiplier(double multiplier) {
    final clamped = multiplier.clamp(_minFeedMultiplier, _maxFeedMultiplier);
    
    if (clamped != multiplier) {
      AppLogger.warn(
        'Feed multiplier clamped: ${multiplier.toStringAsFixed(2)} -> ${clamped.toStringAsFixed(2)}'
      );
    }
    
    return clamped;
  }

  /// Clamp feed price to safe range
  double clampFeedPrice(double price) {
    final clamped = price.clamp(_minFeedPrice, _maxFeedPrice);
    
    if (clamped != price) {
      AppLogger.warn(
        'Feed price clamped: ${price.toStringAsFixed(2)} -> ${clamped.toStringAsFixed(2)}'
      );
    }
    
    return clamped;
  }

  /// Validate and clamp feed calculation result
  FeedSafetyResult validateFeedCalculation({
    required double calculatedFeed,
    required String pondId,
    double? multiplier,
    double? baseFeed,
    String? calculationType,
  }) {
    // Check for negative values
    if (calculatedFeed < 0) {
      AppLogger.error(
        'Negative feed calculation detected for pond $pondId: $calculatedFeed kg',
        {
          'pond_id': pondId,
          'calculated_feed': calculatedFeed,
          'multiplier': multiplier,
          'base_feed': baseFeed,
          'calculation_type': calculationType,
        }
      );
      
      return FeedSafetyResult(
        originalAmount: calculatedFeed,
        safeAmount: 0.0,
        wasClamped: true,
        reason: 'Negative feed amount detected, set to 0',
      );
    }

    // Check for unrealistic spikes (more than 10x previous day)
    // This would need historical data, for now we'll just clamp to max
    if (calculatedFeed > _maxFeedPerPond) {
      AppLogger.error(
        'Excessive feed calculation detected for pond $pondId: $calculatedFeed kg',
        {
          'pond_id': pondId,
          'calculated_feed': calculatedFeed,
          'multiplier': multiplier,
          'base_feed': baseFeed,
          'calculation_type': calculationType,
        }
      );
      
      return FeedSafetyResult(
        originalAmount: calculatedFeed,
        safeAmount: _maxFeedPerPond,
        wasClamped: true,
        reason: 'Feed amount exceeds maximum safe limit',
      );
    }

    // Check for NaN or infinite values
    if (calculatedFeed.isNaN || calculatedFeed.isInfinite) {
      AppLogger.error(
        'Invalid feed calculation detected for pond $pondId: $calculatedFeed',
        {
          'pond_id': pondId,
          'calculated_feed': calculatedFeed,
          'multiplier': multiplier,
          'base_feed': baseFeed,
          'calculation_type': calculationType,
        }
      );
      
      return FeedSafetyResult(
        originalAmount: calculatedFeed,
        safeAmount: 0.0,
        wasClamped: true,
        reason: 'Invalid feed calculation (NaN or infinite)',
      );
    }

    final safeAmount = clampFeedAmount(calculatedFeed, pondId);
    
    return FeedSafetyResult(
      originalAmount: calculatedFeed,
      safeAmount: safeAmount,
      wasClamped: safeAmount != calculatedFeed,
      reason: safeAmount != calculatedFeed ? 'Feed amount clamped to safe range' : null,
    );
  }

  /// Validate feed plan for multiple ponds
  Map<String, FeedSafetyResult> validateFeedPlan(
    Map<String, double> feedPlan, {
    Map<String, double>? multipliers,
    Map<String, double>? baseFeeds,
  }) {
    final results = <String, FeedSafetyResult>{};
    
    for (final entry in feedPlan.entries) {
      final pondId = entry.key;
      final calculatedFeed = entry.value;
      
      results[pondId] = validateFeedCalculation(
        calculatedFeed: calculatedFeed,
        pondId: pondId,
        multiplier: multipliers?[pondId],
        baseFeed: baseFeeds?[pondId],
        calculationType: 'feed_plan',
      );
    }
    
    // Log summary of clamping
    final clampedCount = results.values.where((r) => r.wasClamped).length;
    if (clampedCount > 0) {
      AppLogger.warn(
        'Feed safety clamped $clampedCount out of ${feedPlan.length} pond feed calculations'
      );
    }
    
    return results;
  }

  /// Get safe default feed amount for a pond
  double getSafeDefaultFeed(double pondAreaInSqM) {
    // Default calculation: 0.1 kg per square meter (safe baseline)
    final defaultFeed = pondAreaInSqM * 0.1;
    return clampFeedAmount(defaultFeed, 'default');
  }

  /// Check if feed amount is within safe range
  bool isFeedSafe(double feedAmount) {
    return feedAmount >= _minFeedPerPond && 
           feedAmount <= _maxFeedPerPond && 
           !feedAmount.isNaN && 
           !feedAmount.isInfinite;
  }
}

class FeedSafetyResult {
  final double originalAmount;
  final double safeAmount;
  final bool wasClamped;
  final String? reason;

  FeedSafetyResult({
    required this.originalAmount,
    required this.safeAmount,
    required this.wasClamped,
    this.reason,
  });

  @override
  String toString() {
    return 'FeedSafetyResult(original: $originalAmount, safe: $safeAmount, clamped: $wasClamped, reason: $reason)';
  }
}
