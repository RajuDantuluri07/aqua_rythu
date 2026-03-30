# 🔍 AQUA RYTHU — 6-LAYER ARCHITECTURE AUDIT
**Date:** March 30, 2026 | **Status:** PRE-BACKEND | **CTO Assessment**

---

## EXECUTIVE SUMMARY
| Score | Category | Status |
|-------|----------|--------|
| **5/10** | Frontend UI/UX | ⚠️ **Partially Ready** |
| **6/10** | Feature Completeness | ⚠️ **Risky** |
| **7/10** | Core Logic | ✅ **Mostly Ready** |
| **4/10** | Business Logic | 🚨 **Not Ready** |
| **6/10** | Formula Correctness | ⚠️ **Risky** |
| **1/10** | Backend Readiness | 🚨 **Not Ready** |

**Overall: 4.8/10 — REQUIRES MAJOR WORK BEFORE LAUNCH**

---

# LAYER 1: FRONTEND UI/UX COMPLETENESS
**Score: 5/10** | Status: ⚠️ **Partially Ready**

## ✅ What Exists
- [✅] Splash/Auth screens (login, OTP, Google)
- [✅] Farm/Pond setup flow
- [✅] Dashboard with pond overview
- [✅] Pond-level dashboard with tabbed interface
- [✅] Feed schedule display
- [✅] Water quality test input screen
- [✅] Tray status logging UI
- [✅] Growth sampling screen
- [✅] Harvest tracking screen
- [✅] Supplement management UI
- [✅] Bottom navigation bar

## 🚨 CRITICAL GAPS

### 1. **Missing Real-Time Feed Execution Screens**
- ❌ "Today's Feeding" screen showing current recommended feed for TODAY
- ❌ Smart feed recalculation trigger (calls `getTodaySmartFeed()`)
- ❌ "Log actual feed consumed" per round (vs planned)
- ❌ Visual comparison: Planned vs Actual vs Smart recommendation
- ❌ Manual override UI for feed adjustments
- ⚠️ **Impact:** Users cannot see today's **smart-calculated** feeding plan in real-time

### 2. **Missing Analytics & Visualization**
- ❌ FCR tracking chart (Feed Conversion Ratio over time)
- ❌ Growth curve visualization (ABW trend)
- ❌ Feed consumption trend chart
- ❌ Water quality trend visualization
- ❌ Mortality rate trend
- ❌ Profitability dashboard
- ⚠️ **Impact:** No visibility into cycle performance

### 3. **Missing Alerts & Notifications**
- ❌ Critical water quality alerts (DO < 4, ammonia > threshold)
- ❌ Feed adjustment warnings
- ❌ Mortality alerts
- ❌ Feeding schedule reminders
- ⚠️ **Impact:** Silent failures possible

### 4. **Missing History/Audit Views**
- ❌ Feed adjustment history (why was feed reduced?)
- ❌ Water quality anomaly highlighting
- ❌ Tray status change patterns
- ❌ Event log/timeline
- ⚠️ **Impact:** Cannot troubleshoot past decisions

### 5. **UI/UX Issues**
- ⚠️ Tray description is WRONG: Shows "-8%" but engine uses -30% (inconsistency)
- ⚠️ No loading states during calculations
- ⚠️ No error handling UI for calculation failures
- ⚠️ Feed numbers displayed without context (kg? tons?)
- ⚠️ No "today's date" indicator on pond dashboard

## Must Fix (Before Backend)
- [ ] Create **"Today's Smart Feed"** screen showing recommended vs planned vs actual
- [ ] Fix tray status description labels (match engine constants: -30%, -15%, -5%, 0%)
- [ ] Add error boundaries for calculation failures
- [ ] Add loading indicators during engine processing
- [ ] Display units clearly (kg/day, ppm, °C)

## Optional Improvements (Can ship later)
- [ ] Charts/analytics (can use Chart.js/Fl_chart)
- [ ] Push notifications (can add Firebase)
- [ ] Detailed audit logs
- [ ] Dark mode support

---

