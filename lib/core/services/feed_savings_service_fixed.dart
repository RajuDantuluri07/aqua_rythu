import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'app_config_service.dart';
import 'tray_service.dart';
import 'pond_service.dart';

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

      // Get tray logs count and sampling availability
      final trayLogsCount = await _getTrayLogsCount(pondId);
      final samplingAvailable = await _hasSamplingData(pondId);

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
          displayMessage: moneySaved > 0
              ? 'You saved ₹${_formatCurrency(moneySaved)} in feed so far'
              : null,
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
      // Aggregate tray logs and sampling data across all ponds
      int totalTrayLogs = 0;
      bool anySamplingAvailable = false;

      for (final pondId in pondIds) {
        totalTrayLogs += await _getTrayLogsCount(pondId);
        if (await _hasSamplingData(pondId)) {
          anySamplingAvailable = true;
        }
      }

      // Confidence gate
      final hasEnoughData =
          (avgDoc >= 20) && (totalTrayLogs >= 3 || anySamplingAvailable);

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
          displayMessage: moneySaved > 0
              ? 'You saved ₹${_formatCurrency(moneySaved)} in feed so far'
              : null,
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

      final data = response;
      return data.length;
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

      final data = response;
      return data.isNotEmpty;
    } catch (e) {
      AppLogger.error('Failed to check sampling data for pond=$pondId', e);
      return false;
    }
  }
}

// Provider instance
final feedSavingsServiceProvider = Provider<FeedSavingsService>((ref) {
  return FeedSavingsService(Supabase.instance.client);
});
