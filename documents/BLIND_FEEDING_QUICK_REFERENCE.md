# Blind Feeding Engine — Quick Reference

**Version**: 1.0.0  
**Status**: ✅ Production Ready  
**Scope**: DOC 1–30

---

## 🚀 Quick Start

### Import
```dart
import 'package:aqua_rythu/systems/feed/blind_feeding_engine.dart';
```

### Basic Calculation
```dart
// Calculate daily feed for DOC 15 with 150k shrimp
double feed = BlindFeedingEngine.calculateBlindFeed(
  doc: 15,
  seedCount: 150000,
);
// Returns: 7.8 kg
```

### Get Meal Count
```dart
int meals = BlindFeedingEngine.getMealsPerDay(15);
// Returns: 3
```

### Split into Meals
```dart
List<double> meals = BlindFeedingEngine.splitMeals(
  dailyFeed: 7.8,
  doc: 15,
);
// Returns: [2.6, 2.6, 2.6] (3 meals)
```

---

## 📊 Feed Table (1 Lakh Seed)

| DOC | Feed (kg) | Meals |
|-----|-----------|-------|
| 1   | 1.5       | 2     |
| 5   | 2.3       | 2     |
| 10  | 3.6       | 3     |
| 15  | 5.2       | 3     |
| 20  | 7.2       | 3     |
| 25  | 9.6       | 4     |
| 30  | 12.1      | 4     |

---

## 🔢 Formula

```
feed = (1.5 + increment) × (seedCount / 100000)

Where increment = {
  (DOC - 1) × 0.2,                                if DOC ≤ 7
  (6 × 0.2) + (DOC - 7) × 0.3,                   if DOC ≤ 14
  (6 × 0.2) + (7 × 0.3) + (DOC - 14) × 0.4,     if DOC ≤ 21
  (6 × 0.2) + (7 × 0.3) + (7 × 0.4) + (DOC - 21) × 0.5,  if DOC > 21
}
```

---

## 🔒 Safety Guardrails

| Check | Result | Log |
|-------|--------|-----|
| DOC > 30 | Return 0.0 | ⚠️ Warning |
| Seed count = 0 | Return 0.0 | 🔴 Error |
| Seed count < 1k | Continue | ⚠️ Warning |
| Feed < 0 | Clamp to 0 | Silent |

---

## 🍽️ Meal Rules

```
DOC 1-7   → 2 meals/day
DOC 8-21  → 3 meals/day
DOC 22-30 → 4 meals/day
DOC > 30  → 0 (switch to smart feed)
```

---

## 🔀 Integration Points

### 1. In FeedBaseService
```dart
var baseFeed = BlindFeedingEngine.calculateBlindFeed(
  doc: safeDoc,
  seedCount: safeShrimpCount,
);
```

### 2. In MasterFeedEngine
```dart
final feedsPerDay = useBlindFeeding
    ? BlindFeedingEngine.getMealsPerDay(input.doc)
    : (input.feedsPerDay ?? 4);
```

### 3. In Recommendation
```dart
instruction: 'Feed ${perMealFeed.toStringAsFixed(1)} kg '
             '(${feedsPerDay} meals/day)'
```

---

## ✅ Sample Verification

### Test 1: DOC 10, 100k seed
```dart
BlindFeedingEngine.calculateBlindFeed(doc: 10, seedCount: 100000)
// Expected: 3.6 kg ✓
```

### Test 2: DOC 10, 200k seed
```dart
BlindFeedingEngine.calculateBlindFeed(doc: 10, seedCount: 200000)
// Expected: 7.2 kg (2× the 100k value) ✓
```

### Test 3: DOC 31, any seed
```dart
BlindFeedingEngine.calculateBlindFeed(doc: 31, seedCount: 100000)
// Expected: 0.0 kg (DOC > 30, switch to smart) ✓
```

---

## 📖 Documentation

| File | Purpose |
|------|---------|
| `BLIND_FEEDING_IMPLEMENTATION.md` | Full technical guide |
| `BLIND_FEEDING_ARCHITECTURE.md` | System architecture |
| `IMPLEMENTATION_SUMMARY.md` | High-level summary |
| `BLIND_FEEDING_QUICK_REFERENCE.md` | This file |

---

## 🎯 Key Methods

### Calculate Feed
```dart
static double calculateBlindFeed({
  required int doc,
  required int seedCount,
}) → double
```

### Get Meal Count
```dart
static int getMealsPerDay(int doc) → int
```

### Split Meals
```dart
static List<double> splitMeals({
  required double dailyFeed,
  required int doc,
}) → List<double>
```

### Validate
```dart
static Map<String, dynamic> validateFeedCalculation({
  required int doc,
  required int seedCount,
  required double calculatedFeed,
}) → Map
```

### Get Sample Data
```dart
static Map<int, double> getSampleOutputTable() → Map
static void printSampleOutput()
```

---

## 🔧 Common Questions

**Q: Why no tray adjustments in blind phase?**  
A: Tray data is unreliable before DOC 30. Blind feeding uses only DOC ramp + density.

**Q: Why 2→3→4 meals?**  
A: Matches shrimp growth stages. DOC 1-7: small shrimp, less frequent feeding. DOC 22-30: larger shrimp, can handle 4 meals.

**Q: What if DOC > 30?**  
A: Returns 0.0 kg. System should switch to SmartFeedEngineV2 (PRO only).

**Q: What about mortality?**  
A: Blind feeding ignores mortality (no live sampling yet). FeedBaseService applies continuity damping instead (±30%).

**Q: Can I use this for DOC > 30?**  
A: No. Returns 0.0 and logs warning. Use SmartFeedEngineV2 instead.

---

## 📞 Support

- **Algorithm questions** → See `BLIND_FEEDING_IMPLEMENTATION.md`
- **Integration questions** → See `BLIND_FEEDING_ARCHITECTURE.md`
- **Code questions** → Check inline comments in `blind_feeding_engine.dart`
- **Specification** → See original spec document

---

**Last Updated**: 2026-05-04  
**Status**: ✅ Production Ready
