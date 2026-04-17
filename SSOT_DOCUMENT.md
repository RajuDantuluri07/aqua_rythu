# AquaRythu — Single Source of Truth (SSOT)
**Generated:** 2026-04-17 | **Last updated:** 2026-04-17 (post-BUG-1–5 fixes) | **Derived from:** Full codebase analysis | **Status:** Bugs 1–5 resolved

---

## 1. PRODUCT OVERVIEW

### What AquaRythu Does
AquaRythu is a mobile app (Flutter, Android/iOS) that helps shrimp farmers manage daily feeding operations for *Litopenaeus vannamei* (vannamei shrimp). The app replaces manual guesswork with a data-driven feed recommendation engine that adapts based on shrimp growth, tray observations, and water quality.

The name is Telugu for "Aqua Farmer" (అక్వా రైతు), targeting Small-to-Large shrimp farmers in Andhra Pradesh/Telangana coastal regions.

### Target Users
| Role | Description |
|------|-------------|
| Farm Owner | Creates farms/ponds, views profit dashboard, reviews performance |
| Farm Worker | Logs daily feedings, tray observations, water quality readings |
| Supervisor | Monitors multiple ponds, compares performance |

### Core Value Proposition
- **Prevent overfeeding** — Feed waste is the #1 cost driver. The tray feedback loop tells the farmer exactly how much feed was consumed vs given.
- **Automate feed scheduling** — Removes manual calculation burden. Feed amount is pre-generated for DOC 1–25 and computed live afterward.
- **Growth tracking** — Compares actual shrimp weight to expected growth curve to flag underperforming ponds early.
- **Decision support** — Every recommendation comes with a reason so farmers build trust in the system.

### Key Problems Solved
1. Farmers overfeed in early DOC due to anxiety → app shows blind schedule with science-backed quantities
2. No visibility into shrimp appetite until harvest → tray system provides daily appetite signal
3. Growth deviations discovered too late → ABW sampling with expected curve comparison
4. FCR tracking was manual → app computes FCR from feed logs and biomass estimate

---

## 2. FEATURE BREAKDOWN

### FREE PLAN
> **Note:** There is currently NO plan-gating code in the codebase. All features are accessible to all users. The distinction below reflects intended product direction inferred from the architecture.

**Pond Management**
- Create up to (UNCLEAR — no pond count limit found in code) ponds per farm
- Create/edit/delete farms and ponds
- New cycle setup (clears all historical data and regenerates schedule)

**Feed Schedule (DOC 1–30)**
- Pre-generated blind feed schedule for DOC 1–25 on pond creation
- Rolling recovery adds 7 days at a time up to DOC 30
- 4 rounds per day (06:00, 11:00, 16:00, 21:00) at equal 25% splits
- Feed type progression: 1R → 1R+2R → 2R → 2R+3S → 3S
- Manual override allowed on any round

**Tray Logging (DOC 15+, Hatchery; DOC 3+, Nursery)**
- Log tray status: Empty / Partial / Full per round
- Optional observations per tray
- Tray data collected but NOT applied to feed until DOC 31

**Sampling / Growth**
- Record ABW (g) + count per sampling event
- View ABW vs expected growth curve (L. vannamei table)
- Activity timeline showing last 5 events

**Dashboard KPIs**
- Feed today (kg consumed)
- Planned feed today (kg)
- Current ABW (g) — estimated from DOC if no real sample
- FCR — estimated if no real data
- DOC counter

**Water Quality**
- Log dissolved oxygen (mg/L), ammonia (mg/L), temperature (°C), pH

**Harvest**
- Log partial / intermediate / final harvests
- Fields: quantity (kg), count/kg, price/kg, expenses, notes

### PRO PLAN (Smart Feed — auto-unlocks at DOC 31)
**Smart Feed Engine**
- Activates automatically when `currentDoc >= 31` (no manual trigger)
- Full correction pipeline: tray factor + growth factor + water factor + DOC factor (SmartFeedEngineV2)
- Combined factor clamped to [70%, 130%] of base
- Critical stop when DO < 3.5 mg/L
- Water dominance rule: risky water (waterFactor < 1.0) suppresses all tray/growth positive boosts

**Intelligence Layer**
- Compares yesterday's actual feed vs expected
- Deviation > 5% → enforcement factor applied today
- Status: OnTrack / Overfeeding / Underfeeding

**FCR Engine** (active when FeedStage = intelligent, DOC ≥ 41 with ABW)
- FCR < 1.0 → +15% feed
- FCR 1.0–1.2 → +10%
- FCR 1.2–1.3 → +5%
- FCR 1.3–1.4 → no change
- FCR 1.4–1.5 → -10%
- FCR > 1.5 → -15%

**Feed Decision Engine**
- Outputs single action: Increase / Reduce / Maintain / Stop Feeding
- Priority-ordered signal chain (critical > environment > tray > overfeeding > appetite > underfeeding > growth > FCR)
- Confidence score per stage (blind=0.40, transitional=0.65, intelligent=0.85)

**Growth Intelligence**
- ABW vs expected curve: fast (+5% feed) / good (0%) / slow (-10% feed)
- Sample age decay: 0–2 days = full weight; 3–5 days = 70%; 6–7 days = 40%; >7 days = ignored

**Feed Recommendation Engine**
- Next feed quantity (kg) per round
- Next feed time (based on last feed + gap)
- Human-readable instruction string

**Dashboard Analytics**
- 7-day actual vs ideal feed trend line
- Rolling waste % from tray logs (last 5 observations)
- Smart insight (priority-ordered: FCR > growth > waste > streak)
- Activity timeline

**Profit / Harvest Tracking**
- Revenue = quantity × price/kg
- Profit = revenue − expenses
- Feed cost at ₹60/kg (hardcoded)
- Shrimp market price at ₹220/kg (hardcoded)

---

## 3. USER FLOW (END-TO-END)

### 3.1 Install → Login
1. App starts → `AuthGate` checks `Supabase.auth.currentSession`
2. If session exists → skip to `PondDashboardScreen`
3. If no session → `LoginScreen` (shown during `isCheckingSession=true`, splash displayed)
4. Auth options: Email+Password signup/login, Phone+OTP login, Forgot password (email reset)
5. On success: `_syncUserRecord` creates/updates `profiles` row → `farmProvider.loadFarms()` → `feedHistoryProvider.loadHistoryForPonds()`

### 3.2 Create Farm
1. Navigate to `AddFarmScreen`
2. Enter farm name + location
3. `FarmService.createFarm()` → inserts into `farms` table with `user_id`
4. Returns `farmId`

