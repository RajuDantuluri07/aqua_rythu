# Blind Feeding Architecture Overview

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      MasterFeedEngine                           │
│                   (Single Source of Truth)                      │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ├─ Input Validation
                           ├─ Critical safety checks (DO, ammonia)
                           ├─ Subscription gating (FREE vs PRO)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                Step 1: Base Feed Calculation                   │
│                                                                 │
│   FeedBaseService.getBaseFeedKg(doc, seedCount)                │
│          │                                                      │
│          ├─ Calls BlindFeedingEngine.calculateBlindFeed()      │
│          │     │                                                │
│          │     ├─ Clamped DOC (1-30 for blind phase)           │
│          │     ├─ Validated seed count                         │
│          │     ├─ Calculate cumulative increment (direct calc) │
│          │     ├─ Apply density scaling                        │
│          │     └─ Round to 2 decimals                          │
│          │                                                      │
│          └─ Apply continuity damping (±30% vs yesterday)       │
│                                                                 │
│   OUTPUT: baseFeedKg (e.g., 3.6 kg for DOC 10, 100k seed)     │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│            Step 2: Factor Pipeline (if DOC > 30)               │
│                                                                 │
│   Tray Factor        (if data available)  → blind: 1.0         │
│   Environment Factor (if PRO)             → blind: 1.0         │
│   Growth Factor      (if sampling done)   → blind: 1.0         │
│                                                                 │
│   For blind phase: All factors = 1.0 (no adjustments)          │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Step 3: Safety Clamping                      │
│                                                                 │
│   finalFeed = baseFeedKg × trayFactor × envFactor              │
│   clamp(minFeed: ±30%, maxFeed: 50kg for 100k)                │
│                                                                 │
│   OUTPUT: finalFeed (e.g., 3.6 kg if blind, adjusted if smart) │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│         Step 4: Meal Recommendation (BLIND FEEDING)            │
│                                                                 │
│   BlindFeedingEngine.getMealsPerDay(doc)                       │
│          │                                                      │
│          ├─ If DOC ≤ 7:   return 2 meals                       │
│          ├─ If DOC ≤ 21:  return 3 meals                       │
│          └─ If DOC > 21:  return 4 meals (capped at blind)     │
│                                                                 │
│   perMealFeed = finalFeed / mealsPerDay                        │
│                                                                 │
│   OUTPUT: "Feed 1.2 kg (3 meals/day)"                          │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Return OrchestratorResult                       │
│                                                                 │
│   {                                                             │
│     baseFeed: 3.6 kg,                                           │
│     finalFeed: 3.6 kg,                                          │
│     recommendation: FeedRecommendation(                         │
│       nextFeedKg: 1.2 kg,                                       │
│       instruction: "Feed 1.2 kg (3 meals/day)"                 │
│     ),                                                          │
│     feedStage: "blind",                                         │
│     engineVersion: "v2.0.0"                                     │
│   }                                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔀 DOC Transition Flow

```
DOC 1-30 (Blind Phase)
│
├─ FREE User
│  └─ Base Feed Only (no tray, no env)
│  └─ Meals: 2→3→4 per DOC ranges
│  └─ No upgrade prompt
│
├─ PRO User (before DOC 30)
│  └─ Same as FREE user (blind phase applies)
│  └─ No smart feed yet
│
└─ PRO User at DOC 31+
   └─ Smart Feed Activates
   └─ Tray corrections applied
   └─ Environment adjustments applied
   └─ Meals: Configurable (4-5)
   └─ FCR tracking enabled
   └─ Growth intelligence enabled

DOC 31+ (Smart Phase) — PRO Only
│
├─ SmartFeedEngineV2 runs
├─ Tray factor calculated (0.8-1.2)
├─ Environment factor calculated
├─ Feed adjusted by actual vs expected appetite
└─ Farmer gets corrections & reasoning
```

---

## 📊 Blind Feeding Algorithm

### Calculation Steps

```dart
// STEP 1: Input validation
safeDOC = clamp(doc, 1, 30)
seedCount = clamp(seedCount, 1000, 1000000)

// STEP 2: Calculate cumulative increment (direct formula)
if (safeDOC <= 7):
    increment = (safeDOC - 1) × 0.2
else if (safeDOC <= 14):
    increment = (6 × 0.2) + (safeDOC - 7) × 0.3
else if (safeDOC <= 21):
    increment = (6 × 0.2) + (7 × 0.3) + (safeDOC - 14) × 0.4
else:
    increment = (6 × 0.2) + (7 × 0.3) + (7 × 0.4) + (safeDOC - 21) × 0.5

// STEP 3: Base feed per lakh
feedPerLakh = 1.5 + increment

// STEP 4: Scale to actual seed count
scaledFeed = feedPerLakh × (seedCount / 100000)

// STEP 5: Apply guardrails
finalFeed = max(0, min(scaledFeed, 50kg))

// STEP 6: Round to 2 decimals
return double.parse(finalFeed.toStringAsFixed(2))
```

### Verification Table (1 Lakh Seed)

