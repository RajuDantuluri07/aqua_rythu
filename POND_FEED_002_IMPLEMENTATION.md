# POND-FEED-002 — Multi-Stage Feed Breakdown System

**Status**: ✅ IMPLEMENTED  
**Date**: 2026-05-05  
**Feature**: Phased Feed Breakdown display based on DOC and data availability

---

## Overview

Implements progressive intelligence disclosure for the pond dashboard:
- **DOC 1-14**: No breakdown shown (too early)
- **DOC 15-30 + tray data**: BASIC mode (tray-only factors)
- **DOC 30+ OR sampling data**: ADVANCED mode (full factor pipeline)

This prevents fake intelligence perception while enabling early farmer engagement and building trust for PRO conversion.

---

## Implementation Details

### 1. New Component: `BasicFeedBreakdownCard`

**File**: `lib/features/feed/widgets/feed_breakdown_card_basic.dart`

Shows simplified breakdown for early-stage ponds:
- **Base Feed** — foundational calculation from seed table
- **Tray Adjustment** — single factor showing leftover response
- **Final Feed** — resulting recommendation

**Title**: "Feed Adjustment (Tray Based)" — emphasizes farmer control

### 2. Existing Component: `FeedBreakdownCard` (renamed mentally as "Advanced")

Remains unchanged, used for DOC > 30:
- Base Feed
- Tray Adjustment
- Smart Adjustment
- Final Feed
- Savings banner (if applicable)

**Title**: "Feed Breakdown" — full pipeline visibility

### 3. Conditional Rendering Logic

**File**: `lib/features/pond/pond_dashboard_screen.dart` (line ~1593)

```dart
// POND-FEED-002: Multi-Stage Feed Breakdown System
// DOC 15-30 + tray data: BASIC mode (tray-only factors)
// DOC > 30 OR sampling data: ADVANCED mode (full factor pipeline)
if (currentDoc >= 15 && hasTrayData)
  BasicFeedBreakdownCard(explanation: seedExplanation)
else if (currentDoc > 30 || growthLogs.isNotEmpty)
  FeedBreakdownCard(explanation: seedExplanation)
```

**Conditions**:
1. **BASIC mode**: `currentDoc >= 15 AND hasTrayData == true`
2. **ADVANCED mode**: `currentDoc > 30 OR growthLogs.isNotEmpty`
3. **NO breakdown**: Neither condition met

---

## Data Flow

```
Pond Dashboard
  ├─ Calculate hasTrayData (line 1071)
  │   └─ trayLogs.any((l) => !l.isSkipped && l.trays.isNotEmpty)
  │
  ├─ Fetch growthLogs (from Firestore)
  │   └─ List<SamplingLog> growthLogs
  │
  ├─ Build seedExplanation (line 1114)
  │   └─ SeedFeedEngine.buildExplanation(...)
  │
  └─ Render Feed Breakdown (line 1593)
      ├─ IF currentDoc >= 15 AND hasTrayData
      │   └─ BasicFeedBreakdownCard
      │
      └─ ELSE IF currentDoc > 30 OR growthLogs.isNotEmpty
          └─ FeedBreakdownCard
```

---

## User Journey

### Phase 1: Early Days (DOC 1-14)
- **No breakdown shown** — too early for meaningful tray signal
- User focuses on: feeding schedule, tray tracking, growth

### Phase 2: Early Intelligence (DOC 15-30)
- **BASIC mode activated** when tray data exists
- Shows: "Your trays are [full/partial/empty]... adjust to X kg"
- Builds trust: "I see your trays, I'm adapting"
- **Conversion signal**: Early PRO users see this working

### Phase 3: Advanced Insights (DOC 30+)
- **ADVANCED mode activated** automatically
- Shows: Base + Tray + Smart adjustments
- New value: sampling data, growth signals
- **PRO value proposition**: "See ALL the factors working together"

---

## UI Differences

### BASIC Mode (DOC 15-30)
```
┌─────────────────────────────────────┐
│ 🎯 Feed Adjustment (Tray Based)  D  │
├─────────────────────────────────────┤
│ 🍽️  Base Feed                3.6 kg │
│    Hatchery table · DOC 20          │
│                                     │
│ 📊 Tray Adjustment            +10%  │
│    Trays are partially full         │
├─────────────────────────────────────┤
│ ✅ Final Feed Today           3.96 kg│
└─────────────────────────────────────┘
```

### ADVANCED Mode (DOC 30+)
```
┌─────────────────────────────────────┐
│ 🎯 Feed Breakdown                DOC │
├─────────────────────────────────────┤
│ 🍽️  Base Feed                X.X kg │
│ 📊 Tray Adjustment          ±X%    │
│ 🧠 Smart Adjustment         ±X%    │
├─────────────────────────────────────┤
│ ✅ Final Feed Today           X.X kg │
│ 🎉 Saved ₹XXX today               │
└─────────────────────────────────────┘
```

---

## Testing Checklist

- [ ] DOC 1-14: No breakdown shown (tray data present)
- [ ] DOC 15-30 + tray data: BASIC card shown
- [ ] DOC 15-30 no tray: No breakdown (yet)
- [ ] DOC 31 (no sampling): No advanced breakdown
- [ ] DOC 31 + sampling: ADVANCED card shown
- [ ] Tray data arrives DOC 16: BASIC appears
- [ ] Sampling data arrives DOC 25: No change (still BASIC)
- [ ] Sampling data arrives DOC 32: ADVANCED shows

---

## Files Modified

1. **Created**:
   - `lib/features/feed/widgets/feed_breakdown_card_basic.dart` — new component

2. **Updated**:
   - `lib/features/pond/pond_dashboard_screen.dart`
     - Added import for `BasicFeedBreakdownCard`
     - Replaced unconditional `FeedBreakdownCard` with conditional logic (lines ~1593-1596)

3. **Unchanged**:
   - `lib/features/feed/widgets/feed_breakdown_card.dart` — fully backward compatible

---

## Business Impact

### Conversion Funnel
1. **Blind Phase (DOC 1-14)**: Basic feeding, no breakdown
2. **Tray Recognition (DOC 15-30)**: See "I'm adapting to your trays" → Trust ✓
3. **Smart Phase (DOC 30+)**: Full intelligence visible → Value ✓
4. **PRO Decision**: "Do I upgrade to see sampling insights?"

### Prevents
- ❌ Showing fake intelligence before DOC 30
- ❌ Claiming smart adjustments without sampling data
- ❌ Overwhelming new farmers with complexity

### Enables
- ✅ Early trust-building (DOC 15)
- ✅ Progressive value disclosure
- ✅ Natural PRO conversion narrative

---

## Future Enhancements

1. **DOC 15-30**: Optional adjustment factors (mortality, manual override)
2. **Confidence badges**: "Tray-based" vs "Data-backed" labels
3. **Explanation tooltips**: Why this adjustment? Where's the data?
4. **A/B testing**: Does BASIC mode improve PRO conversion vs. no breakdown?

---

## Notes

- **Backward compatible**: Existing `FeedBreakdownCard` unchanged
- **No API changes**: Uses existing `hasTrayData` and `growthLogs`
- **Phased rollout**: Can monitor BASIC → ADVANCED transition metrics
- **Opt-out ready**: Comment out conditional to revert to always-show behavior
