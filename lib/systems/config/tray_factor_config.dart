/// Configuration for tray-based feed adjustment factors.
///
/// This class allows tunable factors for different tray statuses.
/// All factors are decimal adjustments to be applied to feed amounts:
/// - Positive values increase feed
/// - Negative values decrease feed
/// - Zero means no adjustment
class TrayFactorConfig {
  /// Adjustment factor for empty trays (feed fully consumed)
  final double empty;

  /// Adjustment factor for light leftover trays
  final double light;

  /// Adjustment factor for medium leftover trays
  final double medium;

  /// Adjustment factor for heavy leftover trays (excess feed)
  final double heavy;

  const TrayFactorConfig({
    required this.empty,
    required this.light,
    required this.medium,
    required this.heavy,
  });

  /// Default configuration with conservative adjustments
  static const TrayFactorConfig defaultConfig = TrayFactorConfig(
    empty: 0.15, // +15% increase for empty trays
    light: 0.0, // No change for light leftover
    medium: -0.10, // -10% reduction for medium leftover
    heavy: -0.25, // -25% reduction for heavy leftover
  );

  /// Aggressive configuration for higher feed optimization
  static const TrayFactorConfig aggressive = TrayFactorConfig(
    empty: 0.20, // +20% increase for empty trays
    light: 0.05, // +5% increase for light leftover
    medium: -0.15, // -15% reduction for medium leftover
    heavy: -0.35, // -35% reduction for heavy leftover
  );

  /// Conservative configuration with minimal adjustments
  static const TrayFactorConfig conservative = TrayFactorConfig(
    empty: 0.10, // +10% increase for empty trays
    light: 0.0, // No change for light leftover
    medium: -0.05, // -5% reduction for medium leftover
    heavy: -0.20, // -20% reduction for heavy leftover
  );

  /// Create a copy with specific values overridden
  TrayFactorConfig copyWith({
    double? empty,
    double? light,
    double? medium,
    double? heavy,
  }) {
    return TrayFactorConfig(
      empty: empty ?? this.empty,
      light: light ?? this.light,
      medium: medium ?? this.medium,
      heavy: heavy ?? this.heavy,
    );
  }

  @override
  String toString() {
    return 'TrayFactorConfig(empty: $empty, light: $light, medium: $medium, heavy: $heavy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrayFactorConfig &&
        other.empty == empty &&
        other.light == light &&
        other.medium == medium &&
        other.heavy == heavy;
  }

  @override
  int get hashCode {
    return empty.hashCode ^ light.hashCode ^ medium.hashCode ^ heavy.hashCode;
  }
}
