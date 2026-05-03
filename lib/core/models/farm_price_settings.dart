class FarmPriceSettings {
  final double? feedPricePerKg;
  final double? sellPricePerKg;

  const FarmPriceSettings({this.feedPricePerKg, this.sellPricePerKg});

  bool get isConfigured => feedPricePerKg != null && sellPricePerKg != null;

  FarmPriceSettings copyWith({double? feedPricePerKg, double? sellPricePerKg}) {
    return FarmPriceSettings(
      feedPricePerKg: feedPricePerKg ?? this.feedPricePerKg,
      sellPricePerKg: sellPricePerKg ?? this.sellPricePerKg,
    );
  }
}
