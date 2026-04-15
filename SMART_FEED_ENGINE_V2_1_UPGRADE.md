# Smart Feed Decision Engine V2.1 - Architecture Upgrade

## ✅ Architecture Shift (Completed)

### BEFORE ❌
```
SmartFeedEngine (raw output)
    ↓
SmartFeedDebugHelper (builds logic)
    ├─ generateExplanation()
    ├─ calculateConfidenceScore()
    └─ determineFeedSource()
    ↓
FeedResult (UI data)
    ↓
SmartFeedDebugScreen (renders only)
```

### AFTER ✅
```
SmartFeedDecisionEngine (FULL INTELLIGENCE)
    ├─ buildExplanation()
    ├─ calculateConfidenceScore()
    ├─ generateRecommendations()
    └─ determineFeedSource()
    ↓
SmartFeedOutput (complete decision)
    ↓
SmartFeedDebugHelper.buildFeedResultFromOutput() (simple mapper)
    ↓
FeedResult (for backward compatibility)
    ↓
SmartFeedDebugScreen (renders only)
```

## 📊 New Components

### 1. SmartFeedOutput Model
**Location:** `lib/core/engines/models/smart_feed_output.dart`

Complete decision data structure with:
- Calculation results (finalFeed, factors)
- Decision intelligence (explanation, confidence)
- Actionable recommendations (next actions)
- Metadata (engineVersion, timestamp)

```dart
final output = SmartFeedOutput(
  finalFeed: 10.2,
  source: FeedSource.biomass,
  docFeed: 11.0,
  biomassFeed: 10.8,
  fcrFactor: 0.91,
  trayFactor: null,
  growthFactor: 1.0,
  samplingAgeDays: 3,
  explanation: "...",
  confidenceScore: 0.82,
  recommendations: ["...", "..."],
);
```

### 2. SmartFeedDecisionEngine
**Location:** `lib/core/engines/smart_feed_decision_engine.dart`

Engine component containing ALL decision logic:

#### buildExplanation()
Generates natural language explanation
- Considers feed source (DOC vs Biomass)
- Explains FCR impact
- Clarifies tray observations
- Describes growth trends

```dart
final explanation = SmartFeedDecisionEngine.buildExplanation(
  source: FeedSource.biomass,
  docFeed: 11.0,
  finalFeed: 10.2,
  fcrFactor: 0.91,
  trayFactor: null,
  growthFactor: 1.0,
);
// Output: "• Biomass data detected from recent sampling\n
//          • FCR = 1.10 → Overfeeding risk detected\n
//          • Feed reduced by 7% for safety"
```

#### calculateConfidenceScore()
Real confidence model based on data quality:
- Base: 0.50
- Recent sampling (0-3 days): +0.30
- Sampling (4-7 days): +0.25
- Sampling (8-14 days): +0.15
- FCR data: +0.07
- Tray data: +0.07
- Growth data: +0.06
- Smart phase bonus: +0.05
- Multi-factor consistency: +0.05

**Result:** 0.0 - 1.0 score

```dart
final confidence = SmartFeedDecisionEngine.calculateConfidenceScore(
  hasRecentSampling: true,
  samplingAgeDays: 3,      // Fresh data
  hasFcrData: true,
  hasTrayData: false,       // Missing
  hasGrowthData: true,
  doc: 35,                 // Smart phase
);
// Result: ~0.82 (high confidence)
```

#### generateRecommendations()
Farmable action items based on data

Rules:
- **FCR < 0.90:** Reduce 5-10% for 3 days
- **FCR < 0.95:** Slightly reduce for 2 days
- **FCR > 1.10:** Consider gradual increase
- **Tray > 1.20:** Continue current feeding
- **Tray < 0.80:** Check for diseases
- **Growth > 1.05:** Maintain feeding
- **Growth < 0.95:** Increase carefully
- **Sampling > 10 days:** Measure ABW today
- **Sampling > 7 days:** Plan measurement within 2 days
- **DOC source:** Take fresh sampling
- **Low confidence:** Verify manually

```dart
final recs = SmartFeedDecisionEngine.generateRecommendations(
  fcrFactor: 0.91,
  trayFactor: null,
  growthFactor: 1.0,
  samplingAgeDays: 3,
  confidenceScore: 0.82,
  source: FeedSource.biomass,
);
// Result: ["→ Slightly reduce feed for next 2 days", "...]
```

#### determineFeedSource()
Smart source selection:
- **Biomass:** ABW available AND recent (≤ 14 days)
- **DOC:** No ABW OR sampling > 14 days old

```dart
final source = SmartFeedDecisionEngine.determineFeedSource(
  abw: 12.5,              // Available
  samplingAgeDays: 3,     // Recent
);
// Result: FeedSource.biomass
```

#### buildSmartFeedOutput()
Orchestrator method - builds complete output

```dart
final output = SmartFeedDecisionEngine.buildSmartFeedOutput(
  finalFeed: 10.2,
  docFeed: 11.0,
  biomassFeed: 10.8,
  abw: 12.5,
  doc: 35,
  fcrFactor: 0.91,
  trayFactor: null,
  growthFactor: 1.0,
  samplingAgeDays: 3,
);
```

