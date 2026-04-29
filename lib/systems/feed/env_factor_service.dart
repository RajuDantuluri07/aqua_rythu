class EnvFactorService {
  static const double _criticalDoThreshold = 3.5;
  static const double _warningDoThreshold = 4.5;

  double getEnvFactor({
    required bool isRaining,
    required double temperature,
    required double dissolvedOxygen,
    required bool phFluctuation,
  }) {
    final safeDo = _safeValue(dissolvedOxygen);
    final safeTemperature = _safeValue(temperature);

    if (safeDo != null && safeDo < _criticalDoThreshold) return 0.0;
    if (safeTemperature != null &&
        (safeTemperature < 22 || safeTemperature > 36)) {
      return 0.0;
    }

    var factor = 1.0;
    if (isRaining) factor = 0.5;
    if (safeDo != null && safeDo < _warningDoThreshold) factor = 0.5;
    if (safeTemperature != null &&
        (safeTemperature < 24 || safeTemperature > 34)) {
      factor = 0.5;
    }
    if (phFluctuation) factor = 0.5;

    return factor;
  }

  List<String> getEnvReasons({
    required bool isRaining,
    required double temperature,
    required double dissolvedOxygen,
    required bool phFluctuation,
  }) {
    final reasons = <String>[];
    final safeDo = _safeValue(dissolvedOxygen);
    final safeTemperature = _safeValue(temperature);

    if (safeDo != null && safeDo < _criticalDoThreshold) {
      reasons.add('low DO');
    } else if (safeDo != null && safeDo < _warningDoThreshold) {
      reasons.add('low DO');
    }

    if (safeTemperature != null) {
      if (safeTemperature > 36) {
        reasons.add('critical high temperature');
      } else if (safeTemperature < 22) {
        reasons.add('critical low temperature');
      } else if (safeTemperature > 34) {
        reasons.add('high temperature');
      } else if (safeTemperature < 24) {
        reasons.add('low temperature');
      }
    }

    if (isRaining) reasons.add('rain');
    if (phFluctuation) reasons.add('pH fluctuation');

    return reasons;
  }

  double? _safeValue(double value) {
    if (value.isNaN || value.isInfinite) return null;
    return value;
  }
}
