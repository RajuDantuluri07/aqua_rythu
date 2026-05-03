import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';

/// Feed savings result for a pond
class FeedSavingsResult {
  final double moneySaved;
  final double feedSavedKg;
  final bool hasEnoughData;
  final String? displayMessage;
  final SavingsDisplayType displayType;

  const FeedSavingsResult({
    required this.moneySaved,
    required this.feedSavedKg,
    required this.hasEnoughData,
    this.displayMessage,
    required this.displayType,
  });
}

enum SavingsDisplayType {
  showSavings,
  partialData,
  noData,
  hide,
}

/// Feed Savings calculation service
/// Calculates money saved through optimized feeding vs baseline FCR
class FeedSavingsService {
  final SupabaseClient _supabase;
  static const double _baselineFCR = 1.6;

  FeedSavingsService(this._supabase);

  /// Calculate feed savings for a single pond
  Future<FeedSavingsResult> calculatePondSavings({
    required String pondId,
    required double totalFeedGivenKg,
    required double currentBiomassKg,
    required int doc,
    required double feedPricePerKg,
  }) async {
    try {
      // Edge case: No feed data
      if (totalFeedGivenKg == 0) {
        return const FeedSavingsResult(
          moneySaved: 0,
          feedSavedKg: 0,
          hasEnoughData: false,
          displayMessage: 'No feed data logged yet',
          displayType: SavingsDisplayType.noData,
        );
      }

      // Edge case: Before DOC 15 - don't show
      if (doc < 15) {
        return const FeedSavingsResult(
          moneySaved: 0,
          feedSavedKg: 0,
          hasEnoughData: false,
          displayType: SavingsDisplayType.hide,
        );
      }

      // Get tray logs count and sampling availability in parallel
      final results = await Future.wait([
        _getTrayLogsCount(pondId),
        _hasSamplingData(pondId),
      ]);
      final trayLogsCount = results[0] as int;
      final samplingAvailable = results[1] as bool;

      // Confidence gate
      final hasEnoughData =
          (doc >= 20) && (trayLogsCount >= 3 || samplingAvailable);

      // Calculate savings
      final expectedFeed = currentBiomassKg * _baselineFCR;
      final actualFeed = totalFeedGivenKg;
      double feedSavedKg = expectedFeed - actualFeed;

      // Never show negative savings
      if (feedSavedKg < 0) feedSavedKg = 0;

      final moneySaved = feedSavedKg * feedPricePerKg;

      // Determine display logic
      if (hasEnoughData && moneySaved > 0) {
        return FeedSavingsResult(
          moneySaved: moneySaved,
          feedSavedKg: feedSavedKg,
          hasEnoughData: true,
          displayMessage:
              'You saved ₹${_formatCurrency(moneySaved)} in feed so far',
          displayType: SavingsDisplayType.showSavings,
        );
      } else if (doc >= 15 && !hasEnoughData) {
        return const FeedSavingsResult(
          moneySaved: 0,
          feedSavedKg: 0,
          hasEnoughData: false,
          displayMessage: 'Start using trays to track savings',
          displayType: SavingsDisplayType.partialData,
        );
      } else {
        return FeedSavingsResult(
          moneySaved: moneySaved,
          feedSavedKg: feedSavedKg,
          hasEnoughData: hasEnoughData,
          displayType: moneySaved > 0
              ? SavingsDisplayType.showSavings
              : SavingsDisplayType.hide,
        );
      }
    } catch (e) {
      AppLogger.error(
          'FeedSavingsService.calculatePondSavings failed for pond=$pondId', e);
      return const FeedSavingsResult(
        moneySaved: 0,
        feedSavedKg: 0,
        hasEnoughData: false,
        displayType: SavingsDisplayType.hide,
      );
    }
  }