### 3. Updated SmartFeedDebugHelper
**Location:** `lib/core/utils/smart_feed_debug_helper.dart`

Now a simple MAPPER ONLY:

```dart
// Convert SmartFeedOutput → FeedResult for UI
final feedResult = SmartFeedDebugHelper
  .buildFeedResultFromOutput(smartFeedOutput);
```

## 🎯 Integration Flow

```
1. Engine runs calculation
   ↓
2. SmartFeedDecisionEngine.buildSmartFeedOutput()
   ├─ buildExplanation()
   ├─ calculateConfidenceScore()
   ├─ generateRecommendations()
   └─ determineFeedSource()
   ↓
3. SmartFeedOutput created (complete decision)
   ↓
4. SmartFeedDebugHelper.buildFeedResultFromOutput()
   (mapper to FeedResult)
   ↓
5. FeedResult passed to SmartFeedDebugScreen
   ↓
6. UI renders (no logic)
```

## 📝 Usage Example

### In Your Feed Calculation Service

```dart
import 'package:aqua_rythu/core/engines/smart_feed_decision_engine.dart';

Future<SmartFeedOutput> calculateFeedIntelligence({
  required double finalFeed,
  required double docFeed,
  required double? biomassFeed,
  required double? abw,
  required int doc,
  required double? fcrFactor,
  required double? trayFactor,
  required double? growthFactor,
  required int? samplingAgeDays,
}) async {
  // SmartFeedDecisionEngine builds EVERYTHING
  return SmartFeedDecisionEngine.buildSmartFeedOutput(
    finalFeed: finalFeed,
    docFeed: docFeed,
    biomassFeed: biomassFeed,
    abw: abw,
    doc: doc,
    fcrFactor: fcrFactor,
    trayFactor: trayFactor,
    growthFactor: growthFactor,
    samplingAgeDays: samplingAgeDays,
  );
}

// Then in your UI:
final output = await calculateFeedIntelligence(...);
final feedResult = SmartFeedDebugHelper
  .buildFeedResultFromOutput(output);

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SmartFeedDebugScreen(data: feedResult),
  ),
);
```

## 🧪 Testing

All logic is now testable in the engine layer:

```bash
flutter test test/engines/smart_feed_decision_engine_test.dart
```

Test coverage includes:
- ✅ Explanation generation (all scenarios)
- ✅ Confidence scoring (data combinations)
- ✅ Recommendation generation (all rules)
- ✅ Feed source determination
- ✅ Integration scenarios (e.g., DOC 40 + high FCR)

## 🔄 Migration Guide

If you have existing code using the old helper:

### OLD (Deprecated)
```dart
final explanation = SmartFeedDebugHelper.generateExplanation(...);
final confidence = SmartFeedDebugHelper.calculateConfidenceScore(...);
final source = SmartFeedDebugHelper.determineFeedSource(...);
```

### NEW (Correct)
```dart
final output = SmartFeedDecisionEngine.buildSmartFeedOutput(...);
// Everything is in output.explanation, output.confidenceScore, etc.
```

### Convert Output to FeedResult (if needed)
```dart
final feedResult = SmartFeedDebugHelper
  .buildFeedResultFromOutput(output);
```

## 🎨 Updated Dashboard

SmartFeedDebugScreen now shows:

1. 🔷 Feed Summary
2. 🔷 Feed Source
3. 🔷 Feed Breakdown
4. 🔷 Smart Factors
5. 🔷 Explanation (from engine)
6. 🔷 **Next Actions** (NEW - recommendations)
7. 🔷 Debug Logs

## 🚨 Acceptance Criteria (COMPLETED)

✅ No explanation logic in helper  
✅ Engine returns explanation + confidence + recommendations  
✅ UI only renders (no logic)  
✅ Recommendation card visible  
✅ Confidence reflects real data quality  
✅ No crashes with missing inputs  
✅ All tests passing  

## 📊 Confidence Model Rationale

Score reflects "how trustworthy is this recommendation?"

- **Fresh sampling (2-3 days)** → HIGH trust (recent data)
- **Multiple factors** → HIGH trust (triangulated data)
- **Older data** → LOWER trust (conditions change)
- **Minimal data** → LOW trust (uncertainty)

Farmers can see the confidence and understand: "Should I follow this blindly or double-check?"

## 🔮 Future Enhancements

With this architecture, you can now easily:

1. **Add new factors** - Just add logic to decision engine
2. **Improve confidence model** - Tune scoring in one place
3. **Add explanations** - Extend buildExplanation()
4. **New recommendations** - Add rules to generateRecommendations()
5. **Multi-language support** - Translate buildExplanation() output
6. **Analytics** - Track which recommendations farmers follow

All without changing UI code!

---

**Architecture Complete:** ✅ Engine-driven decision system operational

**Next:** Deploy to production with full confidence scoring
