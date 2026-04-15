# Smart Feed Debug Dashboard - Integration Guide

## Overview
The Smart Feed Debug Dashboard is a new feature designed to expose internal feed engine signals and explain feed recommendations to farmers.

## Files Created

1. **`lib/models/feed_result.dart`** - Core data model
2. **`lib/features/debug/smart_feed_debug_screen.dart`** - Dashboard UI component
3. **`lib/features/debug/smart_feed_debug_provider.dart`** - State management

## Quick Start

### 1. Basic Usage (Navigation)

```dart
import 'package:aqua_rythu/models/feed_result.dart';
import 'package:aqua_rythu/features/debug/smart_feed_debug_screen.dart';

// Navigate to the debug dashboard
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
        explanation:
            "FCR is high → reducing feed. Biomass available from sampling.",
        confidenceScore: 0.82,
      ),
    ),
  ),
);
```

### 2. Using the Provider (State Management)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aqua_rythu/features/debug/smart_feed_debug_provider.dart';

class FeedCalculationScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedResult = ref.watch(smartFeedDebugProvider);
    
    return Column(
      children: [
        // Your existing feed UI...
        
        ElevatedButton(
          onPressed: () {
            // Calculate and set feed result
            final result = FeedResult(
              finalFeed: 10.2,
              source: FeedSource.biomass,
              docFeed: 11.25,
              biomassFeed: 10.8,
              fcrFactor: 0.9,
              trayFactor: null,
              growthFactor: 1.0,
              explanation: "FCR is high → reducing feed.",
              confidenceScore: 0.82,
            );
            
            ref
                .read(smartFeedDebugProvider.notifier)
                .setFeedResult(result);
            
            // Navigate
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SmartFeedDebugScreen(data: result),
              ),
            );
          },
          child: const Text("View Debug Dashboard"),
        ),
      ],
    );
  }
}
```

## Integration with SmartFeedEngine

To integrate with the existing smart feed engine, update your feed calculation service:

```dart
import 'package:aqua_rythu/models/feed_result.dart';
import 'package:aqua_rythu/core/engines/smart_feed_engine.dart';

Future<FeedResult> calculateFeedWithDebug({
  required String pondId,
  required int doc,
}) async {
  // Your existing calculation
  final output = MasterFeedEngine.run(input);
  
  // Determine feed source
  final hasRecentSampling = input.abw != null;
  final source = hasRecentSampling ? FeedSource.biomass : FeedSource.doc;
  
  // Calculate biomass feed if applicable
  double? biomassFeed;
  if (hasRecentSampling) {
    // Use your biomass calculation
    biomassFeed = calculateBiomassFeed(input.abw, input.doc);
  }
  
  // Build explanation
  final explanation = _buildExplanation(
    fcrFactor: output.factors['fcr'],
    trayFactor: output.factors['tray'],
    growthFactor: output.factors['growth'],
    source: source,
  );
  
  // Calculate confidence score
  final confidenceScore = _calculateConfidence(
    fcrFactor: output.factors['fcr'],
    hasRecent Sampling: hasRecentSampling,
  );
  
  return FeedResult(
    finalFeed: output.finalFeed,
    source: source,
    docFeed: output.baseFeed, // DOC-based feed
    biomassFeed: biomassFeed,
    fcrFactor: output.factors['fcr'] as double?,
    trayFactor: output.factors['tray'] as double?,
    growthFactor: output.factors['growth'] as double?,
    explanation: explanation,
    confidenceScore: confidenceScore,
  );
}

String _buildExplanation({
  required double? fcrFactor,
  required double? trayFactor,
  required double? growthFactor,
  required FeedSource source,
}) {
  final parts = <String>[];
  
  if (source == FeedSource.biomass) {
    parts.add("• Biomass detected from last sampling");
  }
  
  if (fcrFactor != null && fcrFactor < 0.95) {
    parts.add("• FCR = ${(1 / fcrFactor).toStringAsFixed(2)} → Overfeeding risk");
    final reduction = ((1 - fcrFactor) * 100).toStringAsFixed(0);
    parts.add("• Feed reduced by $reduction%");
  }
  
  if (trayFactor != null && trayFactor > 1.0) {
    parts.add("• High tray leftover suggests adequate feeding");
  }
  
  return parts.join("\n");
}

double _calculateConfidence({
  required double? fcrFactor,
  required bool hasRecentSampling,
}) {
  double confidence = 0.7; // Base confidence
  
  if (hasRecentSampling) confidence += 0.1;
  if (fcrFactor != null) confidence += 0.05;
  if (fcrFactor != null && (fcrFactor - 1.0).abs() < 0.2) confidence += 0.05;
  
  return confidence.clamp(0.0, 1.0);
}
```

## Dashboard Features

### 1. Feed Summary Card
Shows today's final feed recommendation with mode indicator.

### 2. Feed Source Visualization
Visual indicator of DOC vs Biomass feed source with reason.

### 3. Feed Breakdown Card
Shows all calculation layers:
- DOC Feed (base)
- Biomass Feed (if available)
- FCR Adjustment
- Final Feed

### 4. Smart Factors Panel
Displays:
- 🟢 FCR Factor (Reducing feed)
- 🟡 Tray Factor (When available)
- 🔵 Growth Factor (Trend)
- Confidence Score

### 5. Decision Explanation
Natural language explanation of WHY specific feed was recommended.

### 6. Debug Logs
Collapsible section with raw calculation values for internal use.

## Premium Feature Note

As per the design, this dashboard is planned as a premium feature. To implement access control:

```dart
bool canAccessDebugDashboard(User user) {
  return user.isPremium || user.isInProMode;
}

// Hidden toggle: tap 5 times on dashboard title
int _titleTapCount = 0;

void onDashboardTitleTap() {
  _titleTapCount++;
  if (_titleTapCount >= 5) {
    // Enable pro/debug mode
    showDebugDashboardAccess = true;
  }
}
```

## Example Feed Result

```dart
FeedResult(
  finalFeed: 10.2,
  source: FeedSource.biomass,
  docFeed: 11.25,
  biomassFeed: 10.8,
  fcrFactor: 0.91,
  trayFactor: null, // Not yet tracked
  growthFactor: 1.0,
  explanation:
    "• Biomass detected from last sampling\n"
    "• FCR = 1.9 → Overfeeding risk\n"
    "• Feed reduced by 8%",
  confidenceScore: 0.82,
)
```

## Next Steps

1. ✅ Created FeedResult model and SmartFeedDebugScreen
2. ✅ Created provider for state management
3. 📋 Integrate with your SmartFeedEngine
4. 📋 Connect to your feed calculation service
5. 📋 Add navigation entry point (debug menu or farm screen)
6. 📋 Implement premium feature gate (if needed)
7. 📋 Add telemetry/logging for dashboard views
8. 📋 Design and implement 5-tap pro mode toggle

## File Structure

```
lib/
├── models/
│   └── feed_result.dart (NEW)
└── features/
    └── debug/
        ├── smart_feed_debug_provider.dart (NEW)
        └── smart_feed_debug_screen.dart (NEW)
        ├── debug_dashboard_screen.dart (existing)
        └── debug_feed_screen.dart (existing)
```