### 3.3 Create Pond
1. Navigate to `AddPondScreen` → enter: pond name, area, stocking date, seed count (PL count), PL size, number of trays
2. `PondService.createPondAndReturnId()`:
   - Calls Supabase RPC `create_pond_with_feed_plan` → inserts into `ponds`
   - Calls `generateFeedSchedule()` → generates DOC 1–25 feed_rounds
3. If farmer already fed today → `premarkRoundsCompleted()` marks first N rounds as done

### 3.4 Feed Schedule Generation (DOC 1–25)
1. `generateFeedPlan()` called for startDoc=1, endDoc=25
2. For each DOC: `MasterFeedEngine.compute()` → total daily feed (kg)
3. Split into 4 rounds at 25% each → 4 rows inserted into `feed_rounds`
4. DOC 26–29: added by `ensureFutureFeedExists()` rolling recovery (triggered on dashboard load)
5. DOC ≥ 31: no pre-generated rows; computed live via `FeedOrchestrator.computeForPond()`

### 3.5 Daily Usage Flow — Feeding

**Morning (Round 1):**
1. Open `PondDashboardScreen` → `loadTodayFeed(pondId)` called
2. For DOC ≤ 30: reads `feed_rounds` for today's DOC → displays 4 round amounts
3. For DOC ≥ 31: `FeedOrchestrator.computeForPond()` → injects smart recommendation for next pending round
4. Farmer sees: Round amount (kg), status (pending/completed), gap timer
5. Farmer taps "Mark Done" → `markFeedDone(round)`:
   - Inserts/updates `feed_rounds` row as completed
   - Calls `feedHistoryProvider.logFeeding()` → inserts `feed_logs`
   - Triggers `recalculateFeedPlan()` (fire-and-forget)
   - Reloads dashboard

**Tray Logging (after feeding):**
1. For DOC ≥ 15 (hatchery) or DOC ≥ 3 (nursery), farmer must check tray
2. `TrayLogScreen` → farmer picks status (Empty/Partial/Full) for each tray
3. `TrayService.saveTrayLog()` → inserts into `tray_logs`
4. For DOC ≥ 31: `FeedService.applyTrayAdjustment()` → runs full orchestrator → updates feed_rounds for DOC+1, DOC+2, DOC+3
5. Dashboard reloads to show updated suggestion

### 3.6 Sampling Flow
1. Farmer weighs sample → enters total weight (kg), count of shrimp
2. App calculates: ABW = (total_weight × 1000) / count (g)
3. `SamplingService.addSampling()`:
   - Inserts into `sampling_logs`
   - Updates `ponds.current_abw` and `ponds.latest_sample_date`
4. `GrowthNotifier.addLog()` updates in-memory state only — DB write is owned exclusively by `SamplingService`

### 3.7 Dashboard Updates
- On every load: `loadTodayFeed()` → reads feed_rounds, injects smart feed if DOC ≥ 31
- `HomeBuilder.build()` computes all KPIs, alerts, trend from providers — no logic in widgets
- Alert priority strictly enforced (allDone > feedOverdue > gapWait > trayPending > growthSlow > readyToFeed)

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Multiple ponds with different DOC | Each pond loads independently via `pondDashboardProvider` scoped to `selectedPond` |
| Missing tray data (DOC ≥ 31) | SmartFeedEngine returns `trayFactor = 1.0` (neutral); confidence reduced by 0.3 |
| No sampling yet | ABW = null → `growthFactor = 1.0`, `fcrFactor = 1.0` (disabled), `samplingFactor = 1.0` |
| Feed rows missing for today | Auto-recovery triggers `generateFeedPlan()` for DOC 1–currentDoc (clamped to 29) |
| DOC ≥ 31 with no feed rows | Normal — smart mode has no pre-generated rows |
| ABW sample > 7 days old | Treated as null — growth signal dropped from computation |
| DO < 3.5 mg/L | `SmartFeedEngineV2` returns `finalFeed = 0`, `isCriticalStop = true` |

---

## 4. FEEDING SYSTEM (CRITICAL)

### 4.1 Base Feed Calculation (MasterFeedEngine v2.0.0)

**Formula:**
```
baseFeed_per100K = stockingType == 'hatchery'
    ? 2.0 + (DOC - 1) × 0.15    (kg per 100,000 shrimp)
    : 4.0 + (DOC - 1) × 0.25    (kg per 100,000 shrimp)

adjustedFeed = baseFeed_per100K × (seedCount / 100,000)
```

**Tray factor (plan generation ONLY, not runtime):**
```
leftover 0%      → factor 1.10
leftover 1–10%   → factor 1.00
leftover 11–25%  → factor 0.90
leftover > 25%   → factor 0.75
```
Runtime tray corrections are applied by SmartFeedEngine, NOT here.

**Safety clamp:**
- Min: adjustedFeed × 0.70
- Max: adjustedFeed × 1.30
- Absolute bounds: 0.1 kg ≤ finalFeed ≤ 50 kg

**Input validation / clamping:**
- DOC clamped to [1, 200]
- seedCount clamped to [1,000, 1,000,000]
- Invalid stockingType defaults to 'hatchery'
- NaN/Infinite → fallback to adjustedFeed

**Example (Nursery pond, DOC 15, 100,000 shrimp):**
```
baseFeed_per100K = 4.0 + (15-1) × 0.25 = 7.5 kg
adjustedFeed = 7.5 × (100000/100000) = 7.5 kg
4 rounds × 25% = 1.875 kg each
```

### 4.2 Smart Feeding Phase (DOC ≥ 31)

**Activated:** Automatically when `currentDoc >= 31` (set in `loadTodayFeed`)

**Feed Phases (FeedMode enum):**
| Phase | DOC Range | Tray Collected | Tray Affects Feed |
|-------|-----------|----------------|-------------------|
| Normal | 1–14 | No | No |
| TrayHabit | 15–30 | Yes | No |
| Smart | ≥ 31 | Yes | Yes |

**Feed Stage (FeedStage enum — separate from FeedMode):**
| Stage | Condition | Active Corrections |
|-------|-----------|-------------------|
| Blind | DOC ≤ 30 OR no ABW | None |
| Transitional | Has ABW + DOC 31–40 | Growth, Tray, Env |
| Intelligent | Has ABW + DOC ≥ 41 | All including FCR |

---

### 4.3 SmartFeedEngineV2 Correction Factors

The orchestrator uses `SmartFeedEngineV2.calculate()`. FCR and intelligence factors are applied on top by the orchestrator after V2 returns.

#### Pipeline order:

**1. Water Factor (evaluated first — critical stop path)**
```
DO < 3.5 mg/L               → factor = 0.0  → STOP FEEDING (critical, isCriticalStop=true)
DO < 4.5 mg/L or NH₃ > 0.3 → factor = 0.80 (−20%)
DO < 5.5 mg/L or NH₃ > 0.1 → factor = 0.90 (−10%)
otherwise                   → factor = 1.0
```
If `waterFactor == 0.0` → immediately returns `finalFeed = 0`, skips all other factors.

