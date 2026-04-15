# Engine Architecture Archive

**Last Cleanup:** April 15, 2026

This folder contains archived and deprecated engine implementations that have been superseded by newer code. Do NOT use code in this folder for new development.

---

## Archived Files & Why

### 1. `feed_calculation_engine_v0.dart`
**Status:** DEPRECATED  
**Archived:** April 15, 2026  
**Reason:** Thin wrapper around `FeedingEngineV1.calculateFeed()`  
**Was used by:** `MasterFeedEngine`  
**Replacement:** Use `FeedingEngineV1.calculateFeed()` directly

**What it did:**
```dart
class FeedCalculationEngine {
  static double calculateFeed({...}) {
    return FeedingEngineV1.calculateFeed(...);
  }
}
```

**Impact of removal:** None — direct call to FeedingEngineV1 is faster and clearer

---

### 2. `tray_engine_v0.dart`
**Status:** DEAD CODE  
**Archived:** April 15, 2026  
**Reason:** Not called anywhere in codebase  
**Was a thin wrapper:** around `FeedStateEngine.applyTrayAdjustment()`  
**Replacement:** Use `SmartFeedEngine` for active tray-based feed adjustment

**What it did:**
```dart
class TrayEngine {
  static double apply(List<TrayStatus>, double feed, dynamic mode) {
    return FeedStateEngine.applyTrayAdjustment(...);
  }
}
```

**Impact of removal:** None — no code imported it

---

### 3. `feed_state_engine_v0.dart`
**Status:** LEGACY PIPELINE  
**Archived:** April 15, 2026  
**Reason:** Replaced by `SmartFeedEngine` in the current feed adjustment flow  
**Was used by:** Only `TrayEngine` (which is also archived)  
**Replacement:** Use `SmartFeedEngine.getFeedMode()` instead

**Key differences from current system:**
| Aspect | Old (FeedStateEngine) | New (SmartFeedEngine) |
|--------|------------------------|----------------------|
| **Enum name** | `FeedMode { blind, transitional, smart }` | `FeedMode { normal, trayHabit, smart }` |
| **Naming** | Older UI/UX terminology | Better semantic meaning |
| **Active?** | ❌ NO — replaced | ✅ YES — current system |
| **Called by** | TrayEngine only | SmartFeedEngine, dashboard logic |

**What `FeedStateEngine` did:**
- Determined feed phase based on DOC and smart feed settings
- Managed feed round state (locked, done, tray required, etc.)
- Applied tray adjustments

**Now handled by:** `SmartFeedEngine.getFeedMode()` + `FeedFactorEngine`

---

## Current Active Feed Architecture

```
ENTRY POINT:
SmartFeedEngine.applyTrayAdjustment()
  ↓
CONTEXT BUILD:
FeedInputBuilder.fromDB()
  ↓
ORCHESTRATION:
MasterFeedEngine.run()
  ├─ Base feed: FeedingEngineV1.calculateFeed()
  ├─ Tray factor: FeedFactorEngine.calculateTrayFactor()
  ├─ Growth factor: FeedFactorEngine.calculateGrowthFactor()
  ├─ Sampling factor: FeedFactorEngine.calculateSamplingFactor()
  ├─ Environment factor: FeedFactorEngine.calculateEnvironmentFactor()
  └─ Enforcement: EnforcementEngine.apply()
  ↓
OUTPUT:
FeedOutput { baseFeed, recommendedFeed, factors, reasons }
  ↓
STORAGE:
Update feed_rounds table for next 3 DOCs
```

---

## Migration Guide for Archived Code

If you find any old code referencing these archived files:

### OLD: Using `FeedCalculationEngine`
```dart
// ❌ OLD (ARCHIVED)
import 'feed_calculation_engine.dart';

final feed = FeedCalculationEngine.calculateFeed(
  seedCount: 100000,
  doc: 30,
  stockingType: 'nursery',
);
```

### NEW: Use `FeedingEngineV1` directly
```dart
// ✅ NEW (DO THIS)
import 'feeding_engine_v1.dart';

final feed = FeedingEngineV1.calculateFeed(
  doc: 30,
  stockingType: 'nursery',
  density: 100000,
  leftoverPercent: null,
);
```

---

### OLD: Using `TrayEngine`
```dart
// ❌ OLD (ARCHIVED)
import 'tray_engine.dart';
import 'feed_state_engine.dart';

final adjustedFeed = TrayEngine.apply(trayStatuses, baseFeed, mode);
```

### NEW: Use `SmartFeedEngine`
```dart
// ✅ NEW (DO THIS)
import 'smart_feed_engine.dart';

// SmartFeedEngine handles both tray evaluation AND feed adjustment
await SmartFeedEngine.applyTrayAdjustment(
  pondId: pondId,
  doc: doc,
  trayStatus: trayStatus,
);
```

---

### OLD: Using `FeedStateEngine`
```dart
// ❌ OLD (ARCHIVED)
import 'feed_state_engine.dart';

final mode = FeedStateEngine.getMode(doc, isSmartFeedEnabled: true);
final state = FeedStateEngine.getRoundState(...);
```

### NEW: Use `SmartFeedEngine.getFeedMode()`
```dart
// ✅ NEW (DO THIS)
import 'smart_feed_engine.dart';

final mode = SmartFeedEngine.getFeedMode(doc);
// Returns: FeedMode { normal, trayHabit, smart }
```

---

## Cleanup Statistics

**Files Archived:** 3  
**Lines of Code Removed from Active** codebase: ~200  
**Imports Updated:** 1 (in `master_feed_engine.dart`)  
**Active References Deleted:** 0 (all usages replaced)  

**Code Clarity Improvement:** HIGH  
- ✅ Single source of truth for feed calculation (FeedingEngineV1)
- ✅ No redundant wrappers (FeedCalculationEngine deleted)
- ✅ No dead code (TrayEngine deleted)
- ✅ Single feed mode enum per system (FeedStateEngine deprecated)

---

## How to Fully Remove These Files

Once confident in the refactoring (after testing):

```bash
# Delete the original files from active code
rm lib/core/engines/feed_calculation_engine.dart
rm lib/core/engines/tray_engine.dart
rm lib/core/engines/feed_state_engine.dart

# Commit the archive cleanup
git add lib/core/engines/_archive/
git commit -m "archive(engines): Move deprecated feed engines to _archive/

- feed_calculation_engine_v0: thin wrapper around FeedingEngineV1
- tray_engine_v0: not called anywhere  
- feed_state_engine_v0: replaced by SmartFeedEngine

MasterFeedEngine now uses FeedingEngineV1 directly instead of wrapper.
No functional change, improves code clarity."
```

---

## Review Checklist

- [ ] All imports updated (MasterFeedEngine)
- [ ] Tests passing (no code broke)
- [ ] Dashboard still shows feed correctly
- [ ] Tray adjustment still works (via SmartFeedEngine)
- [ ] No console errors about missing imports
- [ ] Code review approved (team review)

Once checked, DELETE the original files (see "How to Fully Remove" above).

---

**Architecture Owner:** Engineering Team  
**Last Review:** April 15, 2026  
**Next Review:** When new feed logic added  
