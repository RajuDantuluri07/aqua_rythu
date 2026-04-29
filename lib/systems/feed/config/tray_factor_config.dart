/// Configuration for tray-based feed adjustment factors.
/// 
/// This class provides a single source of truth for tray factor values,
/// making them tunable without code changes.
/// 
/// Future: Load from Supabase/remote config for farm-specific calibration.
class TrayFactorConfig {
  final double empty;
  final double light;
  final double medium;
  final double heavy;

  const TrayFactorConfig({
    required this.empty,
    required this.light,
    required this.medium,
    required this.heavy,
  });

  /// Default configuration (V1)
  /// 
  /// Factors represent percentage adjustment to feed:
  /// - empty: +15% (increase feed)
  /// - light: 0% (no change, ideal state)
  /// - medium: -20% (reduce slightly)
  /// - heavy: -35% (reduce strongly)
  static const TrayFactorConfig defaultConfig = TrayFactorConfig(
    empty: 0.15,
    light: 0.0,
    medium: -0.20,
    heavy: -0.35,
  );

  /// Validate that all factors are within reasonable bounds
  bool get isValid {
    return empty >= -1.0 &&
        empty <= 1.0 &&
        light >= -1.0 &&
        light <= 1.0 &&
        medium >= -1.0 &&
        medium <= 1.0 &&
        heavy >= -1.0 &&
        heavy <= 1.0;
  }
}