# LAYER 2: FEATURE COMPLETENESS & FLOWS
**Score: 6/10** | Status: ⚠️ **Risky**

## ✅ Core Flows Implemented
- [x] Auth flow (OTP, Google)
- [x] Farm/Pond setup
- [x] Blind plan creation (120 days)
- [x] Sampling → Plan recalculation
- [x] Tray status logging
- [x] Water quality logging
- [x] Harvest recording
- [x] Supplement management
- [x] New cycle flow

## 🚨 CRITICAL MISSING FLOWS

### 1. **Smart Daily Feed Execution** 
- ❌ Trigger `getTodaySmartFeed()` at app startup
- ❌ Store result in state for today
- ❌ Re-trigger if water quality changes (mid-day)
- ❌ UI to accept/override smart recommendation
- **Impact:** Smart engine runs but never gets called from UI!

### 2. **Daily Feed Logging Flow**
- ❌ "Log actual feed given in Round X" capture
- ❌ Track variance (planned vs actual)
- ❌ Store `actualFeedYesterday` for next day's calculation
- ❌ Detect "missed round" condition
- **Status in code:** `FeedHistoryProvider` exists but INCOMPLETE
- **Impact:** Without logging actual feed, FCR engine has no yesterday data

### 3. **Tray Status → Feed Adjustment Flow**
- ❌ When tray status logged, automatically recalculate today's remaining rounds
- ❌ Show user the adjustment
- ❌ Example: "Trays full (30% reduction) → Round 3 reduced from 100kg to 70kg"
- ⚠️ **Current: Tray status logged but NOT connected to feed adjustment**

### 4. **Mortality Tracking & Impact**
- ❌ Daily mortality log screen
- ❌ Automatic adjustment when mortality > 2% recorded
- ❌ Alert if mortality spike detected
- ✅ Logic exists in `AdjustmentEngine` but NO UI to log it

### 5. **Multi-Pond Synchronization**
- ❌ No scenario where farm has 3+ active ponds
- ❌ Dashboard doesn't aggregate metrics across ponds
- ❌ No "compare ponds" view
- **Risk:** Untested scaling

### 6. **Cycle Completion Flow**
- ❌ End-of-cycle summary report generation
- ❌ Final harvest calculation
- ❌ Profitability calculation
- ❌ "Archive pond" → Enable next stocking
- ✅ `HarvestProvider` partial, needs backend integration

## Must Fix

### A. **BLOCKING: Implement Smart Feed Trigger**
```dart
// In pond_dashboard_screen.dart or new screen:
void _generateTodaySmartFeed() {
  final smartPlan = ref.read(feedPlanProvider.notifier).getTodaySmartFeed(
    pondId: pondId,
    doc: pond.doc,
    seedCount: pond.seedCount,
    // ... get water quality from waterProvider
    // ... get tray status from latest trayProvider
    // ... get mortality from????  ← MISSING
  );
  // Show UI with smart feed vs planned feed
}
```

### B. **BLOCKING: Feed Logging Screen**
Create `FeedActualLoggingScreen` that captures actual feed given per round.

### C. **BLOCKING: Mortality Logging**
Add mortality log to daily operations (currently NO UI).

## Can Fix Later
- [ ] Multi-pond aggregation
- [ ] Advanced cycle reports
- [ ] Export to Excel/PDF

---

# LAYER 3: CORE LOGIC CORRECTNESS
**Score: 7/10** | Status: ✅ **Mostly Ready**

## ✅ Working Correctly

### Feed Calculation Engine
```dart
✅ Survival rate interpolation (DOC-based)
✅ ABW standard curve fallback
✅ Feed % calculation based on weight (not just DOC)
✅ Biomass calculation: (seedCount * survival * weight) / 1000
✅ Per-round distribution: 0.8x, 1.0x, 1.0x, 1.2x
```

### Adjustment Engine
```dart
✅ Feeding score penalty logic
✅ Intake % adjustment
✅ Water quality critical stops (DO < 4 → 0% feed)
✅ Clamping to [0.5, 1.2] range
✅ Mortality-based reduction
```