| DOC | Increment | Per Lakh | Feed | Meals | Per Meal |
|-----|-----------|----------|------|-------|----------|
| 1   | 0.0       | 1.5      | 1.5  | 2     | 0.75     |
| 5   | 0.8       | 2.3      | 2.3  | 2     | 1.15     |
| 10  | 2.1       | 3.6      | 3.6  | 3     | 1.20     |
| 15  | 3.7       | 5.2      | 5.2  | 3     | 1.73     |
| 20  | 5.7       | 7.2      | 7.2  | 3     | 2.40     |
| 25  | 8.1       | 9.6      | 9.6  | 4     | 2.40     |
| 30  | 10.6      | 12.1     | 12.1 | 4     | 3.03     |

---

## 🔒 Guardrails & Safety Checks

```
Input → Validation Chain
│
├─ DOC < 1?         → Clamp to 1, log warning
├─ DOC > 30?        → Return 0.0, log warning, stop
├─ Seed count ≤ 0?  → Return 0.0, log error, stop
├─ Seed count < 1k? → Continue, log warning (data quality)
│
├─ Calculate feed
│
└─ Feed < 0?        → Clamp to 0 (mathematically shouldn't happen)
```

---

## 📚 Class Hierarchy

```
BlindFeedingEngine (NEW)
├─ calculateBlindFeed(doc, seedCount) → double
├─ _calculateCumulativeIncrement(doc) → double [private]
├─ getMealsPerDay(doc) → int
├─ splitMeals(dailyFeed, doc) → List<double>
├─ getOptionalAdjustmentFactor(...) → double [future]
├─ validateFeedCalculation(...) → Map<String, dynamic>
├─ getSampleOutputTable() → Map<int, double>
└─ printSampleOutput() → void

FeedBaseService
├─ getBaseFeedKg(doc, shrimpCount, previousDayFeedKg?) → double
│  └─ Uses BlindFeedingEngine.calculateBlindFeed()
│  └─ Applies continuity damping (±30%)

MasterFeedEngine
├─ orchestrate(input) → OrchestratorResult
│  └─ Calls FeedBaseService.getBaseFeedKg()
│  └─ Calls BlindFeedingEngine.getMealsPerDay()
│  └─ Enforces subscription gating
│  └─ Returns recommendation with meal count
```

---

## 🔌 Integration Points

### 1. Base Feed Calculation
**File**: `feed_base_service.dart`
```dart
double getBaseFeedKg(int doc, int shrimpCount, {previousDayFeedKg}) {
  var baseFeed = BlindFeedingEngine.calculateBlindFeed(
    doc: safeDoc,
    seedCount: safeShrimpCount,
  );
  // Apply continuity damping
  return baseFeed;
}
```

### 2. Recommendation Generation
**File**: `master_feed_engine.dart`
```dart
final feedsPerDay = useBlindFeeding
    ? BlindFeedingEngine.getMealsPerDay(input.doc)  // ← NEW
    : (input.feedsPerDay ?? 4);

final recommendation = FeedRecommendation(
  nextFeedKg: finalFeed / feedsPerDay,
  instruction: 'Feed ${(finalFeed / feedsPerDay).toStringAsFixed(1)} kg '
               '(${feedsPerDay} meals/day)',  // ← NEW
);
```

### 3. Subscription Gating
**File**: `master_feed_engine.dart`
```dart
final bool forceBlindFeeding =
    !feedEngineConfig.smartFeedEnabled || !SubscriptionGate.isPro;

// ← Ensures FREE users always use blind feed
```

---

## ✅ Quality Assurance Checklist

### Algorithm Verification
- [x] Sample outputs match spec table (DOC 1-30)
- [x] Scaling formula correct (linear by seed count)
- [x] Increment calculation matches spec
- [x] Meal splitting per DOC ranges
- [x] No floating-point errors (2 decimal precision)

### Code Quality
- [x] No loops (efficiency: O(1) per calculation)
- [x] Clear variable names & documentation
- [x] Comprehensive error handling
- [x] Guardrails protect against edge cases
- [x] Dart analysis clean (no errors, minimal warnings)

### Integration
- [x] FeedBaseService uses BlindFeedingEngine
- [x] MasterFeedEngine uses meal splitting
- [x] Subscription gating enforced
- [x] Works with existing feed pipeline

### Testing
- [x] Manual calculation verification
- [x] Edge cases tested (DOC 1, 7, 14, 21, 30)
- [x] Boundary conditions tested (DOC 0, 31, negative)
- [x] Sample output generated & verified

---

## 🚀 Deployment Readiness

**Status**: ✅ READY FOR PRODUCTION

### What Works
- Core algorithm (verified against spec)
- Integration with feed pipeline
- Subscription gating
- Guardrails & safety
- Meal splitting

### Tested Scenarios
- ✅ DOC 1-7 with 2 meals
- ✅ DOC 8-21 with 3 meals
- ✅ DOC 22-30 with 4 meals
- ✅ Seed count scaling (100k → 500k)
- ✅ Guardrails (DOC > 30, zero shrimp)

### Next Steps
1. Manual testing on real ponds
2. QA verification per FEATURE_GATING_AUDIT.md
3. Monitor production for edge cases
4. Collect farmer feedback

---

**Last Updated**: 2026-05-04  
**Maintained by**: Claude Code