  /// Calculate aggregate feed savings for multiple ponds
  Future<FeedSavingsResult> calculateFarmSavings({
    required List<String> pondIds,
    required double totalFeedGivenKg,
    required double totalBiomassKg,
    required int avgDoc,
    required double feedPricePerKg,
  }) async {
    if (pondIds.isEmpty) {
      return const FeedSavingsResult(
        moneySaved: 0,
        feedSavedKg: 0,
        hasEnoughData: false,
        displayMessage: 'No ponds available',
        displayType: SavingsDisplayType.noData,
      );
    }

    try {
      // Aggregate tray logs and sampling availability across all ponds in parallel
      final results = await Future.wait([
        _getTotalTrayLogsCountForPonds(pondIds),
        _hasAnySamplingDataForPonds(pondIds),
      ]);
      final totalTrayLogs = results[0] as int;
      final anySamplingAvailable = results[1] as bool;

      // Confidence gate
      final hasEnoughData =
          (avgDoc >= 20) && (totalTrayLogs >= 3 || anySamplingAvailable);

      // Edge case: No feed data
      if (totalFeedGivenKg == 0) {
        return const FeedSavingsResult(
          moneySaved: 0,
          feedSavedKg: 0,
          hasEnoughData: false,
          displayMessage: 'No feed data logged yet',
          displayType: SavingsDisplayType.noData,
        );
      }

      // Edge case: Before DOC 15 - don't show
      if (avgDoc < 15) {
        return const FeedSavingsResult(
          moneySaved: 0,
          feedSavedKg: 0,
          hasEnoughData: false,
          displayType: SavingsDisplayType.hide,
        );
      }

      // Calculate savings
      final expectedFeed = totalBiomassKg * _baselineFCR;
      final actualFeed = totalFeedGivenKg;
      double feedSavedKg = expectedFeed - actualFeed;

      // Never show negative savings
      if (feedSavedKg < 0) feedSavedKg = 0;

      final moneySaved = feedSavedKg * feedPricePerKg;

      // Determine display logic
      if (hasEnoughData && moneySaved > 0) {
        return FeedSavingsResult(
          moneySaved: moneySaved,
          feedSavedKg: feedSavedKg,
          hasEnoughData: true,
          displayMessage:
              'You saved ₹${_formatCurrency(moneySaved)} in feed so far',
          displayType: SavingsDisplayType.showSavings,
        );
      } else if (avgDoc >= 15 && !hasEnoughData) {
        return const FeedSavingsResult(
          moneySaved: 0,
          feedSavedKg: 0,
          hasEnoughData: false,
          displayMessage: 'Start using trays to track savings',
          displayType: SavingsDisplayType.partialData,
        );
      } else {
        return FeedSavingsResult(
          moneySaved: moneySaved,
          feedSavedKg: feedSavedKg,
          hasEnoughData: hasEnoughData,
          displayType: moneySaved > 0
              ? SavingsDisplayType.showSavings
              : SavingsDisplayType.hide,
        );
      }
    } catch (e) {
      AppLogger.error('FeedSavingsService.calculateFarmSavings failed', e);
      return const FeedSavingsResult(
        moneySaved: 0,
        feedSavedKg: 0,
        hasEnoughData: false,
        displayType: SavingsDisplayType.hide,
      );
    }
  }

  /// Get savings color based on amount
  static String getSavingsColor(double moneySaved) {
    if (moneySaved >= 5000) return '#16A34A'; // strong green
    if (moneySaved >= 2000) return '#22C55E'; // medium green
    if (moneySaved >= 500) return '#4ADE80'; // light green
    return '#86EFAC'; // subtle green
  }

  /// Get savings value range for analytics
  static String getSavingsValueRange(double moneySaved) {
    if (moneySaved < 500) return '<500';
    if (moneySaved < 2000) return '500-2k';
    return '2k+';
  }

  /// Format currency for display
  static String _formatCurrency(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.round().toString();
  }

  /// Get tray logs count for a pond
  Future<int> _getTrayLogsCount(String pondId) async {
    try {
      final response = await _supabase
          .from('tray_logs')
          .select('id')
          .eq('pond_id', pondId)
          .neq('tray_statuses', '["skipped"]'); // Exclude skipped trays

      return response.length;
    } catch (e) {
      AppLogger.error('Failed to get tray logs count for pond=$pondId', e);
      return 0;
    }
  }

  /// Check if pond has sampling data
  Future<bool> _hasSamplingData(String pondId) async {
    try {
      final response = await _supabase
          .from('samplings')
          .select('id')
          .eq('pond_id', pondId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      AppLogger.error('Failed to check sampling data for pond=$pondId', e);
      return false;
    }
  }

  /// Get total tray logs count for multiple ponds in one query
  Future<int> _getTotalTrayLogsCountForPonds(List<String> pondIds) async {
    try {
      final response = await _supabase
          .from('tray_logs')
          .select('id')
          .inFilter('pond_id', pondIds)
          .neq('tray_statuses', '["skipped"]');

      return response.length;
    } catch (e) {
      AppLogger.error('Failed to get aggregate tray logs count', e);
      return 0;
    }
  }

  /// Check if any of the ponds have sampling data in one query
  Future<bool> _hasAnySamplingDataForPonds(List<String> pondIds) async {
    try {
      final response = await _supabase
          .from('samplings')
          .select('id')
          .inFilter('pond_id', pondIds)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      AppLogger.error('Failed to check aggregate sampling data', e);
      return false;
    }
  }
}

// Provider instance
final feedSavingsServiceProvider = Provider<FeedSavingsService>((ref) {
  return FeedSavingsService(Supabase.instance.client);
});
