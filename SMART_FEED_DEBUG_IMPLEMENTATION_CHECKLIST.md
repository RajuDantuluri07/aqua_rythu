# Smart Feed Debug Dashboard - Implementation Checklist

## ✅ Completed Setup (Phase 1)

Core components have been created:

### Files Created
- [x] `lib/models/feed_result.dart` - FeedResult & FeedSource enum
- [x] `lib/features/debug/smart_feed_debug_screen.dart` - UI Dashboard
- [x] `lib/features/debug/smart_feed_debug_provider.dart` - State Management
- [x] `lib/core/utils/smart_feed_debug_helper.dart` - Utility Helper
- [x] `lib/features/feed/smart_feed_screen_example.dart` - Example Integration
- [x] `SMART_FEED_DEBUG_INTEGRATION.md` - Integration Guide
- [x] `SMART_FEED_DEBUG_IMPLEMENTATION_CHECKLIST.md` - This file

### Component Overview

#### 1. FeedResult Model
```dart
class FeedResult {
  final double finalFeed;
  final FeedSource source; // DOC or BIOMASS
  final double docFeed;
  final double? biomassFeed;
  final double? fcrFactor;
  final double? trayFactor;
  final double? growthFactor;
  final String explanation;
  final double confidenceScore; // 0.0 - 1.0
}
```

#### 2. SmartFeedDebugScreen
Complete UI with:
- 🔷 Feed Summary Card
- 🔷 Feed Source Visualization
- 🔷 Feed Breakdown Card
- 🔷 Smart Factors Panel
- 🔷 Decision Explanation
- 🔷 Debug Logs (Collapsible)

#### 3. SmartFeedDebugProvider
```dart
final smartFeedDebugProvider = StateNotifierProvider<...>(...)
```
Methods:
- `setFeedResult(FeedResult)` - Display data
- `updateConfidenceScore(double)` - Update confidence
- `updateExplanation(String)` - Update explanation
- `clear()` - Clear state

#### 4. SmartFeedDebugHelper
Static utilities for:
- `buildFeedResult()` - Convert engine output → FeedResult
- `generateExplanation()` - Auto-generate explanations
- `calculateConfidenceScore()` - Compute confidence level
- `determineFeedSource()` - Identify DOC vs Biomass

---

## 📋 Next Steps (Phase 2: Integration)

### Step 1: Verify Dependencies
- [x] Flutter Riverpod available (`flutter_riverpod`)
- [ ] Check that your `SmartFeedEngine` or `MasterFeedEngine` is accessible

**Verify:**
```bash
grep -r "MasterFeedEngine\|FeedOutput" lib/core/engines/
```

### Step 2: Update Your Feed Calculation Service

Choose one of these integration approaches:

#### Option A: Simple Inline (Quickest)
In your feed calculation screen:
```dart
final result = SmartFeedDebugHelper.buildFeedResult(
  engineOutput: output,
  docFeed: docFeed,
  biomassFeed: biomassFeed,
  abw: abw,
  doc: doc,
  explanation: SmartFeedDebugHelper.generateExplanation(...),
  confidenceScore: SmartFeedDebugHelper.calculateConfidenceScore(...),
);

Navigator.push(context, MaterialPageRoute(
  builder: (_) => SmartFeedDebugScreen(data: result),
));
```

#### Option B: Using Provider (Recommended)
```dart
final notifier = ref.read(smartFeedDebugProvider.notifier);
notifier.setFeedResult(result);

// Then navigate
Navigator.push(...);
```

#### Option C: Service Class
Create `lib/services/smart_feed_service.dart`:
```dart
class SmartFeedService {
  Future<FeedResult> calculateFeedWithDebug(String pondId, int doc) async {
    // Your calculations here
    return SmartFeedDebugHelper.buildFeedResult(...);
  }
}
```

### Step 3: Add Navigation Entry Point

Where to add the button/link to view debug dashboard:

- [ ] **Farm Pond Detail Screen** - "View Detailed Analysis" button
- [ ] **Feed History Screen** - Add action menu
- [ ] **Dashboard** - Debug card showing last calculated feed
- [ ] **Smart Feed Screen** - Main CTA button (See Example)
- [ ] **Pro/Premium Mode** - Hidden behind 5-tap unlock

**Recommended:** Add to your feed calculation/display screen (see `smart_feed_screen_example.dart`)

### Step 4: Wire Into Your Smart Feed Engine

Update your feed calculation with FeedResult building:

```dart
// In your smart feed calculation
final engineOutput = MasterFeedEngine.run(input);

// NEW: Build debug result
final debugResult = SmartFeedDebugHelper.buildFeedResult(
  engineOutput: engineOutput,
  docFeed: baseFeed,
  biomassFeed: biomassFeed,
  abw: input.abw,
  doc: doc,
  explanation: SmartFeedDebugHelper.generateExplanation(
    source: source,
    fcrFactor: engineOutput.factors['fcr'] as double?,
    trayFactor: engineOutput.factors['tray'] as double?,
    growthFactor: engineOutput.factors['growth'] as double?,
    finalFactor: engineOutput.finalFactor,
  ),
  confidenceScore: SmartFeedDebugHelper.calculateConfidenceScore(
    hasRecentSampling: input.abw != null,
    hasTrayData: engineOutput.factors['tray'] != null,
    fcrFactor: engineOutput.factors['fcr'] as double?,
    growthFactor: engineOutput.factors['growth'] as double?,
  ),
);

// Save or display as needed
return debugResult;
```

### Step 5: Test the Dashboard

Quick test navigation:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SmartFeedDebugScreen(
      data: FeedResult(
        finalFeed: 10.2,
        source: FeedSource.biomass,
        docFeed: 11.25,
        biomassFeed: 10.8,
        fcrFactor: 0.9,
        trayFactor: null,
        growthFactor: 1.0,
        explanation: "Test explanation",
        confidenceScore: 0.82,
      ),
    ),
  ),
);
```

---

## 🔧 Advanced Configuration (Phase 3)

### A. Customization

#### Change Dashboard Theme
In `smart_feed_debug_screen.dart`, modify:
```dart
backgroundColor: const Color(0xFFF6F7FB), // Change bg color
...[card colors, text styles, etc]
```

#### Add Custom Explanations
Extend `SmartFeedDebugHelper.generateExplanation()`:
```dart
// Add domain-specific rules
if (input.waterTemp < 24) {
  parts.add("• Low water temperature → Feed adjustment for metabolism");
}
```

#### Customize Factor Emoji/Colors
In `_factor()` widget:
```dart
if (value > 1.10) {
  emoji = "🟢🚀"; // More aggressive
  color = Colors.green;
}
```

### B. Premium Feature Gating

For restricting to premium users:

```dart
class DebugAccessService {
  static bool canAccess(User user) {
    return user.isPremium || _debugModeEnabled;
  }

  static bool _debugModeEnabled = false;
  static int _titleTaps = 0;

