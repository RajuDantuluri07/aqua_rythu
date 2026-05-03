/// Config-driven adjustment factors for each tray status.
/// Positive = increase feed, negative = decrease feed.
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

  static const TrayFactorConfig defaultConfig = TrayFactorConfig(
    empty: 0.15,   // +15% — trays fully eaten, increase feed
    light: 0.0,    //   0% — optimal, no change
    medium: -0.10, // -10% — some leftover, reduce slightly
    heavy: -0.20,  // -20% — excess leftover, reduce significantly
  );
}
