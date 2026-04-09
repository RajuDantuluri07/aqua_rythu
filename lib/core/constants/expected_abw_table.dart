/// Static DOC → expected ABW (grams) lookup table.
///
/// Used by the sampling factor computation to determine whether a pond's
/// actual body weight is ahead of, on-track with, or behind schedule.
/// Values are calibrated for L. vannamei under standard stocking density.
const Map<int, double> expectedAbwTable = {
  1: 0.01,
  5: 0.05,
  10: 0.20,
  15: 0.60,
  20: 1.50,
  25: 3.00,
  30: 5.00,
  35: 7.50,
  40: 10.00,
  45: 13.00,
  50: 16.00,
  60: 22.00,
  70: 30.00,
  80: 38.00,
  90: 45.00,
  100: 52.00,
  110: 58.00,
  120: 65.00,
};

/// Returns the expected ABW (g) for a given DOC.
///
/// Hard boundary guards prevent extrapolation outside the table range —
/// DOC ≤ 1 clamps to the first entry, DOC ≥ 120 clamps to the last.
/// Linear interpolation is used between table keys. Always returns a
/// positive value; never extrapolates beyond the defined range.
double getExpectedABW(int doc) {
  final keys = expectedAbwTable.keys.toList()..sort();

  // Hard boundary guards (fix #1)
  if (doc <= keys.first) return expectedAbwTable[keys.first]!;
  if (doc >= keys.last) return expectedAbwTable[keys.last]!;

  if (expectedAbwTable.containsKey(doc)) return expectedAbwTable[doc]!;

  // Linear interpolation between bracketing keys
  for (int i = 0; i < keys.length - 1; i++) {
    final k1 = keys[i], k2 = keys[i + 1];
    if (doc > k1 && doc < k2) {
      final t = (doc - k1) / (k2 - k1);
      return expectedAbwTable[k1]! + t * (expectedAbwTable[k2]! - expectedAbwTable[k1]!);
    }
  }

  // Fallback — should never reach here given the guards above
  return expectedAbwTable[keys.last]!;
}