  static void onTitleTap() {
    _titleTaps++;
    if (_titleTaps >= 5) {
      _debugModeEnabled = true;
      // Show toast: "Debug mode unlocked!"
    }
  }
}
```

Usage in your app:
```dart
if (DebugAccessService.canAccess(currentUser)) {
  // Show debug dashboard button
}
```

### C. Data Persistence

Save FeedResult to database for history:

```dart
Future<void> saveFeedResultHistory(FeedResult result, String pondId) async {
  await supabase
    .from('feed_results_debug')
    .insert({
      'pond_id': pondId,
      'final_feed': result.finalFeed,
      'source': result.source.name,
      'doc_feed': result.docFeed,
      'biomass_feed': result.biomassFeed,
      'fcr_factor': result.fcrFactor,
      'tray_factor': result.trayFactor,
      'growth_factor': result.growthFactor,
      'explanation': result.explanation,
      'confidence_score': result.confidenceScore,
      'created_at': DateTime.now().toIso8601String(),
    });
}
```

### D. Logging & Analytics

Track debug dashboard usage:

```dart
class AnalyticsHelper {
  static void logDebugDashboardView(FeedResult result) {
    // Your analytics service
    analytics.logEvent(
      name: 'debug_dashboard_viewed',
      parameters: {
        'final_feed': result.finalFeed,
        'source': result.source.name,
        'confidence_score': result.confidenceScore,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
```

---

## 🧪 Testing

### Unit Tests
Create `test/models/feed_result_test.dart`:
```dart
void main() {
  test('FeedResult should initialize with correct values', () {
    final result = FeedResult(
      finalFeed: 10.2,
      source: FeedSource.biomass,
      docFeed: 11.25,
      biomassFeed: 10.8,
      fcrFactor: 0.9,
      trayFactor: null,
      growthFactor: 1.0,
      explanation: "Test",
      confidenceScore: 0.82,
    );

    expect(result.finalFeed, 10.2);
    expect(result.source, FeedSource.biomass);
  });
}
```

### Widget Tests
Test the dashboard UI:
```dart
void main() {
  testWidgets('SmartFeedDebugScreen renders all cards', (tester) async {
    final result = FeedResult(...);
    
    await tester.pumpWidget(
      MaterialApp(
        home: SmartFeedDebugScreen(data: result),
      ),
    );

    expect(find.text("Today's Feed Recommendation"), findsOneWidget);
    expect(find.text("Feed Breakdown"), findsOneWidget);
    expect(find.text("Why this feed?"), findsOneWidget);
  });
}
```

---

## 📊 Dashboard Features Summary

| Card | Purpose | Key Data |
|------|---------|----------|
| Feed Summary | Quick glance | Final feed amount, mode, source |
| Feed Source | Visual indicator | DOC vs Biomass, reason |
| Feed Breakdown | Calculation transparency | DOC, Biomass, FCR Adj, Final |
| Smart Factors | Engine insights | FCR, Tray, Growth, Confidence |
| Explanation | Natural language WHY | Readable explanation text |
| Debug Logs | Raw data | All values for debugging |

---

## 🚀 Launch Checklist

Before releasing to users:

**Functionality**
- [ ] Dashboard renders without errors
- [ ] All 6 cards display correctly
- [ ] Navigation works smoothly
- [ ] Explanation text is readable
- [ ] Confidence score calculation is accurate
- [ ] Debug logs show correct raw values

**UI/UX**
- [ ] Layout is responsive on all phone sizes
- [ ] Text is readable (font sizes, contrast)
- [ ] Emojis render correctly (🟢 🟡 🔵 etc)
- [ ] Colors match design spec
- [ ] Smooth app bar scrolling

**Data**
- [ ] FeedResult model captures all needed fields
- [ ] Explanation generation is logical
- [ ] Confidence scoring is meaningful
- [ ] Feed source determination is correct

**Integration**
- [ ] Navigation entry point works
- [ ] Provider state updates properly
- [ ] No console errors/warnings
- [ ] Performance is good (no lag)

**Testing**
- [ ] Unit tests pass
- [ ] Widget tests pass
- [ ] Manual testing on device done
- [ ] Tested with various feed scenarios

---

## 📞 Support

For questions or issues with the Smart Feed Debug Dashboard:

1. Check the Integration Guide: `SMART_FEED_DEBUG_INTEGRATION.md`
2. Review the Example Implementation: `lib/features/feed/smart_feed_screen_example.dart`
3. Check the SmartFeedDebugHelper: `lib/core/utils/smart_feed_debug_helper.dart`
4. Review the Dashboard Code: `lib/features/debug/smart_feed_debug_screen.dart`

---

## 📝 Version History

- **v1.0** (2026-04-16) - Initial dashboard implementation
  - Created FeedResult model
  - Implemented full 6-card UI
  - Added state provider
  - Added utility helpers
  - Added example integration
  - Added documentation

---

**Next: Proceed to Phase 2 Integration Steps above** ⬆️