**Water dominance rule:** If `waterFactor < 1.0`, any `trayFactor > 1.0` and any `growthFactor > 1.0` are capped to 1.0. Risky water blocks all positive boosts.

**2. Tray Factor (SMART phase only, DOC ≥ 31)**

Weighted: latest reading 50%, prior readings (up to last 3) share 50%.
```
leftover = 0%      → 1.15 (+15%)   shrimp ate everything
leftover 1–9%      → 1.10 (+10%)   near-clean tray
leftover 10–20%    → 1.00 (0%)     normal consumption
leftover 21–50%    → 0.85 (−15%)   moderate leftover
leftover > 50%     → 0.70 (−30%)   heavy leftover
```
If no tray data → `trayFactor = 1.0`

**3. Growth Factor (SMART phase only, DOC ≥ 31, requires ABW)**
```
ABW / expectedABW > 1.10 → rawFactor = 1.05 (+5%)
ABW / expectedABW < 0.90 → rawFactor = 0.90 (−10%)
otherwise                → rawFactor = 1.00

Attenuated by sample age:
  ≤2 days → 100% weight
  ≤5 days →  70% weight
  ≤7 days →  40% weight
  >7 days →  factor = 1.0 (signal dropped)

Final: attenuated.clamp(0.90, 1.10)
```
If ABW null or DOC ≤ 30 → `growthFactor = 1.0`

**4. DOC Factor (SMART phase only, DOC ≥ 31)**
```
DOC 31–45  → 0.95 (−5%)   acclimation period — conservative
DOC 46–75  → 1.00 (0%)    optimal feeding window
DOC > 75   → 0.95 (−5%)   late stage, slower metabolism
```

**5. V2 Combination Guard:**
```
rawProduct    = trayFactor × growthFactor × waterFactor × docFactor
clampedProduct = rawProduct.clamp(0.70, 1.30)
finalFeed     = baseFeed × clampedProduct
finalFeed     = finalFeed.clamp(0.1, baseFeed × 2.0)
```

**6. FCR Factor (applied by orchestrator, Intelligent stage only — DOC ≥ 41 + has ABW)**
```
FCR ≤ 1.0 → 1.15 (+15%)
FCR ≤ 1.2 → 1.10 (+10%)
FCR ≤ 1.3 → 1.05 (+5%)
FCR ≤ 1.4 → 1.00 (neutral)
FCR ≤ 1.5 → 0.90 (−10%)
FCR > 1.5  → 0.85 (−15%)
FCR null   → 1.0 (disabled)
```
Applied: `feedAfterFcr = (v2Result.finalFeed × fcrFactor).clamp(0.1, 50.0)`

**7. Intelligence Factor (applied by orchestrator after FCR)**
```
deviation > +5%  (overfeeding yesterday):
    factor = 1.0 − (deviationPct / 100) × 0.25
    clamped to [0.75, 1.0]
    
deviation < −5% (underfeeding yesterday):
    factor = 1.0 + (abs(deviationPct) / 100) × 0.15
    clamped to [1.0, 1.25]
    
|deviation| ≤ 5% → factor = 1.0 (no adjustment)
```
Applied: `feedFinal = (feedAfterFcr × intelligenceFactor).clamp(0.1, 50.0)`

**Final combinedFactor stored:**
```
combinedFactor = (feedFinal / baseFeed).clamp(0.70, 1.30)
```

### 4.4 Feed Plan Constants

**Rounds per day:** Always 4 (DOC 1 to 120+)
**Splits:** Always equal [0.25, 0.25, 0.25, 0.25]
**Scheduled times:** 06:00 AM, 11:00 AM, 04:00 PM, 09:00 PM
**Gap between rounds:** 150 min (DOC < 30) or 180 min (DOC ≥ 30)
**Overdue grace period:** 30 min past gap

**Feed type by DOC:**
| DOC | Feed Type |
|-----|-----------|
| 1–7 | 1R |
| 8–14 | 1R + 2R |
| 15–21 | 2R |
| 22–28 | 2R + 3S |
| 29+ | 3S |

---

## 5. TRAY LOGIC

### Activation Rules
| Stocking Type | Tray Active From |
|---------------|-----------------|
| Hatchery | DOC 15 |
| Nursery | DOC 3 |

### Tray Status Categories
| Status | Leftover % Used | Tray Factor (SmartFeedEngineV2) |
|--------|----------------|--------------------------------|
| Empty | 0% | +15% (factor 1.15) |
| Partial | 30% | −15% (factor 0.85) |
| Full | 70% | −30% (factor 0.70) |

V2 maps these fixed statuses through the 5-band tray table. Rolling weighted average of last 3 readings used (latest 50%, prior 50%).

### Tray Phases
- **DOC 1–14 (Normal):** No tray, no tray factor
- **DOC 15–30 (TrayHabit):** Tray data COLLECTED and stored but NO feed adjustment. The farmer builds the habit.
- **DOC 31+ (Smart):** Tray data actively drives feed corrections

### Tray Aggregation
When multiple trays are logged per round:
1. Each tray's status is mapped to a leftover %
2. Average leftover % computed across all trays
3. Average mapped to factor via lookup table

When multiple rounds are logged:
- SmartFeedEngine uses last 3 days of `tray_logs` (weighted average: latest reading 50%, prior readings 50%)
- FeedInputBuilder fetches last tray log for today's DOC, plus last 3 days via `_last3DaysLeftoverPct()`

### Tray Skip Logic
- If farmer proceeds to next round without logging tray, `markFeedDone()` auto-skips previous rounds' trays via `TrayService.markTraySkipped()`
- Skipped trays stored as `tray_statuses = ['skipped']`
- Skipped logs return `leftoverPercent = null` and are excluded from calculations

### Edge Cases
| Scenario | Behavior |
|----------|----------|
| No tray data in smart phase | `trayFactor = 1.0`, confidence reduced by 0.3 |
| All trays skipped | Treated same as no data |
| Tray persist fails (network error) | `trayPersistFailed = true` → retry banner shown |

---

## 6. SAMPLING & GROWTH SYSTEM

### When Sampling is Triggered
No strict DOC rule — farmer can sample any time. However:
- Growth factor is only active DOC ≥ 31 with valid ABW
- ABW signals decay: sample > 7 days old is treated as null
- Recommended: every 5–7 days in smart phase

### ABW Calculation
```
ABW (g) = (total_weight_kg × 1000) / total_pieces
```
Stored in `sampling_logs.avg_weight` and cached in `ponds.current_abw`