### FCR Engine
```dart
❌ Correction factor based on historical FCR (OLD)
✅ Smooth scaling from 1.15x to 0.85x (FIXED)
✅ No harsh transitions between FCR ranges
✅ Clear business logic: reward efficiency, penalize waste
```

### Tray Engine
```dart
✅ Tray status aggregation (voting system)
✅ Safety capping [0.6x, 1.25x]
✅ Multiplier application: 0.7, 0.85, 0.95, 1.0
```

## 🚨 CRITICAL ISSUES

### 1. **Enforcement Engine is TOO SIMPLE**
```dart
// Current logic:
if (yesterdayActual > recommendedToday) {
  return recommendedToday * 0.90;  // Always 90%?
}
// PROBLEMS:
// - Only penalizes if yesterday OVERFEEDING
// - No reward if yesterday UNDERFEEDING
// - 90% factor is hardcoded
```

**Should be:**
```dart
// More proportional:
final deviation = yesterdayActual - recommendedToday;
if (deviation > 0) {
  return recommendedToday * max(0.7, 1.0 - (deviation / recommendedToday * 0.2));
} else if (deviation < -100) {  // Significant underfeeding
  return recommendedToday * min(1.3, 1.0 + abs(deviation) / recommendedToday * 0.1);
}
return recommendedToday;
```

### 2. **Master Engine Missing Safety Clamp After All Corrections**
```dart
// Current: Each engine applies independently
feed = baseFeed * adjustmentFactor;
feed = TrayEngine.apply(feed);  
feed = feed * fcrFactor;
feed = EnforcementEngine.apply(feed);

// PROBLEM: Multiple 0.7x multipliers could stack to 0.34x (too low)
// Should have final safety check:
feed = _clampToDailyLimit(feed);  // ← MISSING
```

### 3. **No State Validation Between Calls**
```dart
// getTodaySmartFeed() doesn't validate:
- Is pondId valid?
- Is doc > pond stocking date?
- Is seedCount > 0?
- Are water values in valid ranges?
- Does tray status list match numTrays?

// Should have:
void _validateInput(FeedInput input) {
  if (input.seedCount <= 0) throw Exception("Invalid seedCount");
  if (input.doc < 1 || input.doc > 120) throw Exception("Invalid doc");
  if (input.dissolvedOxygen < 0) throw Exception("Invalid DO");
  // ... etc
}
```

### 4. **Interpolation is Crude (Step-based)**
```dart
// Current _survivalRate():
if (doc >= 120) return survivalRates[120]!;
if (doc >= 90) return survivalRates[90]!;
// Returns same value for DOC 91-120
// Should interpolate:
static double _interpolateSurvival(int doc) {
  if (doc <= 1) return survivalRates[1]!;
  if (doc >= 120) return survivalRates[120]!;
  
  final points = [1,15,30,60,90,120];
  for (int i = 0; i < points.length - 1; i++) {
    if (doc >= points[i] && doc <= points[i+1]) {
      final t = (doc - points[i]) / (points[i+1] - points[i]);
      return survivalRates[points[i]]! + 
             t * (survivalRates[points[i+1]]! - survivalRates[points[i]]!);
    }
  }
  return survivalRates[120]!;
}
```

### 5. **State Management is Fragile**
```dart
// All data stored in Riverpod StateNotifier
// Problem: App restart = data loss
// Solution: MISSING integration with Supabase
```

## Must Fix
- [ ] Improve EnforcementEngine proportionality
- [ ] Add final safety clamp in MasterFeedEngine
- [ ] Add input validation function
- [ ] Implement linear interpolation for curves
- [ ] Add state persistence (Supabase)

## Can Fix Later
- [ ] Non-linear interpolation splines
- [ ] Seasonal adjustment models

---

# LAYER 4: BUSINESS LOGIC VALIDATION
**Score: 4/10** | Status: 🚨 **Not Ready**

## ⚠️ Major Issues

