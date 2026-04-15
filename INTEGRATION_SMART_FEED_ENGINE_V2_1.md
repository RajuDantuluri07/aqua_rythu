# Integration: SmartFeedEngine → SmartFeedDecisionEngine

## Overview

This guide shows how to integrate the new SmartFeedDecisionEngine (v2.1) into your existing SmartFeedEngine workflow.

## Current Flow (Before)

```
SmartFeedEngine.applyTrayAdjustment()
    ↓
MasterFeedEngine.run() → FeedOutput
    ↓
_logDebug() → stored in DB
    ↓
Helper generates explanation (UI layer)
```

## New Flow (After)

```
SmartFeedEngine.applyTrayAdjustment()
    ↓
MasterFeedEngine.run() → FeedOutput
    ↓
SmartFeedDecisionEngine.buildSmartFeedOutput()
    ├─ Builds explanation
    ├─ Calculates confidence
    └─ Generates recommendations
    ↓
SmartFeedOutput → stored/displayed
    ↓
UI receives complete intelligence
```

## Step-by-Step Integration

### Step 1: Create Output Conversion Method

Add this method to SmartFeedEngine:

```dart
/// Convert FeedOutput + metadata to SmartFeedOutput with full intelligence
static SmartFeedOutput buildIntelligentOutput({
  required FeedOutput engineOutput,
  required double baseDocFeed,
  required double? biomassFeed,
  required double? abw,
  required int doc,
  required int? samplingAgeDays,
  required String pondId,
}) {
  // Extract factors from existing engine output
  final fcrFactor = engineOutput.factors['fcr'] as double?;
  final trayFactor = engineOutput.factors['tray'] as double?;
  final growthFactor = engineOutput.factors['growth'] as double?;

  // Use new decision engine to build complete output
  return SmartFeedDecisionEngine.buildSmartFeedOutput(
    finalFeed: engineOutput.recommendedFeed,
    docFeed: baseDocFeed,
    biomassFeed: biomassFeed,
    abw: abw,
    doc: doc,
    fcrFactor: fcrFactor,
    trayFactor: trayFactor,
    growthFactor: growthFactor,
    samplingAgeDays: samplingAgeDays,
  );
}
```

### Step 2: Update applyTrayAdjustment()

```dart
static Future<void> applyTrayAdjustment({
  required String pondId,
  required int doc,
  required TrayStatus trayStatus,
}) async {
  final mode = getFeedMode(doc);
  if (mode == FeedMode.normal) return;

  final input = await FeedInputBuilder.fromDB(pondId);
  final output = MasterFeedEngine.run(input);

  if (output.finalFactor <= 0.0) return;

  // 🔥 NEW: Generate intelligent output
  final intelligentOutput = buildIntelligentOutput(
    engineOutput: output,
    baseDocFeed: input.baseFeed, // or however you get doc feed
    biomassFeed: input.biomassFeed,
    abw: input.abw,
    doc: input.doc,
    samplingAgeDays: input.samplingAgeDays,
    pondId: pondId,
  );

  final reasonTag = _reasonTag(output.finalFactor, trayStatus.name, mode);

  // Log with new explanation from engine
  await _logDebugEnhanced(
    pondId: pondId,
    doc: doc,
    mode: mode,
    output: output,
    intelligentOutput: intelligentOutput,
    reason: reasonTag,
    abw: input.abw,
  );

  // Rest of logic stays same...
}
```

### Step 3: Create Enhanced Debug Logging

```dart
static Future<void> _logDebugEnhanced({
  required String pondId,
  required int doc,
  required FeedMode mode,
  required FeedOutput output,
  required SmartFeedOutput intelligentOutput,
  required String reason,
  required double? abw,
}) async {
  // Log raw output (existing)
  await _logDebug(
    pondId: pondId,
    doc: doc,
    mode: mode,
    output: output,
    reason: reason,
    abw: abw,
  );

  // Also store intelligent output if you want to track it
  // Store explanation, confidence, recommendations in a separate table
  // or extend debug_logs table with these fields
}
```

### Step 4: Create Public Method for Dashboard

```dart
/// Get intelligent feed recommendation for dashboard/UI
static Future<SmartFeedOutput?> getIntelligentFeedRecommendation(
  String pondId,
) async {
  try {
    final input = await FeedInputBuilder.fromDB(pondId);
    final output = MasterFeedEngine.run(input);

    if (output.finalFactor <= 0.0) return null;

    return buildIntelligentOutput(
      engineOutput: output,
      baseDocFeed: input.baseFeed,
      biomassFeed: input.biomassFeed,
      abw: input.abw,
      doc: input.doc,
      samplingAgeDays: input.samplingAgeDays,
      pondId: pondId,
    );
  } catch (e) {
    AppLogger.error('SmartFeedEngine.getIntelligentFeedRecommendation failed', e);
    return null;
  }
}
```