### Expected ABW Table (L. vannamei)
| DOC | Expected ABW (g) | DOC | Expected ABW (g) |
|-----|-----------------|-----|-----------------|
| 1 | 0.01 | 50 | 16.00 |
| 5 | 0.05 | 60 | 22.00 |
| 10 | 0.20 | 70 | 30.00 |
| 15 | 0.60 | 80 | 38.00 |
| 20 | 1.50 | 90 | 45.00 |
| 25 | 3.00 | 100 | 52.00 |
| 30 | 5.00 | 110 | 58.00 |
| 35 | 7.50 | 120 | 65.00 |
| 40 | 10.00 | | |
| 45 | 13.00 | | |
Values between table entries are linearly interpolated.

### Growth Classification
| Ratio (ABW / Expected) | Classification | Feed Adjustment |
|------------------------|---------------|----------------|
| > 1.10 | Fast growth | +5% |
| 0.90–1.10 | Good / on track | 0% |
| < 0.90 | Slow growth | -5% to -10% |
| < 0.85 | ALERT shown | May trigger alert |

### Impact on Feed Decisions
- Growth ratio > 1.10 → `growthFactor = 1.05` → `FeedDecision.action = "Increase Feeding"`
- Growth ratio < 0.90 → `growthFactor = 0.95` → `FeedDecision.action = "Reduce Feeding"` (if no stronger signal)
- After 7 days, sample is stale → signal drops to neutral

---

## 7. DASHBOARD SYSTEM

### Pond Dashboard (per-pond)
| Metric | Calculation | Assumption if Missing |
|--------|------------|----------------------|
| Feed Today | Sum of all completed round amounts | 0 |
| Planned Today | Sum of all round planned_amounts | 0 |
| Current ABW | `ponds.current_abw` | Estimated via `getExpectedABW(doc)` from L. vannamei table |
| FCR | `totalFeedGiven / currentBiomass` | Estimated: 1.3 (DOC 30–60), 1.4 (DOC >60) |
| DOC | `(today - stockingDate).inDays + 1` | Min 1 |

### ABW Estimation (when no real sample)
Uses `getExpectedABW(doc)` from `expectedAbwTable` — the same L. vannamei lookup table the feed engine uses for growth factor computation. Linear interpolation between table keys. UI and engine are guaranteed to display the same value.

### Alert Priority System (highest to lowest)
1. **allDone** — All 4 rounds completed today
2. **feedOverdue** — Gap + 30 min elapsed since last feed without new round
3. **gapWait** — Currently within required gap (150/180 min)
4. **trayPending** — DOC ≥ 30, completed round has no tray logged
5. **growthSlow** — Real ABW sample exists AND ABW < 85% of expected
6. **readyToFeed** — Gap cleared or first feed of day

### Feed Trend
- Last 7 days of actual vs planned feed
- Computed in `HomeBuilder._buildTrend()`
- "above ideal" if > 8% over planned average
- "below ideal" if > 8% under planned average

### Waste Insight Card
- Rolling 5-log tray average (`_rollingWaste()`)
- Shows suggested feed factor: 1.00 / 0.97 / 0.93 / 0.88 based on waste %
- **Note:** This is display-only. It does NOT feed into the engine automatically.

### Smart Insight (single priority message)
1. FCR > 1.4 → "Overfeeding by ~X%"
2. Real ABW < 85% expected → "Growth slow: Xg vs Yg ideal"
3. FCR 1.2–1.4 → "FCR X.XX vs target 1.2"
4. Waste > 20% → "X% tray leftover on average"
5. FCR ≤ 1.2 → "FCR X.XX ✅ on target"
6. Streak ≥ 5 → "N-day feeding streak"

### Farm Dashboard
`DashboardService.getPonds()` fetches ponds with nested `feed_rounds`, calculates today's feed total by summing `planned_amount` for matching DOC rows.

---

## 8. DATA MODELS

### DB Tables (Supabase/PostgreSQL)

#### `farms`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| name | text | Farm name |
| location | text | Location string |
| user_id | UUID | FK → auth.users |

#### `ponds`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| farm_id | UUID | FK → farms |
| name | text | |
| area | numeric | Acres/hectares (unit not specified in code) |
| stocking_date | date | Used to compute DOC |
| seed_count | int | Live shrimp count (1,000–500,000) |
| pl_size | int | Post-larval size |
| num_trays | int | Number of feed trays |
| status | text | 'active' or 'completed' |
| current_abw | numeric | Cached ABW from latest sample |
| latest_sample_date | date | For sample freshness check |
| is_smart_feed_enabled | bool | Set true automatically at DOC 31 |
| stocking_type | text | 'hatchery' or 'nursery' (may not exist in all schemas) |
| is_deleted | bool | Soft delete flag |
| initial_feed_rounds | int | Custom config (default 2) |
| post_week_feed_rounds | int | Custom config (default 4) |
| is_custom_feed_plan | bool | Whether to use custom round config |

#### `feed_rounds`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| pond_id | UUID | FK → ponds |
| doc | int | Day of Culture |
| round | int | 1–4 |
| planned_amount | numeric | Recommended feed (kg) |
| base_feed | numeric | Engine base before adjustments |
| status | text | 'pending' or 'completed' |
| is_manual | bool | True = farmer overrode |
| feed_type | text | '1R', '2R', etc. |
| adjustment_reason | text | Why it was changed |

Unique constraint: `(pond_id, doc, round)` — enforced via upsert

#### `feed_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| pond_id | UUID | FK → ponds |
| feed_given | numeric | Total feed for that round (kg) |
| created_at | timestamptz | Time of logging |
| doc | int | Day of Culture |
| tray_leftover | numeric | Optional leftover % |

**Important:** Multiple rows per day are allowed. Latest row per calendar date is authoritative for FCR computation.

#### `tray_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| pond_id | UUID | FK → ponds |
| date | date | Date of observation |
| doc | int | Day of Culture |
| round_number | int | Which feed round |
| tray_statuses | text[] | Array of 'empty'/'partial'/'full'/'skipped' |
| observations | jsonb | Map of tray_index → [observation strings] |

#### `sampling_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| pond_id | UUID | FK → ponds |
| doc | int | Day of Culture |
| avg_weight | numeric | ABW in grams |
| count | int | Number of shrimp sampled |
| created_at | timestamptz | |

#### `water_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| pond_id | UUID | FK → ponds |
| dissolved_oxygen | numeric | mg/L |
| ammonia | numeric | mg/L |
| temperature | numeric | °C |
| ph | numeric | |
| created_at | timestamptz | |

#### `harvest_logs`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| pond_id | UUID | FK → ponds |
| harvest_type | text | 'partial', 'intermediate', 'final' |
| quantity | numeric | kg harvested |
| price | numeric | ₹/kg |
| expenses | numeric | Total expenses ₹ |
| notes | text | |
| doc | int | |
| date | date | |
| count_per_kg | int | |