### 1. **Blind Feeding Period Not Properly Handled**
```dart
// createPlan() creates 120 days immediately
// But PRD says: "Only first 30 days are blind"
// After sampling, all future days should recalculate

✅ recalculatePlan() exists
❌ But when does sampling happen? 
❌ On day 30 automatically? User-triggered?
❌ What if user samples on day 20?
❌ What if user never samples?
```

**Missing:** Business rule for "when to recalculate"

### 2. **Feed Jump Threshold Not Enforced**
```dart
// FarmSettings has: feedJumpThreshold = 30%
// But EnforcementEngine doesn't use it!

// Should prevent:
Day 1 feed: 50 kg
Day 2 feed: 65 kg (30% jump) ← Should be capped at 50 * 1.30 = 65 ✓
Day 2 feed: 100 kg (100% jump) ← Should be capped at 50 * 1.30 = 65 ✗

// Current code: EnforcementEngine only looks at yesterday's ACTUAL
// Doesn't enforce jump threshold
```

### 3. **Mortality Business Logic is INCOMPLETE**
```dart
// AdjustmentEngine applies -20% if mortality > 0
// But real question:
- Is mortality per day?
- Is it cumulative?
- 1% mortality per day is different from 1% total!
- If seed count was 100k and 500 died, is that "mortality"?
- Should recalculate survival rate based on actual mortality?
```

**Missing:** Definition of mortality input format

### 4. **Tray Status Feedback Loop is Manual**
```dart
// User logs tray status → Engine adjusts feed
// But how often should user check trays?
// Current: User must manually log each round
// Better: "Expected time to log: 5 mins before next round"

// No business rule checking:
- Did user log tray for every round?
- 2 hours late for tray check (missed adjustment window)?
- No flag for "missed tray check"
```

### 5. **Water Quality Urgency Not Rated**
```dart
// DO < 4 → Stop feeding (correct)
// But what about:
DO = 4.1 → Some reduction? (current: -30%)
DO = 3.5 → Emergency stop? (current: 0%)
DO = 5.0 → Monitor? (current: -10%)

// These are reasonable but NOT documented
// Should have clear SOP:
```

### 6. **Survival Rate Assumptions are Conservative**
```dart
// Constants assume:
DOC 1: 98% survival
DOC 30: 93% survival
DOC 120: 80% survival

// But what if actual survival is 95% at DOC 30?
// Fish weigh less → Feed should be LESS
// But seeds were already bought at 98% assumption
// This creates tension between plan and reality

// Better: Allow users to adjust survival rate after stocking
```

### 7. **No Business Rules for Intensive vs Semi-Intensive**
```dart
// FarmSettings.farmType = "Semi-Intensive" | "Intensive"
// But:
❌ Feed % calculation doesn't change
❌ Tray multipliers don't change
❌ Water quality thresholds partially change (in WaterProvider)
❌ But NOT in AdjustmentEngine

// Should have:
if (settings.farmType == "Intensive") {
  ammThreshold = 0.2;  // Stricter
  doThreshold = 4.5;   // Stricter
} else {
  ammThreshold = 0.4;
  doThreshold = 3.5;
}
```

### 8. **FCR Averaging Period is Unclear**
```dart
// FCREngine takes cumulative FCR
// But over what time period?
// - Last 30 days?
- Entire cycle?
- Last 3 harvests?

// If cumulative for whole cycle:
// FCR on day 60 = some value
// FCR on day 120 = different value
// Should be historical FCR WITH defined averaging window
```

## Must Fix (Business Blocking)

1. **Define Blind Feeding Trigger**
   ```dart
   // Rule: "Recalculate on Day 30 automatically OR when user samples"
   ```

2. **Implement Jump Threshold in Enforcement**
   ```dart
   // Rule: "Daily feed change capped at ±30%"
   ```

3. **Define Mortality Input Format**
   ```dart
   // Is it: per day? cumulative in pond? 
   // How to represent: count? percentage?
   ```

4. **Enforce Farm Type in Adjustment Engine**
   ```dart
   // Semi-Intensive vs Intensive must adjust thresholds
   ```

