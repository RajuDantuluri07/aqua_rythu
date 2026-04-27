// Feed Pipeline - Daily feed engine orchestrator
//
// This service orchestrates the complete feed calculation pipeline:
// 1. Calculate baseline feed
// 2. Apply smart adjustments
// 3. Calculate ROI and savings
// 4. Determine confidence level
// 5. Generate explanation
// 6. Save to database
//
// Provides a single entry point for daily feed calculations.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import 'baseline_calculator.dart';
import 'smart_feed_service.dart';
import 'roi_calculator.dart';
import 'confidence_service.dart';
import 'reason_builder.dart';

/// Feed Pipeline - Main orchestrator for daily feed calculations
///
/// Coordinates all feed engine components to produce complete
/// feed recommendations with ROI tracking and explanations
class FeedPipeline {
  static const String version = '1.0.0';

  /// Run daily feed engine for a pond
  ///
  /// [pond] Pond data model with required fields
  ///
  /// Returns complete feed calculation result
  static Future<FeedPipelineResult> runDailyFeedEngine(PondData pond) async {
    AppLogger.info(
      'FeedPipeline: starting daily feed engine',
      {
        'pondId': pond.id,
        'doc': pond.doc,
        'shrimpCount': pond.shrimpCount,
      },
    );

    try {
      final validation = validatePondData(pond);
      if (!validation.isValid) {
        return FeedPipelineResult.error(
          pondId: pond.id,
          doc: pond.doc,
          error: validation.errors.join('; '),
        );
      }

      // Step 1: Calculate baseline feed
      final double baselineFeed = BaselineCalculator.calculateBaselineFeed(
        doc: pond.doc,
        shrimpCount: pond.shrimpCount,
        sampledAbw: pond.sampledAbw,
        survivalRate: pond.survivalRate,
      );

      // Step 2: Apply smart adjustments
      final double actualFeed = SmartFeedService.applySmartAdjustments(
        baselineFeed: baselineFeed,
        trayFactor: pond.trayFactor,
        growthFactor: pond.growthFactor,
        fcrFactor: pond.fcrFactor,
      );

      // Step 3: Calculate ROI and savings
      final double dailySavings = RoiCalculator.calculateDailySavings(
        baselineFeed: baselineFeed,
        actualFeed: actualFeed,
        feedCost: pond.feedCostPerKg,
      );

      // Step 4: Get previous cumulative savings
      final double previousTotal = await _getPreviousCumulativeSavings(pond.id);

      // Step 5: Update cumulative savings
      final double cumulativeSavings = RoiCalculator.updateCumulativeSavings(
        previousTotal: previousTotal,
        todaySavings: dailySavings,
      );

      // Step 6: Determine confidence level
      final String confidence = ConfidenceService.getConfidence(
        hasTrayData: pond.hasTrayData,
        hasSampling: pond.hasSampling,
        hasWaterQuality: pond.hasWaterQuality,
        dataRecencyHours: pond.dataRecencyHours,
        trayConsistency: pond.trayConsistency,
      );

      // Calculate metrics for zero-data fallback
      final double pondAbw =
          pond.sampledAbw ?? BaselineCalculator.estimateAbwFromDoc(pond.doc);
      final double pondBiomass = BaselineCalculator.calculateBiomass(
        shrimpCount: pond.shrimpCount,
        abw: pondAbw,
        survivalRate: pond.survivalRate,
      );
      final double pondFeedRate =
          BaselineCalculator.getFeedRate(pond.doc, pondAbw);

      // Step 6.5: Zero-data fallback (CRITICAL TRUST FIX)
      if (!pond.hasTrayData && !pond.hasSampling) {
        final result = FeedPipelineResult(
          pondId: pond.id,
          doc: pond.doc,
          baselineFeed: baselineFeed,
          actualFeed: baselineFeed, // No adjustments
          dailySavings: 0.0, // No savings
          cumulativeSavings: previousTotal,
          confidence: 'low',
          reason:
              'Insufficient data → Standard optimization applied (Limited data - conservative approach)',
          action: _buildAction(baselineFeed),
          abw: pondAbw,
          biomass: pondBiomass,
          feedRate: pondFeedRate,
          feedCostPerKg: pond.feedCostPerKg,
          timestamp: DateTime.now(),
        );

        AppLogger.info(
          'FeedPipeline: zero-data fallback applied',
          {
            'pondId': pond.id,
            'confidence': 'low',
            'reason': 'Insufficient data for smart adjustments',
          },
        );

        return result;
      }

      // Step 7: Generate explanation
      final String reason = ReasonBuilder.buildReason(
        trayLeftover: pond.trayLeftover,
        growthSlow: pond.growthSlow,
        fcrHigh: pond.fcrHigh,
        waterQualityPoor: pond.waterQualityPoor,
        confidenceLevel: confidence,
      );

      // Step 8: Build clear action output (VERY IMPORTANT)
      final String action = _buildAction(actualFeed);

      // Step 9: Create result
      final result = FeedPipelineResult(
        pondId: pond.id,
        doc: pond.doc,
        baselineFeed: baselineFeed,
        actualFeed: actualFeed,
        dailySavings: dailySavings,
        cumulativeSavings: cumulativeSavings,
        confidence: confidence,
        reason: reason,
        action: action,
        abw: pondAbw,
        biomass: pondBiomass,
        feedRate: pondFeedRate,
        feedCostPerKg: pond.feedCostPerKg,
        timestamp: DateTime.now(),
      );

      // Step 10: Save to database
      final saved = await saveToDatabase(result);

      if (!saved) {
        AppLogger.warn(
          'FeedPipeline: failed to save result to database',
          {'pondId': pond.id, 'error': 'Database save failed'},
        );
      }

      AppLogger.info(
        'FeedPipeline: daily feed engine completed',
        {
          'pondId': pond.id,
          'baselineFeed': baselineFeed,
          'actualFeed': actualFeed,
          'dailySavings': dailySavings,
          'cumulativeSavings': cumulativeSavings,
          'confidence': confidence,
          'reason': reason,
          'action': action,
        },
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        'FeedPipeline: error in daily feed engine',
        e.toString(),
        stackTrace,
      );

      // Return error result
      return FeedPipelineResult.error(
        pondId: pond.id,
        doc: pond.doc,
        error: e.toString(),
      );
    }
  }

