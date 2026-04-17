/// Single source of truth for shrimp biomass and survival calculations.
/// All screens and engines must use these helpers — no inline formulas.
library;

/// Biomass in kg: seedCount × abwGrams × survivalRate / 1000.
double calcBiomassKg(int seedCount, double abwGrams, double survivalRate) {
  if (seedCount <= 0 || abwGrams <= 0 || survivalRate <= 0) return 0.0;
  return (seedCount * abwGrams * survivalRate) / 1000.0;
}

/// Model-based survival estimate when no real sampling data exists.
/// Breakpoints: DOC ≤30 → 100%, ≤60 → 95%, >60 → 90%.
double estimateSurvival(int doc) {
  if (doc > 60) return 0.90;
  if (doc > 30) return 0.95;
  return 1.00;
}