5. **Document FCR Averaging Period**
   ```dart
   // "Use 30-day rolling average" OR "Use entire cycle"?
   ```

## Optional (Can Fix in V2)
- [ ] Severity rating system for alerts
- [ ] Tray logging time windows
- [ ] Predictive alerts based on trends

---

# LAYER 5: FORMULA CORRECTNESS
**Score: 6/10** | Status: ⚠️ **Risky**

## ✅ Formulas That Look Correct

### Biomass Calculation
```
Biomass = (seedCount × survival_rate × abw) / 1000
Units: kg
Logic: ✅ Correct
```

### Daily Feed  
```
Daily_Feed = Biomass × Feed%
Feed% = f(ABW)  [self-adjusting based on size]
Logic: ✅ Correct
```

### Tray Aggregation (Voting)
```dart
// Correct weighted scheme:
if (fullCount ≥ 2) → Full (heavy leftovers)
if (emptyCount ≥ 2) and !(fullCount ≥ 2) → Empty
else → Partial
Logic: ✅ Mostly correct (but see below)
```

## 🚨 PROBLEMATIC FORMULAS

### 1. **FCR Correction is Now Correct** ✅ FIXED
```dart
// OLD (backwards):
FCR ≤ 1.2: correction = 1.0x (no change)
FCR ≤ 1.4: correction = 0.95x (reduce 5%)
FCR > 1.4: correction = 0.85x (reduce 15%)

// ✅ NEW (production-ready with smooth scaling):
FCR ≤ 1.0: correction = 1.15x (+15%, exceptional)
FCR ≤ 1.2: correction = 1.10x (+10%, very good)
FCR ≤ 1.3: correction = 1.05x (+5%, good)
FCR ≤ 1.4: correction = 1.00x (no change, acceptable)
FCR ≤ 1.5: correction = 0.90x (-10%, poor)
FCR > 1.5: correction = 0.85x (-15%, wasteful)

// With final safety clamp:
feed = feed.clamp(baseFeed * 0.6, baseFeed * 1.3)
```

**Why this is better:**
- ✅ Smooth transitions (no sudden jumps)
- ✅ Rewards efficiency (inverse relationship)
- ✅ Penalizes waste (proportional)
- ✅ Final clamp prevents multiplier stacking
- ✅ Farmer trust: predictable behavior


### 2. **Clamp Ranges are Too Narrow**
```dart
// AdjustmentEngine clamps to [0.5, 1.2]
// This means:
baseFeed = 100kg
Min possible = 50kg  (-50%)
Max possible = 120kg (+20%)

// But with multiple penalties stacking:
baseFeed * 0.7 (tray) * 0.8 (fcr?) * 0.9 (enforcement)
= baseFeed * 0.504  (50.4%)

// Is this intentional?
// Should probably clamp to [0.6, 1.3]
```

### 3. **Tray Adjustment Safety Caps Are Not in MasterEngine**
```dart
// TrayEngine applies [0.6x, 1.25x]
// But then what?
feed = TrayEngine.apply(200);  // Returns [120, 250]
feed = feed * fcrFactor * enforcementFactor;  // Could go below 0.6x

// Should re-clamp after all corrections:
feed = _clampToDaily(feed, minFactor: 0.6, maxFactor: 1.3);
```

### 4. **Feeding Score Penalties Have No Basis**
```dart
if (feedingScore >= 4) factor += 0.05;   // +5%
if (feedingScore == 3) factor -= 0.10;   // -10%
if (feedingScore <= 2) factor -= 0.25;   // -25%

// Question: Why these exact numbers?
// Where do they come from?
// Should be in PRD with justification
// Is 3 vs 3.5 different? (no, just 3)
```

### 5. **Intake % Thresholds Not Calibrated**
```dart
if (intakePercent > 95) factor += 0.05;  // "Exceptional eaters"
if (intakePercent < 85) factor -= 0.10;  // "Slow eaters"
if (intakePercent < 70) factor -= 0.25;  // "Very slow eaters"

// Are these based on:
// - Historical data?
// - Aquaculture research?
// - Guesswork?
// Need justification!
```