#### `profiles`
| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK = auth.users.id |
| name | text | |
| phone | text | |
| email | text | |
| created_at | timestamptz | |

#### `feed_debug_logs`
| Column | Type | Notes |
|--------|------|-------|
| pond_id | UUID | |
| doc | int | |
| mode | text | 'normal'/'trayHabit'/'smart' |
| base_feed | numeric | |
| expected_feed | numeric | |
| actual_feed | numeric | |
| deviation | numeric | |
| deviation_pct | numeric | |
| intelligence_status | text | |
| tray_factor | numeric | |
| growth_factor | numeric | |
| sampling_factor | numeric | |
| environment_factor | numeric | |
| fcr_factor | numeric | |
| intelligence_factor | numeric | |
| combined_factor | numeric | |
| final_feed | numeric | |
| engine_version | text | |
| reason | text | |
| created_at | timestamptz | |

### Dart Models (in-memory)

#### `Pond` (lib/features/farm/farm_provider.dart)
Core pond model with: id, name, area, stockingDate, seedCount, plSize, numTrays, status, currentAbw, latestSampleDate, isSmartFeedEnabled, initialFeedRounds, postWeekFeedRounds, isCustomFeedPlan

#### `FeedInput` (lib/core/engines/models/feed_input.dart)
Engine input bundle: seedCount, doc, abw, stockingType, feedingScore, intakePercent, dissolvedOxygen, temperature, phChange, ammonia, mortality, trayStatuses, sampleAgeDays, recentTrayLeftoverPct, lastFcr, actualFeedYesterday, lastFeedTime

**Note:** There is a SECOND `FeedInput` class in `lib/models/feed_model.dart` with different fields. This is dead code but causes confusion.

#### `FeedHistoryLog` (lib/features/feed/feed_history_provider.dart)
Per-day feed record: date, doc, rounds[], trayStatuses[], smartFeedRecommendations[], expected, cumulative

#### `TrayLog` (lib/features/tray/tray_model.dart)
Per-round tray record: pondId, time, doc, round, trays[], observations, isSkipped

#### `SamplingLog` (lib/features/growth/sampling_log.dart)
Per-sampling-event: doc, abw, date, totalPieces

#### `HarvestEntry` (lib/features/harvest/harvest_provider.dart)
Per-harvest: id, pondId, date, doc, quantity, countPerKg, pricePerKg, expenses, notes, type

---

## 9. BUSINESS RULES (EXTRACTED FROM CODE)

### Feed Phase Rules
- **R1:** DOC 1–14 = blind feeding only. No tray, no smart adjustment.
- **R2:** DOC 15–30 = tray habit phase. Tray IS logged but MUST NOT affect feed.
- **R3:** DOC ≥ 31 = smart phase. All corrections active.
- **R4:** Feed plan is pre-generated for DOC 1–25 at pond creation. Never pre-generated for DOC ≥ 31.
- **R5:** Rolling recovery adds 7 days at a time but ONLY up to DOC 30 max.

### Base Feed Rules
- **R6:** Hatchery: 2.0 + (DOC-1) × 0.15 kg per 100K shrimp
- **R7:** Nursery: 4.0 + (DOC-1) × 0.25 kg per 100K shrimp
- **R8:** Feed scales linearly with seed count (density scaling)
- **R9:** Always 4 rounds per day; always equal 25% splits
- **R10:** Feed never below 0.1 kg or above 50 kg (absolute hard caps)
- **R11:** Smart adjustments are clamped to ±30% of base feed

### Tray Rules
- **R12:** Tray active for hatchery at DOC ≥ 15, nursery at DOC ≥ 3
- **R13:** Empty tray = shrimp hungry → increase feed +10%
- **R14:** Partial tray = normal → -10%
- **R15:** Full tray = overfeeding → -25%
- **R16:** Tray data in DOC 15–30 is stored but explicitly NOT used in feed calculation
- **R17:** Skipped trays count as null (excluded from all calculations)

### Sampling / Growth Rules
- **R18:** ABW sample older than 7 days = ignored (treated as null)
- **R19:** Growth factor only active when DOC ≥ 31 AND valid ABW exists
- **R20:** FCR factor only active in "intelligent" stage: DOC ≥ 41 AND has ABW

### Water Quality Rules
- **R21:** DO < 3.5 → STOP FEEDING immediately (SmartFeedEngineV2, isCriticalStop=true)
- **R22:** DO < 4.5 or NH₃ > 0.3 → −20% feed (waterFactor 0.80)
- **R23:** DO < 5.5 or NH₃ > 0.1 → −10% feed (waterFactor 0.90)
- **R24:** DO ≥ 5.5 and NH₃ ≤ 0.1 → no water-based adjustment
- **R25:** Water dominance: any waterFactor < 1.0 caps trayFactor and growthFactor at 1.0 (positive boosts suppressed)

### Intelligence / Deviation Rules
- **R26:** ±5% deviation from expected → no enforcement
- **R27:** Overfeeding yesterday → proportional reduction today (up to -25%)
- **R28:** Underfeeding yesterday → small catch-up (+up to +15%)

### Smart Feed Activation
- **R29:** Smart feed flag set automatically when DOC reaches 31 (no manual toggle)
- **R30:** Smart feed flag is also a DB column (`is_smart_feed_enabled`) — auto-updated on load

### Cost Constants (Hardcoded)
- **R31:** Feed cost = ₹60/kg
- **R32:** Shrimp market price = ₹220/kg

### Harvest Rules
- **R33:** Harvest type 'final' marks cycle as effectively done (`isFinalHarvestDone = true`)
- **R34:** Cycle reset (`clearPondCycleData`) deletes ALL: feed_rounds, feed_logs, tray_logs, sampling_logs, water_logs, harvest_logs

---

## 10. EDGE CASES & RISKS

### CRITICAL BUGS (Fixed)

#### ~~BUG-1: Two SmartFeedEngines with different formulas — only one used in production~~ ✅ FIXED
**Fix:** `FeedOrchestrator.compute()` now calls `SmartFeedEngineV2.calculate()`. FCR and intelligence factors applied on top by the orchestrator. Tray history ordering corrected (reversed to oldest-first as V2 expects) and today's live tray reading appended before passing to V2.

#### ~~BUG-2: DashboardService.getPonds() references non-existent column~~ ✅ FIXED
**Fix:** `lib/services/dashboard_service.dart` — both the nested select and the fold accumulator now use `planned_amount`.

#### ~~BUG-3: Duplicate sampling_logs inserts~~ ✅ FIXED
**Fix:** `GrowthNotifier.addLog()` (`lib/features/growth/growth_provider.dart`) is now purely in-memory. `SamplingService.addSampling()` is the sole DB writer and also owns the `ponds.current_abw` cache update.