  /// Save feed calculation result to database
  ///
  /// [result] Feed calculation result to save
  ///
  /// Returns success status
  static Future<bool> saveToDatabase(FeedPipelineResult result) async {
    if (result.isError) {
      AppLogger.error('FeedPipeline: cannot save error result to database');
      return false;
    }

    try {
      final supabase = Supabase.instance.client;

      final insertData = {
        'pond_id': result.pondId,
        'feed_date':
            result.timestamp.toIso8601String().split('T')[0], // Date only
        'baseline_feed_kg': result.baselineFeed,
        'actual_feed_kg': result.actualFeed,
        'feed_cost_per_kg': result.feedCostPerKg,
        'daily_savings_rs': result.dailySavings,
        'cumulative_savings_rs': result.cumulativeSavings,
        'abw': result.abw,
        'biomass': result.biomass,
        'feed_rate': result.feedRate,
        'confidence_level': result.confidence,
        'reason': result.reason,
      };

      final response = await supabase
          .from('pond_daily_feed')
          .upsert(insertData, onConflict: 'pond_id,feed_date')
          .select();

      AppLogger.info(
        'FeedPipeline: result saved to database',
        {'response': response},
      );

      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'FeedPipeline: error saving to database',
        e.toString(),
        stackTrace,
      );
      return false;
    }
  }

  /// Get previous cumulative savings for a pond
  ///
  /// [pondId] Pond identifier
  ///
  /// Returns previous cumulative savings amount
  static Future<double> _getPreviousCumulativeSavings(String pondId) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('pond_daily_feed')
          .select('cumulative_savings_rs')
          .eq('pond_id', pondId)
          .order('feed_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return 0.0; // No previous records
      }

      final double previousTotal =
          (response['cumulative_savings_rs'] as num?)?.toDouble() ?? 0.0;

      AppLogger.info(
        'FeedPipeline: previous cumulative savings retrieved',
        {
          'pondId': pondId,
          'previousTotal': previousTotal,
        },
      );

      return previousTotal;
    } catch (e, stackTrace) {
      AppLogger.error(
        'FeedPipeline: error getting previous cumulative savings',
        e.toString(),
        stackTrace,
      );
      return 0.0; // Default to 0 on error
    }
  }

  /// Run complete pipeline and save to database
  ///
  /// [pond] Pond data model
  ///
  /// Returns success status and result
  static Future<FeedPipelineResponse> runAndSave(PondData pond) async {
    // Run the pipeline
    final result = await runDailyFeedEngine(pond);

    if (result.isError) {
      return FeedPipelineResponse(
        success: false,
        result: result,
        error: result.error,
      );
    }

    // Save to database
    final bool saved = await saveToDatabase(result);

    return FeedPipelineResponse(
      success: saved,
      result: result,
      error: saved ? null : 'Failed to save to database',
    );
  }

  /// Build clear action output (VERY IMPORTANT)
  ///
  /// [feedKg] Feed amount in kilograms
  ///
  /// Returns clear action string for farmers
  static String _buildAction(double feedKg) {
    return "Feed ${feedKg.toStringAsFixed(1)} kg today in 3–4 rounds";
  }

  /// Get feed calculation history for a pond
  ///
  /// [pondId] Pond identifier
  /// [days] Number of days to retrieve
  ///
  /// Returns list of historical results
  static Future<List<FeedPipelineResult>> getFeedHistory({
    required String pondId,
    int days = 30,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('pond_daily_feed')
          .select('*')
          .eq('pond_id', pondId)
          .order('feed_date', ascending: false)
          .limit(days);

      final List<FeedPipelineResult> results = [];

      for (final record in response) {
        results.add(FeedPipelineResult.fromDatabase(record));
      }

      return results;
    } catch (e, stackTrace) {
      AppLogger.error(
        'FeedPipeline: error getting feed history',
        e.toString(),
        stackTrace,
      );
      return [];
    }
  }

  /// Validate pond data for pipeline execution
  ///
  /// [pond] Pond data model
  ///
  /// Returns validation result
  static FeedPipelineValidation validatePondData(PondData pond) {
    final List<String> errors = [];

    if (pond.id.isEmpty) {
      errors.add('Pond ID is required');
    }

    if (pond.doc <= 0) {
      errors.add('DOC must be positive');
    }

    if (pond.shrimpCount <= 0) {
      errors.add('Shrimp count must be positive');
    }

    if (pond.survivalRate <= 0 || pond.survivalRate > 1.0) {
      errors.add('Survival rate must be between 0 and 1');
    }

    if (pond.feedCostPerKg <= 0) {
      errors.add('Feed cost per kg must be positive');
    }

    return FeedPipelineValidation(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// Pond data model for feed pipeline
class PondData {
  final String id;
  final int doc;
  final int shrimpCount;
  final double? sampledAbw;
  final double survivalRate;
  final double feedCostPerKg;

  // Adjustment factors
  final double trayFactor;
  final double growthFactor;
  final double fcrFactor;

  // Data quality indicators
  final bool hasTrayData;
  final bool hasSampling;
  final bool hasWaterQuality;
  final int dataRecencyHours;
  final double trayConsistency;

  // Decision factors
  final bool trayLeftover;
  final bool growthSlow;
  final bool fcrHigh;
  final bool waterQualityPoor;

  const PondData({
    required this.id,
    required this.doc,
    required this.shrimpCount,
    this.sampledAbw,
    required this.survivalRate,
    required this.feedCostPerKg,
    this.trayFactor = 1.0,
    this.growthFactor = 1.0,
    this.fcrFactor = 1.0,
    this.hasTrayData = false,
    this.hasSampling = false,
    this.hasWaterQuality = false,
    this.dataRecencyHours = 0,
    this.trayConsistency = 1.0,
    this.trayLeftover = false,
    this.growthSlow = false,
    this.fcrHigh = false,
    this.waterQualityPoor = false,
  });
}

/// Feed pipeline result
class FeedPipelineResult {
  final String pondId;
  final int doc;
  final double baselineFeed;
  final double actualFeed;
  final double dailySavings;
  final double cumulativeSavings;
  final String confidence;
  final String reason;
  final String action;
  final double abw;
  final double biomass;
  final double feedRate;
  final double feedCostPerKg;
  final DateTime timestamp;
  final String? error;
  final bool isError;

  const FeedPipelineResult({
    required this.pondId,
    required this.doc,
    required this.baselineFeed,
    required this.actualFeed,
    required this.dailySavings,
    required this.cumulativeSavings,
    required this.confidence,
    required this.reason,
    required this.action,
    required this.abw,
    required this.biomass,
    required this.feedRate,
    required this.feedCostPerKg,
    required this.timestamp,
    this.error,
  }) : isError = error != null;

  FeedPipelineResult.error({
    required this.pondId,
    required this.doc,
    required this.error,
  })  : isError = true,
        baselineFeed = 0.0,
        actualFeed = 0.0,
        dailySavings = 0.0,
        cumulativeSavings = 0.0,
        confidence = 'low',
        reason = '',
        abw = 0.0,
        biomass = 0.0,
        feedRate = 0.0,
        feedCostPerKg = 0.0,
        timestamp = DateTime.now(),
        action = 'Feed 0.0 kg today in 3–4 rounds';

  /// Create result from database record
  factory FeedPipelineResult.fromDatabase(Map<String, dynamic> record) {
    return FeedPipelineResult(
      pondId: record['pond_id'] as String,
      doc: record['doc'] as int? ?? 0,
      baselineFeed: (record['baseline_feed_kg'] as num?)?.toDouble() ?? 0.0,
      actualFeed: (record['actual_feed_kg'] as num?)?.toDouble() ?? 0.0,
      dailySavings: (record['daily_savings_rs'] as num?)?.toDouble() ?? 0.0,
      cumulativeSavings:
          (record['cumulative_savings_rs'] as num?)?.toDouble() ?? 0.0,
      confidence: record['confidence_level'] as String? ?? 'low',
      reason: record['reason'] as String? ?? '',
      action: record['action'] as String? ?? '',
      abw: (record['abw'] as num?)?.toDouble() ?? 0.0,
      biomass: (record['biomass'] as num?)?.toDouble() ?? 0.0,
      feedRate: (record['feed_rate'] as num?)?.toDouble() ?? 0.0,
      feedCostPerKg: (record['feed_cost_per_kg'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(record['created_at'] as String),
    );
  }

  /// Convert to JSON for API responses (matches UI contract)
  Map<String, dynamic> toJson() {
    if (isError) {
      return {
        'error': error,
        'pondId': pondId,
        'doc': doc,
      };
    }

    return {
      'baseline_feed': baselineFeed,
      'actual_feed': actualFeed,
      'daily_savings': dailySavings,
      'total_savings': cumulativeSavings,
      'confidence': confidence,
      'reason': reason,
      'action': action,
      'abw': abw,
      'biomass': biomass,
      'feed_rate': feedRate,
      'feed_cost_per_kg': feedCostPerKg,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Feed pipeline response
class FeedPipelineResponse {
  final bool success;
  final FeedPipelineResult result;
  final String? error;

  const FeedPipelineResponse({
    required this.success,
    required this.result,
    this.error,
  });
}

/// Feed pipeline validation
class FeedPipelineValidation {
  final bool isValid;
  final List<String> errors;

  const FeedPipelineValidation({
    required this.isValid,
    required this.errors,
  });
}