### 6. **Ammonia Thresholds Vary by Farm Type But Inconsistently**
```dart
// In WaterProvider:
const ammThreshold = isSemiIntensive ? 0.4 : 0.3;

// In AdjustmentEngine:
if (input.ammonia > 0.1) factor -= 0.20;

// These are DIFFERENT thresholds!
// 0.1 vs 0.3/0.4
// Which is correct?
```

## Must Fix (Math Blocking)

- [ ] **REVERSE FCR Logic** (this is a critical bug!)
- [ ] Add final clamp in MasterEngine
- [ ] Justify feeding score & intake % thresholds
- [ ] Align ammonia thresholds (0.1, 0.3, 0.4)
- [ ] Document why tray cap is [0.6, 1.25]

## Can Fix Later
- [ ] Non-linear adjustment curves
- [ ] Seasonal corrections
- [ ] Species-specific adjustments

---

# LAYER 6: BACKEND READINESS
**Score: 1/10** | Status: 🚨 **NOT READY**

## Current State: ZERO PERSISTENCE
```
✅ Auth: Supabase login/OTP works
❌ Database: NO schema
❌ Persistence: Only local Riverpod + SharedPreferences (lost on app delete)
❌ Sync: No multi-device sync
❌ Backup: No backup
```

## What's Missing for Supabase Integration

### 1. **NO DATABASE SCHEMA**
```sql
-- Required tables:
users (id, phone, email, created_at)
farms (id, user_id, name, location)
ponds (id, farm_id, name, area, stocking_date, seed_count, pl_size, num_trays, current_abw, total_mortality)

-- Feed tracking:
feed_plans (id, pond_id, doc, planned_total, smart_total, created_at)
feed_logs (id, pond_id, doc, round, planned_qty, actual_qty, timestamp)

-- Water quality:
water_logs (id, pond_id, doc, ph, do, ammonia, salinity, alkalinity, nitrite, timestamp)

-- Growth sampling:
sampling_logs (id, pond_id, doc, weight_kg, count_groups, pieces_per_group, avg_body_weight, timestamp)

-- Tray status:
tray_logs (id, pond_id, doc, round, tray_statuses, observations, timestamp)

-- Harvest:
harvest_entries (id, pond_id, doc, quantity_kg, count_per_kg, price_per_kg, expenses, notes, type, timestamp)

-- Mortality:
mortality_logs (id, pond_id, doc, count, percentage, notes, timestamp)  ← Currently no UI/DB!

-- Supplements (partial):
supplement_logs (id, pond_id, doc, round, supplement_id, quantity, timestamp)
```

### 2. **NO DATA SYNC STRATEGY**
```dart
// Current:
- Data stored locally in Riverpod
- No upload to Supabase
- No multi-device sync
- App restart = potential data loss

// Needed:
- Auto-upload to Supabase after each log entry
- Conflict resolution strategy
- Offline queue for failed uploads
- Periodic sync check
```

### 3. **NO PERSISTENCE REPOSITORIES**
```dart
// Need to create:
UserRepository (read/update user profile)
FarmRepository (CRUD farms)
PondRepository (CRUD ponds, read by id/farm_id)
FeedLogRepository (write logs, read history)
WaterLogRepository (write logs, read history)
SamplingRepository (write logs, query trends)
TrayLogRepository (write logs, get latest)
HarvestRepository (write logs, calculate totals)

// Each with methods:
Future<List<T>> getAll(String userId);
Future<T> getById(String id);
Future<T> create(T item);
Future<void> update(T item);
Future<void> delete(String id);
```

### 4. **NO MIGRATIONS / VERSIONING**
```dart
// If schema changes:
// - What happens to old data?
// - How to rollback?
// Need:
// - Database versioning
// - Migration scripts
// - Version checks in app
```

### 5. **NO SECURITY / ROW LEVEL SECURITY**
```sql
-- Need Supabase RLS policies:
CREATE POLICY "Users can only access their own farms"
ON farms
FOR SELECT
USING (auth.uid() = user_id);

-- For all tables: water_logs, feed_logs, etc.
-- Current: NO protection! Any user could fetch others' data!
```