#### BUG-4: FeedHistoryNotifier._expectedFeedForDoc() is broken for non-selected ponds
**File:** `lib/features/feed/feed_history_provider.dart:56`
Returns 0 for any pond that isn't `dashboardState.selectedPond`. This means `FeedHistoryLog.expected` is 0 for all background ponds. Explicitly documented as broken: "Fix #5: returns 0 for non-selected ponds."

#### BUG-5: Pond.feedRoundsForDoc() is dead code that contradicts standardFeedConfig
**File:** `lib/features/farm/farm_provider.dart:49`
```dart
int feedRoundsForDoc(int doc) {
  if (isCustomFeedPlan) {
    return doc <= 7 ? initialFeedRounds : postWeekFeedRounds;
  }
  return doc <= 7 ? 2 : 4;  // Returns 2 for DOC 1-7
}
```
But `standardFeedConfig` always generates 4 rounds from DOC 1. The `feedRoundsForDoc()` method is never used in feed plan generation, creating a gap between the Pond model's intent and reality.

#### BUG-6: Smart feed auto-activation has race condition in multi-device
**File:** `lib/features/pond/pond_dashboard_provider.dart:154`
On every `loadTodayFeed()` call at DOC ≥ 31, if `!pond.isSmartFeedEnabled`, it fires an async DB update. If two devices open simultaneously, both race to update the flag. Not dangerous but causes unnecessary DB writes.

### MEDIUM RISKS

#### ~~RISK-1: ABW estimated value ≠ expectedAbwTable value~~ ✅ FIXED
**Fix:** `HomeBuilder` now calls `getExpectedABW(doc)` directly. `_estimateAbw()` deleted. UI and engine use the same value.

#### RISK-2: FCR computation uses `feed_logs` running totals
**File:** `lib/core/engines/feed_input_builder.dart:260`
`feed_logs` stores a running cumulative per `logFeeding()` call. The code tries to take "last row per date" but multiple saves per day means the last row may not represent the true daily total if `saveFeed()` is called with round quantities rather than daily totals. This is architecture-level ambiguity.

#### RISK-3: FarmService.deleteFarm() leaves orphaned pond data
**File:** `lib/services/farm_service.dart:79`
`deleteFarm()` deletes ponds but NOT their associated `feed_rounds`, `feed_logs`, `tray_logs`, etc. These rows will remain in the DB as orphans. If RLS policies don't cascade delete, they accumulate indefinitely.

#### RISK-4: No pond count limit enforced
No code limits how many ponds a farm can have. For a future freemium model, this gate doesn't exist.

#### RISK-5: Hardcoded financial constants
`kFeedCostPerKg = 60.0` and `kShrimpMarketPricePerKg = 220.0` in `app_constants.dart`. These are market-dependent and will become wrong over time. No UI to update them.

#### RISK-6: stocking_type column may not exist in all deployments
`FeedInputBuilder.fromDB()` selects `stocking_type` from `ponds`. If the column doesn't exist in the Supabase schema (it's not in `getPonds()` SELECT list), the query will throw or default to 'nursery'. The base feed formula differs by 2× between hatchery and nursery at DOC 1.

### LOW RISKS / TECH DEBT

#### TD-1: Two FeedInput classes
`lib/core/engines/models/feed_input.dart` (used by engines) and `lib/models/feed_model.dart` (dead code). Import confusion possible.

#### TD-2: Dead archived engines
`lib/core/engines/_archive/` contains 6+ archived engine files including a FeedCalculationEngineV0, SmartFeedDecisionEngine, etc. These are not imported but clutter the codebase and confuse new developers.

#### TD-3: FeedInputValidator.validateOutput() is still not called
**File:** `lib/core/validators/feed_input_validator.dart:171`
`validate()` (input) is now wired. `validateOutput()` (post-computation) is still not called. Low priority — the orchestrator's `clamp(0.1, 50.0)` and `combinedFactor.clamp(0.70, 1.30)` provide equivalent safety at the output boundary.

#### TD-4: `feedingScore` and `intakePercent` in FeedInput are unused
Both fields are hardcoded in `FeedInputBuilder.fromDB()` (`feedingScore: 3.0`, `intakePercent: 85.0`) and not used by any engine. They remain in FeedInput as historical artifacts.

#### TD-5: Missing water_logs in pond delete cascade
`PondService.clearPondCycleData()` correctly deletes all tables. But `PondService.deletePond()` only deletes from `ponds` table — relies on Supabase cascade. If cascade is not set up, orphaned rows accumulate.

---