### Step 5: Update UI to Use New Output

In your feed display/dashboard widget:

```dart
// Before: Built explanation in helper
// final explanation = SmartFeedDebugHelper.generateExplanation(...);

// After: Get complete output from engine
final intelligentOutput = await SmartFeedEngine
  .getIntelligentFeedRecommendation(pondId);

if (intelligentOutput != null) {
  // Convert to FeedResult for backward compatibility
  final feedResult = SmartFeedDebugHelper
    .buildFeedResultFromOutput(intelligentOutput);

  // Display on screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SmartFeedDebugScreen(data: feedResult),
    ),
  );
}
```

## Data Model Considerations

### Option A: Extend debug_logs Table

If you want to persist explanation/confidence/recommendations:

```sql
ALTER TABLE debug_logs ADD COLUMN (
  explanation TEXT,
  confidence_score DECIMAL(3,2),
  recommendations JSONB
);
```

Then update _logDebug:

```dart
static Future<void> _logDebug({...}) async {
  final intelligentOutput = buildIntelligentOutput(...);

  await _supabase
    .from('debug_logs')
    .insert({
      // ... existing fields ...
      'explanation': intelligentOutput.explanation,
      'confidence_score': intelligentOutput.confidenceScore,
      'recommendations': jsonEncode(
        intelligentOutput.recommendations,
      ),
    });
}
```

### Option B: Keep Separate

Store engine output only when needed for display (minimal DB impact):

```dart
// Only build intelligent output when displaying dashboard
// Don't persist to DB (lighter weight)
```

## Testing Integration

### Unit Test

```dart
test('SmartFeedEngine.buildIntelligentOutput produces complete output', () {
  final mockEngineOutput = FeedOutput(
    recommendedFeed: 10.2,
    baseFeed: 11.0,
    finalFactor: 0.93,
    fcrFactor: 0.91,
    factorBreakdown: {},
    factors: {
      'fcr': 0.91,
      'tray': null,
      'growth': 1.0,
    },
    engineVersion: 'v1',
    alerts: [],
    reasons: [],
  );

  final intelligentOutput = SmartFeedEngine.buildIntelligentOutput(
    engineOutput: mockEngineOutput,
    baseDocFeed: 11.0,
    biomassFeed: 10.8,
    abw: 12.5,
    doc: 35,
    samplingAgeDays: 3,
    pondId: 'test_pond',
  );

  expect(intelligentOutput.finalFeed, equals(10.2));
  expect(intelligentOutput.explanation, isNotEmpty);
  expect(intelligentOutput.confidenceScore, greaterThan(0.7));
  expect(intelligentOutput.recommendations, isNotEmpty);
});
```

### Integration Test

```dart
testWidgets('Dashboard displays intelligent output', (tester) async {
  // Mock SmartFeedEngine.getIntelligentFeedRecommendation
  // Verify SmartFeedDebugScreen shows explanation + recommendations
  // Verify confidence score displays correctly
});
```

## Backward Compatibility

Old code using Helper still works:

```dart
// OLD CODE - Still works
final feedResult = SmartFeedDebugHelper.buildFeedResult(...);

// NEW CODE - Better
final intelligentOutput = SmartFeedDecisionEngine.buildSmartFeedOutput(...);
final feedResult = SmartFeedDebugHelper
  .buildFeedResultFromOutput(intelligentOutput);
```

## Summary of Changes

| Component | Before | After |
|-----------|--------|-------|
| Explanation | Generated in Helper | Generated in Engine |
| Confidence | Calculated in Helper | Calculated in Engine |
| Recommendations | None | Generated in Engine |
| DB Storage | Raw output only | Can store explanation |
| UI Logic | Has decision logic | Display only |
| Testability | Helper tests | Engine tests |

## Checklist

- [ ] Add `buildIntelligentOutput()` to SmartFeedEngine
- [ ] Create `getIntelligentFeedRecommendation()` getter
- [ ] Update `applyTrayAdjustment()` to use new engine
- [ ] Create test for buildIntelligentOutput()
- [ ] Update UI to use SmartFeedOutput
- [ ] Test on device
- [ ] Consider DB schema updates
- [ ] Update debug logging if storing explanation

## Next: Production Deployment

Once integrated:

1. Run test suite: `flutter test test/`
2. Manual QA on device
3. Deploy with new dashboard
4. Monitor for issues

---

**Ready to integrate SmartFeedDecisionEngine into your SmartFeedEngine!** ✅