### 6. **NO ANALYTICS / LOGGING**
```dart
// Need to track:
- Feed adjustments made by engine
- Why each adjustment (reason codes)
- User manual overrides
- Calculation errors/failures
- Performance metrics

// Current: Silent calculations, no audit trail!
```

### 7. **CREDENTIALS ARE HARDCODED**
```dart
// In main.dart:
const url = 'https://qzubiqetvsgaiwhshcex.supabase.co';
const anonKey = 'sb_publishable_vR-960VzTfuvGZeac79JVQ_XWtj2OPL';

// SECURITY ISSUE: Public key exposed in source code!
// Should use:
// - Environment variables (.env)
// - Secrets management (GitHub, Firebase)
```

## Must Fix (Blocking)

### PHASE 1: Data Persistence (Week 1)
1. **Create Supabase schema** (all tables listed above)
2. **Create Repository classes** (CRUD for each entity)
3. **Wire up Riverpod to repositories** (notify when remote data changes)
4. **Implement sync strategy** (auto-upload on-data-change)

### PHASE 2: Security (Week 2)
1. **Add RLS policies** (users see only their data)
2. **Move credentials to env vars** (never hardcode secrets)
3. **Add data validation** (inputs to database)
4. **Add audit logging** (track all changes)

### PHASE 3: Error Handling (Week 3)
1. **Network error recovery** (offline mode)
2. **Conflict resolution** (race conditions)
3. **Data versioning** (track schema changes)
4. **Monitoring/alerting** (errors to backend)

## Optional (Can do V2)
- [ ] ElasticSearch for analytics
- [ ] Real-time sync (PostgreSQL subscriptions)
- [ ] Data export/backup tools
- [ ] Admin dashboard

---

# COMPREHENSIVE ISSUE SUMMARY

## 🚨 CRITICAL (MUST FIX BEFORE LAUNCH)

| # | Issue | Layer | Impact | Status |
|---|-------|-------|--------|--------|
| ~~1~~ | ~~FCR Logic is Backwards~~ | Formula | ~~Wrong feed adjustment~~ | ✅ **FIXED** |
| 2 | **No Smart Feed Trigger from UI** | Feature | Smart engine never called | ⏳ TODO |
| 3 | **No Feed Logging UI** | Feature | Actual intake never recorded | ⏳ TODO |
| 4 | **No Mortality Logging** | Feature | Mortality impacts ignored | ⏳ TODO |
| 5 | **No Database Schema** | Backend | Data persists on restart only | ⏳ TODO |
| 6 | **No Repository Layer** | Backend | Cannot upload to Supabase | ⏳ TODO |
| 7 | **Credentials Hardcoded** | Backend | Security breach | ⏳ TODO |
| 8 | **No RLS Policies** | Backend | Users can see others' data | ⏳ TODO |
| 9 | **Enforcement Engine Too Simple** | Logic | Feed caps don't scale | ⏳ TODO |
| 10 | **Feed Jump Threshold Not Enforced** | Business | 100% jumps possible | ⏳ TODO |

**Remaining Critical Fix Time: ~51 hours (~6-7 days)** *(down from 52 hours)*

---

## ⚠️ HIGH (SHOULD FIX BEFORE MVP)

| # | Issue | Layer | Impact | Fix Time |
|---|-------|-------|--------|----------|
| 11 | Ammonia thresholds inconsistent | Business | Wrong feed adjustments | 1 hour |
| 12 | Interpolation is step-based | Logic | Inaccurate curves | 3 hours |
| 13 | No input validation | Logic | Bad data crashes engine | 2 hours |
| 14 | Tray UI labels wrong (-8% vs -30%) | UI | Confuses users | 1 hour |
| 15 | No blind feeding rule | Business | Can recalculate too early | 2 hours |
| 16 | Missing state validation | Logic | Fragile to edge cases | 3 hours |

**Total High Priority: 12 hours**