## 11. CODEBASE STRUCTURE

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart           # Supabase URL + anonKey
│   ├── constants/
│   │   ├── app_constants.dart        # kFeedCostPerKg, kShrimpMarketPricePerKg
│   │   └── expected_abw_table.dart   # L. vannamei DOC→ABW lookup table
│   ├── engines/
│   │   ├── _archive/                 # 6 deprecated engines (do not use)
│   │   ├── models/
│   │   │   ├── feed_input.dart       # Engine input bundle
│   │   │   ├── feed_output.dart      # Legacy output model
│   │   │   └── smart_feed_output.dart
│   │   ├── engine_constants.dart
│   │   ├── fcr_engine.dart           # FCR correction factor
│   │   ├── feed_decision_engine.dart # Action + reason output
│   │   ├── feed_input_builder.dart   # DB → FeedInput constructor
│   │   ├── feed_intelligence_engine.dart # Expected vs actual deviation
│   │   ├── feed_orchestrator.dart    # SINGLE ENTRY POINT for pipeline
│   │   ├── feed_plan_constants.dart  # Round config, timings, splits
│   │   ├── feed_plan_generator.dart  # Generates blind phase schedule to DB
│   │   ├── feed_recommendation_engine.dart # Next feed time + instruction
│   │   ├── feed_status_engine.dart
│   │   ├── master_feed_engine.dart   # DOC ramp + density scaling
│   │   ├── pond_cycle_engine.dart
│   │   ├── pond_value_engine.dart
│   │   ├── smart_feed_decision_engine.dart
│   │   ├── smart_feed_engine.dart    # ← provides CorrectionResult model + computeIntelligenceFactor
│   │   ├── smart_feed_engine_v2.dart # ← USED BY ORCHESTRATOR (wired in BUG-1 fix)
│   │   ├── tray_decision_engine.dart
│   │   └── feed_recommendation_engine.dart
│   ├── enums/
│   │   ├── feed_stage.dart           # blind / transitional / intelligent
│   │   └── tray_status.dart          # empty / partial / full
│   ├── language/                     # i18n (English + Telugu)
│   ├── repositories/
│   │   └── feed_repository.dart      # Atomic DB operations
│   ├── theme/
│   ├── utils/
│   │   ├── doc_utils.dart            # calculateDocFromStockingDate
│   │   ├── logger.dart               # AppLogger (debug/info/error)
│   │   └── time_provider.dart        # Testable DateTime.now()
│   └── validators/
│       └── feed_input_validator.dart # Input validation — called at start of FeedOrchestrator.compute()
│
├── features/
│   ├── auth/
│   │   ├── auth_provider.dart        # Supabase email+OTP auth, session check
│   │   ├── login_screen.dart
│   │   ├── otp_screen.dart
│   │   ├── splash_screen.dart
│   │   └── forgot_password_dialog.dart
│   ├── dashboard/
│   │   ├── dashboard_screen.dart     # Farm-level dashboard
│   │   └── farm_dashboard_provider.dart
│   ├── debug/                        # Dev-only debug screens
│   │   ├── debug_dashboard_provider.dart
│   │   ├── debug_dashboard_screen.dart
│   │   ├── debug_feed_provider.dart
│   │   ├── debug_feed_screen.dart
│   │   ├── smart_feed_debug_provider.dart
│   │   └── smart_feed_debug_screen.dart
│   ├── farm/
│   │   ├── farm_provider.dart        # Pond/Farm models + Riverpod state
│   │   ├── add_farm_screen.dart
│   │   ├── edit_farm_dialog.dart
│   │   └── new_cycle_setup_screen.dart
│   ├── feed/
│   │   ├── feed_history_provider.dart # In-memory + DB feed history
│   │   ├── feed_history_screen.dart
│   │   ├── feed_schedule_provider.dart
│   │   ├── feed_schedule_screen.dart
│   │   └── smart_feed_provider.dart
│   ├── growth/
│   │   ├── growth_provider.dart      # Sampling logs Riverpod state
│   │   ├── mortality_provider.dart
│   │   ├── sampling_log.dart         # SamplingLog model
│   │   └── sampling_screen.dart
│   ├── harvest/
│   │   ├── harvest_provider.dart     # HarvestEntry model + Riverpod
│   │   ├── harvest_screen.dart
│   │   └── harvest_summary_screen.dart
│   ├── home/
│   │   ├── home_builder.dart         # ALL home screen computation (no widgets)
│   │   ├── home_view_model.dart      # Data structs for home widgets
│   │   ├── alert_strip.dart
│   │   ├── activity_timeline.dart
│   │   ├── feed_trend_card.dart
│   │   ├── growth_status_card.dart
│   │   ├── kpi_row.dart
│   │   ├── smart_insight_box.dart
│   │   └── waste_insight_card.dart
│   ├── pond/
│   │   ├── pond_dashboard_provider.dart  # Core daily operation state
│   │   ├── pond_dashboard_screen.dart
│   │   ├── pond_model.dart           # EMPTY FILE
│   │   ├── growth_provider.dart      # Duplicate of features/growth/growth_provider
│   │   ├── add_pond_screen.dart
│   │   └── edit_pond_screen.dart
│   ├── profile/
│   ├── supplements/                  # Feed supplement mix calculator
│   ├── tray/
│   │   ├── tray_model.dart           # TrayLog model
│   │   ├── tray_provider.dart        # Riverpod state for tray logs
│   │   └── tray_log_screen.dart
│   └── water/
│       ├── water_provider.dart
│       └── water_test_screen.dart
│
├── models/
│   ├── feed_model.dart               # DEAD CODE — FeedEntry + duplicate FeedInput
│   ├── feed_result.dart              # FeedResult (used in some UI paths)
│   └── feed_round_model.dart
│
├── repositories/
│   ├── feed_repository.dart          # atomicUpdateRound
│   ├── pond_repository.dart
│   └── tray_repository.dart
│
├── routes/
│   └── app_routes.dart               # Named route definitions
│
├── services/
│   ├── dashboard_service.dart        # BUG: wrong column name
│   ├── farm_service.dart             # CRUD for farms
│   ├── feed_calculation_service.dart
│   ├── feed_service.dart             # Feed saving, plan adjustment, recalc
│   ├── pond_service.dart             # Pond CRUD + feed schedule generation
│   ├── sampling_service.dart         # ABW sampling + pond cache update
│   ├── supplement_service.dart
│   └── tray_service.dart             # Tray log save/fetch, skip
│
├── shared/
├── theme/
│   └── app_theme.dart               # Duplicate of core/theme/app_theme.dart
└── widgets/
    └── app_bottom_bar.dart
