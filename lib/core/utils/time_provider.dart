class TimeProvider {
  static DateTime Function() _now = DateTime.now;

  static DateTime now() => _now();

  /// Override the time source for tests.
  static set nowOverride(DateTime Function() override) {
    _now = override;
  }

  /// Restore the default time source.
  static void reset() {
    _now = DateTime.now;
  }
}