---

## 📋 MEDIUM (CAN FIX IN V1.1)

| # | Issue | Description |
|---|-------|-------------|
| 17 | No analytics charts | Feed trends invisible |
| 18 | No alert system | Silent failures possible |
| 19 | Survival rate assumptions conservative | Users can't override |
| 20 | Farm type not used in Adjustment | Intensive ponds same as semi |
| 21 | No multi-pond aggregation | Can't compare ponds |
| 22 | No cycle reports | No profitability view |

**Total Medium: 20+ hours**

---

## 🎯 WHAT WILL BREAK IN PRODUCTION

```
Scenario 1: User has 1.1 FCR (excellent efficiency)
  → ✅ Engine now INCREASES feed by 10% (CORRECT!)
  → Fish get optimal nutrition
  → Growth excellent
  → User happy ✓

Scenario 2: Water DO drops to 4.5 ppm mid-day
  → No real-time alert
  → User doesn't see smart feed recommendation change
  → Continues planned feeding
  → Fish stressed, mortality spikes

Scenario 3: User logs tray status (full)
  → Engine handles adjustment internally
  → But UI never shows "Feed reduced to 70kg today"
  → User gives 100kg anyway
  → Inconsistency

Scenario 4: App crashes on day 45
  → All farm data lost (no Supabase backup)
  → Can only recover from local SharedPreferences
  → 30 days of history gone

Scenario 5: Farm has 3 ponds
  → Filter/search across ponds is missing
  → Cannot compare performance
  → Cannot see which pond has problem
```

---

# RECOMMENDATIONS FOR LAUNCH

## If Target is "Internal Beta" (Team/Friends)
- [ ] Fix FCR logic (CRITICAL)
- [ ] Implement smart feed trigger
- [ ] Add feed logging
- [ ] Deploy basic Supabase backend (CRITICAL)
- **Timeline: 10 days**

## If Target is "Limited Public Release" (< 100 farmers)
- [ ] All CRITICAL fixes
- [ ] All HIGH fixes
- [ ] Basic analytics
- [ ] Error handling UI
- **Timeline: 3 weeks**

## If Target is "Full Public Release"
- [ ] All above
- [ ] Alert system
- [ ] Multi-device sync
- [ ] Comprehensive testing
- [ ] Documentation
- **Timeline: 6-8 weeks**

---

# STRENGTHS TO RETAIN

✅ **Clean architecture** - Engines are modular
✅ **Good state management** - Riverpod used correctly
✅ **Math heavy** - Formula-based (not rule-based)
✅ **Business-aware** - UX targets farmers
✅ **Type-safe** - Dart typing prevents runtime errors
✅ **Extensible** - Easy to add new engines

---

# NEXT STEPS

## ✅ COMPLETED
- [x] Fix FCR logic backwards bug (Reversed + smooth scaling model added)
- [x] Add safety clamp in MasterFeedEngine [0.6x, 1.3x]
- [x] Integrate SmartFeedProvider into pond dashboard
- [x] Create SmartFeedRoundCard component (Planned vs Smart vs Actual)
- [x] Enhanced FeedHistoryProvider to track smart feed recommendations
- [x] Wire "Mark as Fed" callback to log smart feed data
- [x] Implement real-time feed recommendation display with reasons

## 🚀 IN PROGRESS
- [ ] Create mortality logging screen (blocks adjustment engine)
- [ ] Calculate FCR from historical data (currently placeholder)
- [ ] Create feed override history view

## 2. **NEXT WEEK:**
   - [ ] Create Supabase schema (ponds, feed_logs, water_logs, etc.)
   - [ ] Build Repository layer (CRUD operations)
   - [ ] Migrate SharedPreferences to Supabase
   - [ ] Add RLS policies (users see only their data)

## 3. **TODO:**
   - [ ] Run on real farm device
   - [ ] Test all 120-day cycle
   - [ ] Load test with 10+ ponds
   - [ ] Security audit

---

**END OF AUDIT**
Generated: March 30, 2026 | CTO Assessment