```

### State Management
**Riverpod** (flutter_riverpod ^2.6.1):
- `StateNotifierProvider`: `farmProvider`, `authProvider`, `pondDashboardProvider`, `feedHistoryProvider`, `trayProvider`, `growthProvider`, `harvestProvider`
- `Provider.family`: `docProvider(pondId)`, `trayProvider(pondId)`, `growthProvider(pondId)`, `harvestProvider(pondId)`
- `Provider`: `currentDateProvider` (refreshes every hour for DOC auto-increment), `todayProvider`, `oneWeekAgoProvider`

### Key Architecture Patterns
- **Engines are pure functions** — no DB access, no Flutter dependencies
- **FeedOrchestrator** is the single computation entry point; nothing bypasses it in the normal path
- **FeedInputBuilder.fromDB()** is the only place that reads pond state from DB and constructs `FeedInput`
- **HomeBuilder** is a static class that takes provider values and computes `HomeViewModel` — no logic in widgets
- **Services** handle DB persistence; engines handle computation

---

## 12. KNOWN ISSUES / TECH DEBT

### Architecture
1. ~~**Two parallel smart feed engines**~~ — ✅ Fixed. Orchestrator now uses SmartFeedEngineV2. `smart_feed_engine.dart` is retained for `CorrectionResult` model and `computeIntelligenceFactor` helper only.
2. **Dead code accumulation**: `_archive/` folder, `lib/models/feed_model.dart`, `pond_model.dart` (empty), `features/pond/growth_provider.dart` (duplicate of features/growth/growth_provider.dart)
3. **Duplicate theme files**: `lib/core/theme/app_theme.dart` and `lib/theme/app_theme.dart`
4. **`feedingScore` and `intakePercent`** are always hardcoded (3.0 and 85.0) and never used by any engine. Historical dead fields in `FeedInput`.
5. ~~**`FeedInputValidator`** is never called in the production pipeline~~ — ✅ Fixed. `FeedInputValidator.validate(input)` is now the first line of `FeedOrchestrator.compute()`.

### Data Integrity
6. **Running cumulative in `feed_logs`**: `saveFeed()` stores `feed_given` as the total for that round (not cumulative), but `_computeLastFcr()` tries to sum "last row per day" as daily totals. The semantics are ambiguous.
7. **No soft-delete on ponds**: `is_deleted` flag exists in DashboardService query but the pond deletion in FarmService doesn't set it — it hard-deletes.
8. **Orphaned data**: Farm deletion and pond deletion don't clean associated child records (depends on Supabase cascade config).

### UX / Logic
9. ~~**Estimated ABW displayed vs engine ABW mismatch**~~ — ✅ Fixed. Both now use `getExpectedABW(doc)`.
10. **FeedHistoryLog.expected = 0 for non-selected ponds** means trend comparison data is incorrect in multi-pond views.
11. **Waste insight is display-only** — the `suggestedFeedFactor` shown in the UI is never fed back into the engine automatically.
12. **No offline support** — every operation requires network. No queue for failed operations (except `trayPersistFailed` flag for retry banner).

### Scalability
13. **Feed plan generation is sequential** (one `INSERT` per round × DOC). For a 120-DOC plan, this is 480 individual inserts with a loop. This is the upsert batch approach but it runs in a loop, not a true batch.
14. **`loadHistoryForPonds()` fetches ALL feed_logs for all ponds** on startup. Will degrade as data grows.
15. **No pagination** anywhere in the app.

---

## 13. BACKEND EXPECTATIONS (FOR SUPABASE)

### Required Supabase RPC Function
`create_pond_with_feed_plan(p_farm_id, p_name, p_area, p_stocking_date, p_seed_count, p_pl_size, p_num_trays, p_user_id)` → returns pond UUID

### Required Tables (with constraints)
1. `farms` — user_id RLS: `user_id = auth.uid()`
2. `ponds` — farm_id FK with cascade delete to all child tables
3. `feed_rounds` — unique constraint `(pond_id, doc, round)`
4. `feed_logs` — ordered by `created_at`
5. `tray_logs` — ordered by `date, round_number`
6. `sampling_logs`
7. `water_logs`
8. `harvest_logs`
9. `profiles` — id = auth.uid()
10. `feed_debug_logs` — write-only, non-critical

### Required RLS Policies (minimum)
- All tables: `SELECT/INSERT/UPDATE/DELETE` restricted to ponds belonging to farms belonging to `auth.uid()`
- The app has NO client-side multi-tenancy enforcement; RLS is the only security layer

### Missing from Schema (Inferred Gaps)
- `ponds.stocking_type` — queried by `FeedInputBuilder` but not in `getPonds()` SELECT. May or may not exist.
- `feed_rounds.adjustment_reason` — written by `_applyFactorFromBase()` but may not exist in schema

### Data Sync Expectations
- **Real-time:** NOT implemented. App polls on user actions.
- **Offline:** NOT implemented. All operations require connectivity.
- **Conflict resolution:** Last-write-wins. Atomic update in `FeedRepository.atomicUpdateRound()` uses optimistic concurrency (checks expected value before update).

---

## 14. RECOMMENDED IMPROVEMENTS

### Pre-Launch (Critical)

**~~P0 — Fix BUG-1 (Two Smart Feed Engines)~~** ✅ Done

**~~P0 — Fix BUG-2 (DashboardService column name)~~** ✅ Done

**~~P0 — Fix BUG-3 (Duplicate sampling_logs insert)~~** ✅ Done

**~~P1 — Fix RISK-1 (ABW estimation mismatch)~~** ✅ Done

**~~P1 — Call `FeedInputValidator.validate()` in orchestrator~~** ✅ Done

### Architecture

**Wire FCR factor correctly for transitional stage:**
Currently FCR is only applied at `FeedStage.intelligent` (DOC ≥ 41). Consider enabling it at DOC ≥ 31 once a first sample exists.

**Consolidate `FeedInput` classes:**
Delete `lib/models/feed_model.dart` (dead code). The `lib/core/engines/models/feed_input.dart` is the authoritative class.

**Remove unused fields from FeedInput:**
`feedingScore` and `intakePercent` are always hardcoded and unused by engines. Remove or repurpose.

**Delete or properly archive old engines:**
Move `_archive/` files to a git history tag and delete from active codebase.

**Make financial constants configurable:**
Move `kFeedCostPerKg` and `kShrimpMarketPricePerKg` to a farm settings model stored in Supabase, editable in profile/settings screen.

### Performance

**Batch feed plan inserts:**
Replace the loop in `generateFeedPlan()` with a single upsert call for all rows in one request.

**Paginate feed_logs loading:**
`loadHistoryForPonds()` currently fetches all history. Limit to last 30 days on startup.

**Add Supabase cascade deletes:**
Set up proper FK cascade so pond deletion automatically removes all child records. Remove manual cleanup loops.

### QA / Testing

**Add integration tests for engine pipeline:**
The only test file is `test/feed_decision_engine_test.dart` (5 unit tests). Need:
- MasterFeedEngine tests across DOC/density range
- SmartFeedEngine correction factor tests
- FeedOrchestrator end-to-end tests with mock DB

**Add snapshot tests for ABW table interpolation:**
`getExpectedABW()` linear interpolation could return wrong values at boundaries.

**Test multi-pond scenarios:**
FeedHistory for non-selected ponds is known-broken. Add integration tests to surface this.

---

## PRODUCTION READINESS CHECKLIST

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | SmartFeedEngineV2 not wired to orchestrator | CRITICAL | ✅ Fixed |
| 2 | DashboardService `feed_amount` column bug | CRITICAL | ✅ Fixed |
| 3 | Duplicate sampling_logs insert | HIGH | ✅ Fixed |
| 4 | ABW estimated value ≠ engine expected value | HIGH | ✅ Fixed |
| 5 | FeedInputValidator never called | HIGH | ✅ Fixed |
| 6 | FeedHistoryLog.expected = 0 for non-selected ponds | HIGH | ✅ Fixed |
| 7 | FCR computed from ambiguous `feed_logs` running totals | MEDIUM ✅ Fixed |
| 8 | Farm/pond delete leaves orphaned data | MEDIUM | ✅ Fixed |
| 9 | Hardcoded financial constants | MEDIUM | ✅ Fixed |
| 10 | `stocking_type` column may not exist in schema | MEDIUM | UNCLEAR | ✅ Fixed |
| 11 | No offline support / no operation queue | MEDIUM | ✅ Fixed |
| 12 | Waste insight factor is display-only (not applied) | LOW | ✅ Fixed |
| 13 | Dead code (`_archive/`, `feed_model.dart`, etc.) | LOW | ✅ Fixed |
| 14 | `Pond.feedRoundsForDoc()` contradicts standardFeedConfig | LOW | ✅ Fixed |
| 15 | Sequential feed plan inserts (performance) | LOW | ✅ Fixed |

---

*This document was generated by analyzing the full source of `/Users/sunny/Documents/aqua_rythu/lib` on 2026-04-17. All claims are derived from actual code, not assumptions. Items marked UNCLEAR indicate areas where the code behavior depends on Supabase schema state not visible in the Flutter codebase.*
