import '../../../features/tray/enums/tray_status.dart';
import '../config/tray_factor_config.dart';

/// Central service for tray-based feed adjustment factors.
///
/// This is the single entry point for all tray factor calculations.
/// Uses config-driven factors for tunability.
class TrayFactorService {
  final TrayFactorConfig config;

  TrayFactorService([this.config = TrayFactorConfig.defaultConfig]);

  /// Get the adjustment factor for a single tray status.
  ///
  /// Returns a decimal factor representing the percentage adjustment:
  /// - 0.15 → +15% increase
  /// - 0.0 → no change
  /// - -0.20 → -20% decrease
  double getFactor(TrayStatus status) {
    switch (status) {
      case TrayStatus.empty:
        return config.empty;
      case TrayStatus.light:
        return config.light;
      case TrayStatus.medium:
        return config.medium;
      case TrayStatus.heavy:
        return config.heavy;
    }
  }

  /// Get the average adjustment factor from multiple tray statuses.
  ///
  /// Useful when aggregating multiple tray observations.
  /// Returns null if the list is empty.
  double? getAverageFactor(List<TrayStatus> trayStatuses) {
    if (trayStatuses.isEmpty) return null;

    final total = trayStatuses.fold<double>(0.0, (sum, status) {
      return sum + getFactor(status);
    });

    return total / trayStatuses.length;
  }

  /// Calculate leftover percentage from tray statuses (legacy compatibility).
  ///
  /// This method provides backward compatibility with the old percentage-based system.
  /// New code should prefer using getFactor() directly.
  double? getLeftoverPercentFromStatuses(List<TrayStatus> trayStatuses) {
    if (trayStatuses.isEmpty) return null;

    final total = trayStatuses.fold<double>(0.0, (sum, status) {
      switch (status) {
        case TrayStatus.empty:
          return sum; // 0%
        case TrayStatus.light:
          return sum + 15.0; // ~15%
        case TrayStatus.medium:
          return sum + 40.0; // ~40%
        case TrayStatus.heavy:
          return sum + 70.0; // ~70%
      }
    });

    return total / trayStatuses.length;
  }

  /// Get human-readable reason for tray-based adjustment.
  String getTrayReason(TrayStatus status) {
    switch (status) {
      case TrayStatus.empty:
        return 'Trays empty - increasing feed';
      case TrayStatus.light:
        return 'Optimal feed level';
      case TrayStatus.medium:
        return 'Some feed remaining - reducing slightly';
      case TrayStatus.heavy:
        return 'Excess feed remaining - reducing significantly';
    }
  }

  /// Validate that a tray status is not null.
  ///
  /// Throws an exception if status is null.
  void validateTrayStatus(TrayStatus? status) {
    if (status == null) {
      throw Exception('Tray status is required');
    }
  }
}
