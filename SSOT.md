# AquaRythu — Single Source of Truth (SSOT)
> Last updated: 2026-04-14 | Version: V1 (Live) → V1.5 (In Progress) → V2 (Behavior Layer Planned)

---

## 1. Product Overview

### 1.1 What is AquaRythu?

AquaRythu is a **feed intelligence platform** for shrimp farmers. It reduces feed waste, improves FCR (Feed Conversion Ratio), and increases profitability through structured data and a smart feed engine.

### 1.2 Core Problem

- Farmers overfeed because there is no real-time feedback loop
- Feed = 60–70% of total crop cost → highest leakage point
- No structured way to track or adjust

### 1.3 Solution

- Structured daily feed logging (per round)
- Hybrid Smart Feed Engine (tray × growth × sampling)
- Alerts + actionable insights
- Profit-focused recommendations

---

## 2. Vision & Goal

| Item | Detail |
|------|--------|
| Vision | Become the **operating system for shrimp farming** |
| Core Goal | FCR ≤ 1.2 OR save ₹50,000+ per crop |
| Long-term | Full farm automation + AI predictions + water intelligence |

---

## 3. Target Users

### 3.1 Primary User: Andhra Pradesh Shrimp Farmer

| Attribute | Detail |
|-----------|--------|
| Geography | Coastal Andhra Pradesh — Krishna, Guntur, West Godavari, East Godavari, Nellore districts |
| Language | Telugu primary, limited English |
| Farm size | 2–20 ponds, 0.5–5 acres each |
| Species | Litopenaeus vannamei (Pacific white shrimp) — dominant |
| Stocking | Hatchery or nursery-reared PL |
| Seed count | 50,000–500,000 per pond |
| Cycles | 2–3 crops per year |
| Connectivity | Intermittent mobile data (BSNL/Jio 4G), often poor at farm |
| Device | Android mid-range smartphone (₹8,000–₹15,000) |
| Tech literacy | Basic WhatsApp + calling; app-first products are new |
| Decision driver | Neighbor advice, feed company rep, gut instinct |

### 3.2 User Pain Points

1. **No feedback loop** — feeds the same amount every day regardless of tray signal
2. **Feed rep dependency** — relies on company rep who sells more, not less
3. **No cost visibility** — doesn't know FCR until harvest; loss discovered too late
4. **Record-keeping** — paper notebooks lost or never updated
5. **Language barrier** — English-only apps are abandoned

### 3.3 Secondary Users

| User | Role |
|------|------|
| Farm manager | Manages 3–10 farms for an owner; needs multi-farm view |
| Feed company rep | May use data for advisory; potential B2B channel |
| Investor / crop financier | Needs yield and FCR data for loan decisions (future) |

---

## 4. Business Model

### Revenue Streams
- Subscription per pond / per farm
- Commission via feed suppliers (future)
- Data-driven advisory premium

### Pricing
- **Free:** Basic feed tracking
- **Paid:** Smart engine + insights

### Growth Roadmap

| Stage | Revenue | How |
|-------|---------|-----|
| Stage 1 | 0 → 1 Cr | 1,000 farmers × ₹100/month |
| Stage 2 | 1 → 10 Cr | Advisory + insights + regional expansion |
| Stage 3 | 10 → 100 Cr | Platform + marketplace + credit + input linkage |

---

## 5. Product Roadmap

| Version | Status | Features |
|---------|--------|---------|
| **V1** | Live | Pond tracking, feed logging, basic dashboard, blind feeding plan |
| **V1.5** | In Progress | Smart feed engine, tray decision engine, feed status engine, pond value engine, debug dashboard, alerts |
| **V2** | Planned | Behavior layer (habit loop, streaks, ₹ nudges, quick feed), predictive AI, water integration, auto recommendations |

---

## 6. System Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend | Supabase (PostgreSQL + Realtime) |
| Auth | Supabase Auth |
| State | Provider pattern (transitioning to Riverpod in parts) |

### Core Modules

```
lib/
├── core/
│   ├── engines/           ← Feed calculation logic (MOST CRITICAL)
│   │   ├── feeding_engine_v1.dart        ← SSOT for base feed calculation
│   │   ├── smart_feed_engine.dart        ← Hybrid engine (tray × smart × sampling)
│   │   ├── master_feed_engine.dart       ← Orchestrator (water quality + FCR + enforcement)
│   │   ├── feed_state_engine.dart        ← Mode decider + round state
│   │   ├── feed_status_engine.dart       ← Feed safety gate (ALLOW / WARNING / BLOCK)
│   │   ├── tray_decision_engine.dart     ← Multi-round weighted tray scoring
│   │   ├── pond_value_engine.dart        ← Estimated pond harvest value (₹ range)
│   │   ├── feed_plan_constants.dart      ← Round configs + timings
│   │   └── engine_constants.dart         ← ABW targets + survival rates
│   ├── constants/
│   │   └── expected_abw_table.dart       ← DOC → expected ABW lookup (L. vannamei)
│   └── validators/
│       └── feed_input_validator.dart     ← Input safety checks
├── features/
│   ├── pond/              ← Pond management + dashboard
│   ├── feed/              ← Feed schedule, history, smart feed, timeline card
│   ├── tray/              ← Tray logging
│   ├── growth/            ← Sampling (ABW) + mortality
│   ├── harvest/           ← Harvest screen + summary
│   ├── supplements/       ← Supplement mix engine
│   ├── water/             ← Water test logging
│   ├── dashboard/         ← Farm-level dashboard
│   └── debug/             ← Debug dashboard (feed factor validation)
└── services/              ← Supabase service layer
```

### Database Tables (Supabase)

| Table | Purpose |
|-------|---------|
| `ponds` | Pond info — stocking date, seed count, current ABW cache, latest sample date |
| `feed_rounds` | Per-round planned feed (base_feed, planned_amount, is_smart_adjusted) |
| `feed_logs` | Actual feed given per day |
| `tray_logs` | Tray status logs (empty / partial / full / skipped) |
| `sampling_logs` | ABW sampling records |
| `feed_debug_logs` | Smart engine factor trace (tray/smart/sampling/final) |

---

## 7. Screens & Features

### 7.1 Pond Dashboard
- Central view per pond
- Shows: today's feed rounds, DOC, health indicators, pond value estimate
- Feed round cards (FeedTimelineCard) with: mark fed, tray CTA, skip detection
- Smart Feed toggle (activates at DOC > 30)
- 5-tap secret opens debug dashboard (debug builds only)

### 7.2 Farm Dashboard
- High-level overview across all ponds
- Total feed, alerts, performance metrics

### 7.3 Feed Schedule Screen
- Full 120-day feed plan
- Shows planned vs actual per DOC

### 7.4 Feed History Screen
- Past feed logs with cumulative view

### 7.5 Tray Log Screen
- Log tray status after each round (empty / partial / full)
- Triggers smart adjustment for DOC+1, DOC+2, DOC+3

### 7.6 Sampling Screen
- Log shrimp ABW (Average Body Weight)
- Updates pond cache: `current_abw`, `latest_sample_date`

### 7.7 Debug Dashboard
- Validates engine accuracy
- Shows: tray_factor, smart_factor, sampling_factor, final_factor, final_feed
- Critical for pre-scale validation

### 7.8 FeedTimelineCard
- Per-round card in pond dashboard
- States: `done`, `current`, `upcoming`
- Flags: `isPendingTray`, `isTraySkipped`, `isSmartFeed`
- `isTraySkipped = true` → shows ⚠️ skipped banner + "Update Now" CTA

---

## 8. Core Feed Logic (MOST IMPORTANT)

### 8.1 Feed Phases (Mode Decider)

Implemented in: `feed_state_engine.dart` + `smart_feed_engine.dart`

| DOC | Mode | Behavior |
|-----|------|---------|
| 1–14 | `NORMAL` / `blind` | Fixed feed plan, no tray/smart adjustment |
| 15–30 | `TRAY_HABIT` / `transitional` | Tray data collected, **no adjustment applied yet** |
| 31+ | `SMART` | Full hybrid engine active (mandatory tray per round) |

> **Rule:** Smart Feed activates ONLY when DOC > 30 AND `isSmartFeedEnabled = true`. Once activated, it never turns off.

---

### 8.2 Base Feed Calculation

Implemented in: `feeding_engine_v1.dart` (SSOT — all base feed flows here)

**Formula:**
```
baseFeed (kg per 100K shrimp):
  hatchery: 2.0 + (DOC - 1) × 0.15
  nursery:  4.0 + (DOC - 1) × 0.25

adjustedBase = baseFeed × (density / 100_000)
rawFeed      = adjustedBase × trayFactor
finalFeed    = clamp(rawFeed, adjustedBase × 0.7, adjustedBase × 1.3)
```

**Examples:**
- DOC=1, hatchery, 100K shrimp, no tray → **2.00 kg**
- DOC=15, hatchery, 100K shrimp, no tray → **4.10 kg**
- DOC=1, nursery, 100K shrimp → **4.00 kg**
- Density=200K → feed doubles linearly

---

### 8.3 Round Configuration

Implemented in: `feed_plan_constants.dart`

| DOC | Rounds | Splits | Timings |
|-----|--------|--------|---------|
| 1–7 | 4 rows stored, 2 active | 50% / 50% / 0 / 0 | 07:00, 18:00 |
| 8+ | 4 rounds | 25% / 20% / 30% / 25% | 06:00, 11:00, 16:00, 21:00 |

**Feed type by DOC:**
- DOC 1–7: `1R`
- DOC 8–14: `1R + 2R`
- DOC 15–21: `2R`
- DOC 22–28: `2R + 3S`
- DOC 29+: `3S`

---

### 8.4 Tray Factor (Single Source of Truth)

Implemented in: `feeding_engine_v1.dart → trayFactor()`

| Leftover % | Factor | Action |
|-----------|--------|--------|
| 0% (clean tray) | **1.10** | Shrimp hungry → increase +10% |
| 1–10% | **1.00** | On track → no change |
| 11–25% | **0.90** | Moderate leftover → reduce -10% |
| >25% | **0.75** | Heavy leftover → reduce -25% |
| No data | **1.00** | Neutral → no adjustment |

**Tray activation threshold:**
- Hatchery: DOC ≥ 15
- Nursery: DOC ≥ 3

**Per-round tray state adjustment:**
- Empty → +8% (`factor = 1.08`)
- Partial → 0% (`factor = 1.00`)
- Full → -8% (`factor = 0.92`)
- Safety cap: [0.6x, 1.25x] of planned

---

### 8.5 Hybrid Smart Feed Engine

Implemented in: `smart_feed_engine.dart`

**Formula:**
```
finalFeed = baseFeed × finalFactor

finalFactor = trayFactor × smartFactor × effectiveSamplingFactor

where:
  effectiveSamplingFactor = 1.0 if trayFactor ∉ [0.8, 1.2]  ← tray priority
                          = samplingFactor otherwise
```

**Factor priority (highest → lowest): TRAY > SMART > SAMPLING**

#### Layer 1: Tray Factor
- Computed from last 3 days' average tray leftover %
- Maps tray_statuses (empty/partial/full) → leftover %:
  - `empty` majority → 0%, `full` majority → 70%, otherwise → 30%

#### Layer 2: Smart Factor (Growth Signal)
- Based on actual ABW vs expected ABW (from `expectedAbwTable`)
- `ratio = actualABW / expectedABW`
  - ratio > 1.1 → `1.05` (ahead of schedule)
  - ratio < 0.9 → `0.95` (behind schedule)
  - otherwise → `1.00`
- Hard clamped: [0.9, 1.1]
- Returns `1.0` when no ABW data

#### Layer 3: Sampling Factor (Confidence-Decayed)
- Same ratio as smart factor, attenuated by 0.7 to avoid double-counting
- Confidence decay by sample age:
  - ≤ 2 days → 100% weight
  - ≤ 5 days → 70% weight
  - ≤ 7 days → 40% weight
  - >7 days → ignored (0%)
- Hard clamped: [0.9, 1.1]

#### Layer 4: Safety Guardrails
Implemented in: `applySafetyGuards()`

| Rule | Condition | Action |
|------|-----------|--------|
| Daily change limit | Always | Factor clamped to [0.90, 1.10] |
| Increase streak cap | ≥3 consecutive increases | Cap at +5% max |
| Decrease streak cap | ≥3 consecutive decreases | Hold (no further reduction) |
| Overfeeding guard | Current > 130% of base | Hold (no increase) |
| DB hard clamp | Always | adjusted ∈ [base×0.70, base×1.30] |

---

### 8.6 ABW Table (L. vannamei Expected Growth)

Source: `expected_abw_table.dart`

| DOC | Expected ABW (g) |
|-----|-----------------|
| 1 | 0.01 |
| 5 | 0.05 |
| 10 | 0.20 |
| 15 | 0.60 |
| 20 | 1.50 |
| 25 | 3.00 |
| 30 | 5.00 |
| 35 | 7.50 |
| 40 | 10.00 |
| 50 | 16.00 |
| 60 | 22.00 |
| 70 | 30.00 |
| 80 | 38.00 |
| 90 | 45.00 |
| 120 | 65.00 |

> Values between table keys are linearly interpolated. Clamped at DOC 1 (min) and DOC 120 (max).

---

### 8.7 Master Feed Engine (Water Quality + FCR + Enforcement)

Implemented in: `master_feed_engine.dart`

Used when full environmental context is available (feedingScore, DO, ammonia, mortality).

**Pipeline:**
1. **Input Validation** — reject bad data before calculation
2. **Base Feed** → `FeedingEngineV1.calculateFeed()`
3. **Adjustment Factor** → `AdjustmentEngine.calculate()` (DO, ammonia, feeding score, intake%)
   - If DO critically low → **STOP feeding** (factor = 0)
4. **Tray Adjustment** → `TrayEngine.apply()`
5. **FCR Correction** → `FCREngine.correction(lastFcr)`
   - FCR ≤ 1.2 → reward (+feed)
   - FCR > 1.4 → reduce
6. **Enforcement** → `EnforcementEngine.apply()` (prevents huge jumps vs yesterday)
7. **Safety Clamp:**
   - Normal: [60%, 130%] of base
   - Critical condition: [50%, 110%] of base
8. **Output Validation** → fallback to baseFeed if anomaly detected

**Critical condition triggers (triggers tighter clamp):**
- DO < 5 ppm
- Ammonia > 0.2 ppm
- Feeding score ≤ 2
- Intake < 70%
- Mortality > 5% of seed count

**Alert thresholds:**
- DO < 4 → Stop feeding
- Intake < 80% → Overfeeding risk
- Feeding score ≤ 2 → Appetite drop
- Ammonia > 0.1 → High ammonia warning

---

### 8.8 Round Lock Rules

A feed round is locked (cannot be started) if:
1. Previous round is not yet marked as fed (all modes)
2. In SMART mode: previous round's tray is not yet logged

---

### 8.9 TrayDecisionEngine (NEW — V1.5)

Implemented in: `core/engines/tray_decision_engine.dart`

Replaces naive single-round tray logic with **multi-round weighted scoring** + stability rules.

**Scoring:**
| Tray Status | Score |
|-------------|-------|
| EMPTY | +1.0 (shrimp eating well → increase) |
| PARTIAL | 0.0 (neutral) |
| FULL | -1.0 (leftover → reduce) |

**Decision thresholds** (raised to ±0.6 to absorb single-tray noise):

| avgScore | Action | % Change |
|----------|--------|----------|
| ≥ 0.6 | INCREASE | +5% |
| ≤ -0.6 | REDUCE | -10% |
| between | MAINTAIN | 0% |

**Safety rules (always enforced):**
1. **DOC ≤ 30** → always MAINTAIN (blind feed phase; scoring ignored)
2. **Max change cap** → increase ≤ +10%, decrease ≥ -15%
3. **No consecutive reduce** → if previous window also resolved to REDUCE, downgrade to MAINTAIN
4. **Feed floor** → finalFeed ≥ 70% of baseFeed

**Minimum confidence gate:**
- `totalTrays < 4` across the window → always MAINTAIN ("Not enough data")
- Prevents action on 1 round × 2 trays (too noisy)

**Output:** `TrayDecisionResult` — action, percentage, finalFeed, avgScore, roundsUsed, reason (human-readable)

---

### 8.10 FeedStatusEngine (NEW — V1.5)

Implemented in: `core/engines/feed_status_engine.dart`

Validates whether a feed action is **safe before the farmer marks a round done**.

Philosophy: **Guide, don't restrict.**
- `ALLOW` → go ahead, all good
- `WARNING` → risky but farmer can proceed (show banner, don't disable button)
- `BLOCK` → must not feed (daily max reached — rare, hard rule)

**Priority order: BLOCK > GAP > TRAY**

**Decision logic:**

| Check | Condition | Result |
|-------|-----------|--------|
| Daily max reached | feedsCompletedToday ≥ maxRounds | BLOCK |
| First feed of day | lastFeedTime == null | ALLOW (no gap/tray check) |
| Gap too short | elapsed < minGap | WARNING + minutes remaining |
| Tray not logged | DOC > 30, >90 min since last feed, no tray | WARNING |
| All clear | — | ALLOW |

**Gap rules:**
- Blind mode (DOC ≤ 30): min 150 minutes between rounds
- Smart mode (DOC > 30): min 180 minutes between rounds
- Tray warning delay: 90 minutes (gives farmer time to check tray physically)

**Helper methods:**
- `minutesUntilNextFeed()` — unified "when is optimal next feed time" (max of gap clearance vs scheduled time)
- `suggestedFeedsDoneNow(doc)` — used in AddPondScreen to pre-fill chip (based on current clock)

---

### 8.11 PondValueEngine (NEW — V1.5)

Implemented in: `core/engines/pond_value_engine.dart`

Calculates estimated pond harvest value as a **₹ range** with confidence score.

**Default price:** ₹150/kg (configurable later)

**Formula:**
```
biomassKg   = (stockCount × effectiveAbwG × survivalRate) / 1000
baseValue   = biomassKg × pricePerKg
finalValue  = baseValue × behaviourFactor
```

**Behaviour factor adjustments:**
| Signal | Effect |
|--------|--------|
| Fed today | +1% |
| Missed feed | -2% |
| Tray full (overfeeding signal) | -2% |
| Tray empty (under-feed signal) | -1% |

**Confidence scoring (base = 60):**
| Condition | Δ |
|-----------|---|
| DOC > 30 | +10 |
| Feeding consistent (≥3 day streak) | +10 |
| Has tray data | +10 |
| Missing logs today | -10 |
| Range | 0–100 |

**Output:** `PondValue` — min (₹), max (±10% of final), delta (+1%/event), confidence

**When no ABW sample:** uses DOC-based approximation:
- DOC 1: 0.001g, DOC 10: 0.1g, DOC 20: 1.0g, DOC 30: 3.5g, DOC 45: 7.0g, DOC 60: 12.0g, DOC 80: 16.0g, DOC 80+: 20.0g

---

## 9. Insight Engine (Planned — V2)

### Outputs (to be implemented)
- Overfeeding alert: "You are overfeeding by 15%. Potential loss: ₹3,000/week"
- Underfeeding alert
- Profit loss warning
- FCR trend alert

### Current State
- Debug dashboard tracks factor trace for validation
- Alerts generated in `MasterFeedEngine._generateAlerts()` (basic DO/intake/score/ammonia)
- PondValueEngine provides live ₹ estimate on dashboard

---

## 10. Debug & Validation System

Implemented in: `features/debug/`, `feed_debug_logs` table

### Tracked per calculation:
| Field | Description |
|-------|-------------|
| `tray_factor` | From last 3 days tray average |
| `smart_factor` | From ABW growth signal |
| `sampling_factor` | From ABW age-weighted |
| `final_factor` | After safety guardrails |
| `base_feed` | Density-scaled daily base |
| `final_feed` | base × final_factor |
| `abw` | Actual ABW used |
| `expected_abw` | Expected ABW for DOC |
| `mode` | normal / trayHabit / smart |
| `reason` | Human-readable adjustment tag |

> Debug logs must never crash the main feed flow (try/catch everywhere).

---

## 11. User Journey

1. Add farm → Add pond (stocking date, seed count, stocking type)
2. App generates 120-day feed plan automatically
3. Each day: log feed rounds (Mark as Fed)
4. After each round (SMART mode): log tray status
5. Periodically: log ABW sampling
6. Engine adjusts next 1–3 days' feed based on signals
7. Dashboard shows FCR, feed trends, alerts, pond ₹ value
8. Harvest → summary screen

---

## 12. Current Status (as of 2026-04-14)

### Completed
- Flutter app: pond screen, feed rounds, tray logging, sampling, harvest
- Hybrid Smart Feed Engine (tray × growth × sampling × safety)
- TrayDecisionEngine (multi-round scoring, V1.5)
- FeedStatusEngine (ALLOW/WARNING/BLOCK gate, V1.5)
- PondValueEngine (live ₹ estimate, V1.5)
- Feed plan generator (120-day automatic plan)
- FeedTimelineCard (tray skip detection, isSmartFeed flag)
- Debug dashboard (factor trace validation)
- Supabase backend (all core tables)
- Multi-language support (Telugu added)

### In Progress
- Smart engine validation (debug dashboard active)
- Insight / alert system (basic alerts in MasterFeedEngine, full insight engine pending)
- PondValueEngine UI integration on dashboard

### Pending
- Full insight engine (profit loss calculation, FCR trends)
- AI/predictive layer
- Water quality integration into main feed loop
- Marketplace / advisory features

---

## 13. Gaps & Risks

| Gap | Risk | Status |
|-----|------|--------|
| No real-time water quality integration | Feed decisions miss DO/ammonia context | Planned V2 |
| Smart engine not fully validated in field | May over/under-adjust | Debug dashboard active |
| Farmer behavior dependency | Inconsistent tray logging breaks signal | UX improvement needed |
| Sampling frequency low | ABW data gets stale (>7 day decay) | Decay handled in engine |
| No overfeeding profit alert yet | Farmers don't see ₹ impact | PondValueEngine live, insight engine pending |
| TrayDecisionEngine min-confidence gate | <4 tray reads → no action | By design; educate farmers to log consistently |
| FeedStatusEngine warnings | Farmers may ignore warnings and overfeed | UI shows banner, never hard-blocks |
| PondValueEngine price hardcoded | ₹150/kg may not match market price | Make configurable in V2 |

---

## 14. Way Forward (Execution Plan)

### Next 7 Days
- [ ] Validate smart engine via debug dashboard with real pond data
- [ ] Wire PondValueEngine output to pond dashboard UI
- [ ] Implement basic insight alerts (overfeeding %, estimated loss)
- [ ] Finalize feed logic edge cases (DOC transitions, stale ABW)

### Next 30 Days
- [ ] Launch to first 10–20 farmers
- [ ] Collect feedback on tray compliance and engine accuracy
- [ ] Add profit-loss insight screen
- [ ] Track analytics events (see Section 18)

### Next 90 Days
- [ ] Add predictive layer (AI-based feed recommendation)
- [ ] Scale to 100+ farmers
- [ ] Water test integration into feed adjustment
- [ ] Make market price per kg configurable in PondValueEngine

---

## 15. Success Metrics

| Metric | Target |
|--------|--------|
| FCR | ≤ 1.2 per crop |
| Feed saved per pond | ≥ ₹50,000 per crop |
| Daily active farmers | Growing week-over-week |
| Tray compliance rate | > 80% rounds logged |
| Retention | > 60% after 30 days |

---

## 16. Product Differentiation

- **Not a tracking app — a decision engine**
- Focus on ₹ outcome, not raw data
- Simple UI, powerful backend math
- Hybrid tray × growth × sampling is unique to AquaRythu
- FeedStatusEngine (ALLOW/WARNING/BLOCK) prevents farmer from overfeeding due to bad timing

---

## 17. Key Constants & Thresholds (Quick Reference)

| Constant | Value | Source |
|----------|-------|--------|
| Smart mode activation | DOC > 30 | `feed_state_engine.dart` |
| Tray habit DOC range | 15–30 | `smart_feed_engine.dart` |
| Max daily factor change | ±10% | `applySafetyGuards()` |
| Consecutive increase cap | 3 days → max +5% | `applySafetyGuards()` |
| Consecutive decrease cap | 3 days → hold | `applySafetyGuards()` |
| Overfeeding guard | >130% of base → hold | `applySafetyGuards()` |
| DB hard clamp | [70%, 130%] of base | `_applySafetyClamp()` |
| ABW sample freshness | 7 days max | `_latestAbwFromPondData()` |
| Stop feeding DO threshold | < 4 ppm | `MasterFeedEngine` |
| Critical condition DO | < 5 ppm | `MasterFeedEngine` |
| Critical condition ammonia | > 0.2 ppm | `MasterFeedEngine` |
| Tray full leftover proxy | 70% | `_statusesToLeftoverPct()` |
| Tray empty leftover proxy | 0% | `_statusesToLeftoverPct()` |
| Tray partial leftover proxy | 30% | `_statusesToLeftoverPct()` |
| Blind mode min gap | 150 min | `FeedStatusEngine` |
| Smart mode min gap | 180 min | `FeedStatusEngine` |
| Tray warning delay | 90 min post-feed | `FeedStatusEngine` |
| TrayDecisionEngine INCREASE threshold | avgScore ≥ 0.6 | `TrayDecisionEngine` |
| TrayDecisionEngine REDUCE threshold | avgScore ≤ -0.6 | `TrayDecisionEngine` |
| TrayDecisionEngine min tray data | 4 tray reads | `TrayDecisionEngine` |
| TrayDecisionEngine INCREASE cap | +5% (hard cap +10%) | `TrayDecisionEngine` |
| TrayDecisionEngine REDUCE cap | -10% (hard cap -15%) | `TrayDecisionEngine` |
| PondValue default price | ₹150/kg | `PondValueEngine` |
| PondValue confidence base | 60 | `PondValueEngine` |

---

## 18. Farmer Simulation

> **Purpose:** Discover hidden UX problems, confusion points, and drop-off risks before real farmers.

### Persona: Raju, 42, Narsapur, West Godavari

- 10 ponds, 200K shrimp each, L. vannamei
- Knows WhatsApp, uses it daily
- Has never used a farming app before
- Is skeptical — tried one app 2 years ago, deleted after 3 days

---

### Day 0 — First Launch

**Step 1: Registration**
> Raju sees an English login form. He stares at "Email or Phone." He has a phone number but never used email for anything. He tries his phone number and it works.

**Confusion point:** Email-first UI confuses phone-only users. → Ensure phone OTP is prominent.

**Step 2: Farm Setup**
> "Add Farm" screen asks for farm name. Raju types "Raju Farm." He doesn't know what to put for "Location" — expects a village picker, not a text field.

**Confusion point:** Free-text location is unclear. → Add district/mandal dropdown for AP.

**Step 3: Add Pond**
> 10 ponds. He needs to add each one. By pond 3 he is frustrated.

**Drop-off risk:** Manual entry of 10 ponds. → Add bulk pond creation ("Add 5 similar ponds").

**Step 4: Stocking Date**
> Calendar shows English month names. He recognizes the numbers, picks the right date slowly.

**Minor friction:** Telugu month names in calendar would help.

---

### Day 1 — First Feed Round

**Step 5: Open pond dashboard**
> He sees "DOC 1 — 2.00 kg — Round 1 (07:00)." He marks it done. A small tick appears. He smiles.

**What he likes:** Simple, clear, one action.

**Step 6: Second round**
> It's 11:00 AM. Round 2 should be at 18:00 but DOC 1 has only 2 rounds. He taps Round 2 early. FeedStatusEngine returns WARNING: "⏳ Better results if you wait 7 hours." He ignores the warning and marks done anyway.

**Key insight:** Farmers WILL ignore warnings. Warning must also show ₹ risk ("Feeding too early could waste ₹120 of feed today").

---

### Day 14 — Tray Habit Phase Begins

**Step 7: Tray logging**
> At DOC 15, a new "Log Tray" button appears after each round. Raju doesn't know what a tray is in this context. He skips it.

**Critical drop-off point:** First tray log is confusing without onboarding. → Show "What is a tray?" tooltip on first appearance with photo.

**Step 8: Day 16**
> The app shows ⚠️ on Round 2 — "Tray from last round not logged." Raju feels nagged. He considers uninstalling.

**Key insight:** Tray warnings without education feel like pestering. → First 3 missed trays: gentle reminder. After that: "Your feed engine has no data — feeding by guesswork." Frame it as their loss.

---

### Day 30 — Smart Mode Activates

**Step 9: Smart Mode banner**
> "Smart Feed Active. Engine adjusting based on your tray data." Raju doesn't understand what changed. He sees "2.3 kg → 2.5 kg" but doesn't know why.

**Confusion point:** Adjustment shown without explanation. → Show "Tray was empty 3 rounds — shrimp hungry — increased 10%" in plain Telugu.

**Step 10: Pond Value Widget**
> "Pond Value: ₹1,40,000 – ₹1,60,000 (Confidence: 70%)" appears. Raju's eyes widen. He calls his son to show him.

**What he loves:** ₹ outcome is powerful. This is the stickiness hook.

---

### Day 45 — Likely Drop-off Point

**Step 11: ABW sampling**
> App asks for ABW sample. Raju doesn't know how to weigh shrimp in the field. He skips it. Engine confidence drops. Value estimate becomes stale.

**Risk:** ABW data gets stale → engine accuracy drops → farmer loses trust in recommendations.
**Fix:** Add simple ABW guide (photo + Telugu instructions). Offer "Skip — I'll measure next week" with penalty shown ("Confidence drops to 50%").

**Step 12: Consistency**
> After 45 days of logging, Raju notices his FCR is 1.18 vs neighbor's 1.35. He becomes an evangelist.

**Stickiness driver:** Show comparative FCR benchmark ("Your farm vs region average").

---

### Summary: Where Farmers Drop Off

| Stage | Drop-off Trigger | Fix |
|-------|-----------------|-----|
| Onboarding | 10-pond manual entry | Bulk pond creation |
| Day 1 | English-heavy UI | Telugu-first labels |
| Day 15 | First tray log confusing | Photo onboarding tooltip |
| Day 16–20 | Tray nagging without context | Frame as farmer's loss, not app rule |
| Day 30 | Smart mode change unexplained | Show reason in Telugu |
| Day 45 | ABW sampling friction | Simplified guide + skip with cost |

---

## 19. Edge Case Catalog

> **Purpose:** Prevent field bugs and farmer mistrust by testing feed system under 20 real-world conditions.

| # | Scenario | Expected Behavior | Failure Risk |
|---|----------|-------------------|-------------|
| 1 | Farmer feeds at 05:00 before sunrise (before Round 1 schedule) | FeedStatusEngine: ALLOW (first feed of day, no gap check) | None — correctly permitted |
| 2 | Farmer logs Round 2 at 07:30 (30 min after Round 1) | WARNING: "⏳ wait 120 more min" | If ignored and allowed: 2 rounds in 30 min = double dose |
| 3 | Tray logged as FULL for 6 consecutive rounds | TrayDecisionEngine: REDUCE once, then MAINTAIN (no consecutive reduce rule) | Without rule: engine starves pond |
| 4 | ABW sample is 2-week-old (stale) | samplingFactor returns 0% weight → sampling factor = 1.0 (ignored) | Old data driving wrong adjustment |
| 5 | Farmer misses all tray logs for 5 days | Engine: MAINTAIN (no data → no action); TrayDecisionEngine returns "No tray data" | Silent underfeeding if shrimp actually hungry |
| 6 | Stocking density entered as 1,000,000 (10x normal) | baseFeed scales linearly → 20 kg per round; no cap on density | Catastrophic overfeed if typo not caught |
| 7 | DOC transition from 30 to 31 (Smart mode activates) | `feed_state_engine` switches to SMART; tray now mandatory | If tray not logged: round lock activates — farmer blocked |
| 8 | Farmer changes stocking date (edited pond) | All downstream DOC calculations shift; historical logs reference wrong DOC | Engine recalculates from new stocking date; historical mismatch |
| 9 | Network timeout during "Mark as Fed" | Feed log not saved; pond shows round incomplete | Farmer re-marks next day → double log possible |
| 10 | Sampling done twice in same day | Second sample overwrites first; latest_sample_date = today | Acceptable — second measurement more accurate |
| 11 | Farmer gives 3 kg when engine says 2.5 kg (manual override) | Feed log records 3 kg; planned = 2.5 kg; overfeeding flag potential | FCR calculation uses logged amount — correct |
| 12 | ABW entered as 50g at DOC 10 (impossible growth) | expectedABW at DOC 10 = 0.20g; ratio = 250x → smartFactor clamped to 1.1 | Extreme but clamped correctly |
| 13 | Survival rate drops to 10% (mass mortality) | biomassKg = stockCount × ABW × 0.1 → PondValueEngine shows low value | MasterFeedEngine should trigger mortality alert |
| 14 | DOC > 120 (crop extended past plan) | ABW table clamped at DOC 120 → uses DOC 120 value | Feed plan only generated to DOC 120; rounds after may be blank |
| 15 | Farmer has 0 tray logs at DOC 31 (smart mode day 1) | TrayDecisionEngine: validLogs empty → MAINTAIN | Correct; engine waits for data |
| 16 | Two farmers share one phone/account | Both farms show up; each farmer may log rounds for the other's pond | No multi-user/multi-role isolation currently |
| 17 | App used offline; feed logs cached locally | Logs queue until network returns | No offline queue currently — data loss risk |
| 18 | Harvest logged early (DOC 60 instead of DOC 90) | Crop ends; new cycle setup prompted | Summary shows partial crop — FCR may be low (short crop) |
| 19 | Tray logged as EMPTY 10x in a row | TrayDecisionEngine: INCREASE once (DOC 31–33), then MAINTAIN (no consecutive increase cap at engine level, only safety cap in SmartFeedEngine) | May continuously increase until safety clamp |
| 20 | Feed round time logged at 23:59 | Round completion time = 23:59; next day's rounds start DOC+1 | Edge around midnight: if farmer logs midnight+ as same day, round count off |

### Critical Edge Cases to Fix Before Scale

- **#6** — ~~Add density input validation (max 500,000 per pond)~~ **FIXED (BUG-12)** — UI and engine validator now cap at 500K with farmer-friendly error message
- **#9** — Add offline queue / idempotent log endpoint (V2)
- **#16** — Add farm-level user isolation (V2)
- **#17** — Offline-first data layer (V2)
- **#20** — ~~Normalize round timestamps to pond's timezone day boundary~~ **FIXED (BUG-15)** — `_computeDoc` now uses a 5-hour farming-day offset (00:00–04:59 treated as prior day)

---

## 19b. Bug Fix Log (2026-04-14)

> All fixes applied to V1.5 codebase. See inline comments in each file for full reasoning.

| Bug | File(s) | Fix Summary |
|-----|---------|-------------|
| **BUG-01** | `pond_value_engine.dart` | Empty tray was `-1%` (wrong direction). Corrected to `+1%` — shrimp eating well is a positive biomass signal. |
| **BUG-02** | `pond_value_engine.dart` | `_estimatedAbwFromDoc()` removed. Replaced with `getExpectedABW(doc)` from `expected_abw_table.dart` — single SSOT. Was 30–50% below real expected values. |
| **BUG-03** | `smart_feed_engine.dart` | All-skipped tray returned `0.0` leftover → `trayFactor = 1.10` (10% increase on no data). Fixed: all-skipped returns sentinel `-1.0`, filtered before averaging → `trayFactor = 1.0` (neutral). |
| **BUG-04** | `smart_feed_engine.dart` | "Last 3 days" query included today's partial data. Fixed: added `.lt('date', todayStr)` to exclude today's incomplete rounds from the rolling window. |
| **BUG-05** | `smart_feed_engine.dart` | Consecutive streak check used `.limit(1)` (single round per DOC). Fixed: now sums ALL rounds for the DOC (same pattern as `_todayTotalFeed`). |
| **BUG-06** | `smart_feed_engine.dart` | `DateTime.tryParse(dateStr)` returned UTC midnight; `DateTime.now()` is IST. ageDays crossed thresholds 5.5 h early. Fixed: both sides normalized to local midnight. |
| **BUG-07** | `smart_feed_engine.dart` | Tray priority silencing upper boundary was `> 1.2` (never reachable; max trayFactor = 1.10). Fixed: changed to `> 1.08` — symmetric with the lower `< 0.8` guard. |
| **BUG-08** | — | No code fix. Architecture confirmed: `_isLocked()` in `pond_dashboard_screen.dart` enforces hard round lock for DOC > 30. FeedStatusEngine WARNING is a supplementary advisory layer only. |
| **BUG-09** | `tray_decision_engine.dart` | No consecutive INCREASE cap existed (mirror of REDUCE rule). Fixed: consecutive INCREASE dampened from +5% → +3% to absorb runaway escalation on persistent empty trays. |
| **BUG-10** | `feed_status_engine.dart` | DOC 31 Smart Mode transition was abrupt — farmers suddenly blocked with no warning. Fixed: added `smartModeTransitionWarning(doc)` returning escalating 3-day warnings at DOC 28, 29, 30. |
| **BUG-11** | `pond_dashboard_screen.dart` | `isSmartFeedEnabled` boundary was `>= 30` (incorrectly activated Smart badge at DOC 30). Fixed to `> 30`. Auto-enable documented: SmartFeedEngine and round lock always activate at DOC > 30 regardless of DB flag. |
| **BUG-12** | `feed_input_validator.dart`, `add_pond_screen.dart` | Density max was 10M — a 10x phone-keypad typo produced 20 kg/round. Fixed: max 500K, min 1K in both UI validator and engine validator. |
| **BUG-13** | `engine_constants.dart`, `feed_status_engine.dart`, `pond_value_engine.dart` | Feed cost hardcoded at ₹20/kg (3–4x too low). Harvest price hardcoded at ₹150/kg with no shared constant. Both moved to `FeedEngineConstants.feedCostPerKg` (₹70) and `FeedEngineConstants.harvestPricePerKg` (₹150). |
| **BUG-14** | `pond_value_engine.dart` | SSOT and code comment claimed confidence range 0–100. Actual achievable range is 50–90. Comment corrected; SSOT updated here. |
| **BUG-15** | `smart_feed_engine.dart` | `_computeDoc` used `DateTime.now()` — a round logged at 23:59 but written after midnight got wrong DOC. Fixed: farming-day boundary set to 05:00 (`DateTime.now().subtract(5h)`), so 00:00–04:59 resolves to the prior calendar day. |

### Updated Confidence Range (BUG-14 correction)

`PondValueEngine` confidence actual range: **50–90** (not 0–100 as previously stated).

| State | Confidence |
|-------|-----------|
| Min (base - penalty) | 50 |
| Base only | 60 |
| Base + DOC > 30 | 70 |
| Base + 2 bonuses | 80 |
| Base + all 3 bonuses | 90 |

### Updated Tray Priority Silencing Threshold (BUG-07 correction)

`computeFinalFactor()` upper tray-priority boundary changed from `> 1.2` to `> 1.08`:

| trayFactor | Sampling silenced? |
|-----------|-------------------|
| < 0.8 (heavy leftover, factor 0.75) | Yes |
| 0.8–1.08 (trace/partial/moderate) | No |
| > 1.08 (clean empty tray, factor 1.10) | **Yes (BUG-07 fix)** |

---

## 20. Analytics Plan

> **Purpose:** Measure whether the app is actually working — for farmers, for the engine, and for the business.

### 20.1 Event Tracking

| Event | Properties | Purpose |
|-------|-----------|---------|
| `app_open` | farmer_id, pond_count, doc_range | Daily active usage |
| `feed_round_marked` | pond_id, doc, round, feed_qty, mode | Core engagement |
| `tray_logged` | pond_id, doc, round, status | Tray compliance |
| `tray_skipped` | pond_id, doc, round | Drop-off signal |
| `abw_sampled` | pond_id, doc, abw_g | Sampling frequency |
| `smart_mode_activated` | pond_id, doc | Milestone |
| `feed_warning_shown` | pond_id, type (gap/tray) | Warning frequency |
| `feed_warning_ignored` | pond_id, type | How often farmers override |
| `pond_value_viewed` | pond_id, doc, value_min, confidence | ₹ widget engagement |
| `harvest_logged` | pond_id, doc, total_feed_kg, harvest_kg | Final outcome |
| `app_abandoned` | pond_id, last_doc, last_event | Drop-off point |

### 20.2 Retention Metrics

| Metric | Definition | Target |
|--------|-----------|--------|
| D1 retention | Opened app day after install | > 70% |
| D7 retention | Active in first 7 days | > 50% |
| D30 retention | Active in first 30 days | > 40% |
| Feed discipline rate | Rounds logged / rounds scheduled | > 80% |
| Tray compliance rate | Tray logs / rounds (DOC 15+) | > 70% |
| ABW sampling frequency | Samples per 10 DOC | ≥ 1 |

### 20.3 Farmer Feeding Discipline Detection

> **Is the farmer following feeding discipline?**

A farmer is "disciplined" if all of the following for the last 7 days:
- Feed log completed for ≥ 85% of rounds
- Tray logged for ≥ 75% of rounds (DOC 15+)
- No two consecutive rounds logged within 60 minutes of each other

Trigger alert to Raju if discipline score < 50% for 3 consecutive days:
- Farmer-facing: "Your pond may be underperforming — 3 days of missing logs detected."
- Admin: flag for outreach.

### 20.4 Dashboard Structure

**Farm-level:**
- Active ponds count
- Today's total feed logged vs planned
- Tray compliance % (last 7 days)
- Avg FCR across all ponds

**Engine health:**
- Smart mode active ponds count
- TrayDecisionEngine INCREASE / REDUCE / MAINTAIN split (last 30 days)
- Avg sampling age (freshness signal)

**Business:**
- DAU / WAU / MAU
- Ponds by DOC range (early / mid / late crop)
- Churn rate by DOC (when do farmers stop logging?)

---

## 21. Farmer Communication

> **Purpose:** Simple Telugu + English messages for key moments. Rule: 7th standard Telugu, no jargon.

### 21.1 Feed Success

| Context | Telugu | English |
|---------|--------|---------|
| Round marked done | "✅ రౌండ్ 1 పూర్తైంది. తదుపరి రౌండ్ సాయంకాలం 4 గంటలకు." | "✅ Round 1 done. Next round at 4 PM." |
| All rounds done | "🎉 నేటి అన్ని రౌండ్లు పూర్తయ్యాయి. మీ చెరువు బాగుంది!" | "🎉 All rounds done for today. Your pond is on track!" |

### 21.2 Warning — Early Feed

| Context | Telugu | English |
|---------|--------|---------|
| Gap warning | "⏳ గత తినుబండారం ఇంకా జీర్ణమవుతోంది. $X నిమిషాలు వేచి ఉండండి — వృధా తగ్గుతుంది." | "⏳ Last feed still active. Wait $X min — reduces waste." |
| ₹ framing | "⚠️ ముందుగా తినిపిస్తే రోజుకు ₹$Y వృధా అవుతుంది." | "⚠️ Feeding early wastes ₹$Y today." |

### 21.3 Tray Reminder

| Context | Telugu | English |
|---------|--------|---------|
| Tray pending | "🟠 గత రౌండ్ ట్రే చెక్ చేయండి — ఇది తదుపరి తినుబండారాన్ని మెరుగుపరుస్తుంది." | "🟠 Check last round's tray — it improves your next feed." |
| Tray full | "🐟 ట్రేలో మిగులు ఉంది — చేపలు ఎక్కువ తింటున్నాయి. తదుపరి రౌండ్ తగ్గిస్తున్నాం." | "🐟 Feed left in tray — reducing next round." |
| Tray empty | "🐟 ట్రే ఖాళీ అయింది — చేపలు ఆకలిగా ఉన్నాయి. తదుపరి రౌండ్ పెంచుతున్నాం." | "🐟 Tray empty — shrimp are hungry. Increasing next round." |

### 21.4 Smart Adjustment Explanation

| Context | Telugu | English |
|---------|--------|---------|
| Feed increased | "📈 గత 3 రౌండ్లలో ట్రే ఖాళీ అయింది — తినుబండారం $X% పెంచాం ($Y kg → $Z kg)." | "📈 Tray empty 3 rounds — increased feed $X% ($Y kg → $Z kg)." |
| Feed reduced | "📉 ట్రేలో మిగులు ఉంది — $X% తగ్గించాం. ₹$Y ఆదా అవుతుంది." | "📉 Feed leftover detected — reduced $X%. Saving ₹$Y." |

### 21.5 Motivation

| Context | Telugu | English |
|---------|--------|---------|
| 7-day streak | "🔥 7 రోజులు వరుసగా — మీరు చాలా క్రమబద్ధంగా ఉన్నారు! మీ FCR మెరుగుపడుతోంది." | "🔥 7 days straight — great discipline! Your FCR is improving." |
| Pond value milestone | "💰 మీ చెరువు విలువ ₹1,00,000 దాటింది!" | "💰 Your pond value crossed ₹1,00,000!" |
| Poor compliance | "📋 3 రోజులు లాగింగ్ మిస్ అయ్యారు. ఇంజిన్‌కు డేటా లేదు — తినుబండారం అంచనాలు తక్కువ అవుతున్నాయి." | "📋 3 days of missed logs. Engine has no data — estimates weakening." |

---

## 22. Dev QA Checklist

> **Purpose:** Run before every release. One engineer acts as QA reviewer.

### Feed Engine
- [ ] DOC 1–14: Smart mode NOT active; feed follows base plan exactly
- [ ] DOC 15–30: Tray collected but TrayDecisionEngine returns MAINTAIN
- [ ] DOC 31: Smart mode activates; TrayDecisionEngine becomes active
- [ ] Round lock works: cannot start Round 2 without completing Round 1
- [ ] SMART mode: cannot start next round without tray log for previous
- [ ] Base feed doubles linearly when density doubles
- [ ] ABW > 7 days old: samplingFactor = 1.0 (ignored, not crashing)
- [ ] ABW sample entered as 0: engine uses DOC-based estimate, no division by zero
- [ ] finalFeed never exceeds 130% of baseFeed (DB clamp)
- [ ] finalFeed never goes below 70% of baseFeed (DB floor)

### FeedStatusEngine
- [ ] First round of day: always ALLOW (no gap check)
- [ ] Gap < 150 min (blind mode): WARNING shown, not blocked
- [ ] Gap < 180 min (smart mode): WARNING shown, not blocked
- [ ] All rounds done: BLOCK shown, mark-done button disabled
- [ ] Tray warning: only appears after 90 min AND DOC > 30 AND tray missing
- [ ] Farmer can override WARNING and mark done (not force-blocked)

### TrayDecisionEngine
- [ ] DOC ≤ 30: always MAINTAIN regardless of tray data
- [ ] < 4 tray data points: MAINTAIN ("Not enough data")
- [ ] All empty trays: INCREASE +5%
- [ ] All full trays: REDUCE -10%
- [ ] Mixed trays: MAINTAIN
- [ ] Two consecutive REDUCE windows: second becomes MAINTAIN
- [ ] finalFeed ≥ 70% of baseFeed (floor enforced)

### PondValueEngine
- [ ] stockCount = 0: returns ₹0 min/max, no crash
- [ ] survivalRate = 0: returns ₹0, no crash
- [ ] avgWeightG = 0: uses DOC-based estimate
- [ ] confidence clamped to [0, 100]
- [ ] Missed feed reduces estimate by ~2%

### UI
- [ ] Telugu language: all labels translate correctly
- [ ] FeedTimelineCard: `isTraySkipped = true` shows ⚠️ banner
- [ ] FeedTimelineCard: `isSmartFeed = true` shows smart badge
- [ ] Debug dashboard opens on 5-tap (debug build only)
- [ ] Debug dashboard does NOT open in release build

### Data / Backend
- [ ] feed_debug_logs do not block main feed flow on failure
- [ ] Duplicate "mark as fed" is idempotent (second log doesn't double-count)
- [ ] Pond with 0 feed rounds shows empty state, no crash

---

## 23. Launch Checklist

> **Purpose:** Ensure nothing is missed before releasing to first real farmers.

### Technical Checks

- [ ] All engine unit tests passing (feed, tray, status, value)
- [ ] Debug dashboard accessible (5-tap) in debug build; hidden in release
- [ ] Crash-free rate > 99% on test devices
- [ ] App works on Android API 26+ (covers most AP farmer devices)
- [ ] App loads in < 3 seconds on 4G (test on mid-range device, ₹10,000 category)
- [ ] Offline: app shows stale data with "Last synced" timestamp, does not crash
- [ ] Supabase RLS (Row Level Security) enforced — farmers cannot see other farms' data
- [ ] Auth: phone OTP works reliably (test with BSNL SIM)
- [ ] Telugu locale loads on first launch without manual toggle
- [ ] No hardcoded API keys / secrets in source code

### UX Checks

- [ ] Onboarding: first-time farmer can add farm + pond in under 5 minutes
- [ ] Bulk pond add (or clone pond) available if > 3 ponds
- [ ] Tray logging: "What is a tray?" tooltip shown on first appearance
- [ ] Smart mode activation: explanation shown in Telugu on DOC 31
- [ ] Pond value widget: confidence shown alongside ₹ range
- [ ] All WARNING messages include ₹ framing ("wasting ₹X")
- [ ] All critical numbers (feed qty, ABW, pond value) shown in local number format
- [ ] App accessible without email — phone OTP as primary auth

### Real-World Testing Steps

- [ ] 5 farmers from different AP districts test-run for 3 DOC (minimum)
- [ ] Tray logging tested on physical tray at pond site
- [ ] Smart mode switch (DOC 30→31) tested with actual pond data
- [ ] ABW entry tested with field sampling method (net + scale)
- [ ] Network interruption test: turn off WiFi mid-log, resume
- [ ] Low-storage device test (< 500 MB free)

### Post-Launch Monitoring (First 30 Days)

- [ ] Analytics dashboard live (see Section 20.4)
- [ ] Daily active ponds tracked
- [ ] Tray compliance rate tracked daily
- [ ] Feed warning ignored rate tracked (if > 50%, revise messaging)
- [ ] Crash reports monitored via Flutter crashlytics / Sentry
- [ ] WhatsApp group with first 10–20 farmers for fast feedback
- [ ] Weekly call with 2–3 farmers to catch invisible friction
- [ ] Debug logs reviewed weekly to validate engine accuracy

---

---

## 24. Behavior Layer V2 — Habit Engine

> **Goal:** Turn AquaRythu from a tool → into a daily farming habit.

### Core Loop (must always be tight)

```
Feed → See Result (₹) → Get Feedback → Come Back → Repeat
```

If this loop is tight → app becomes addictive.
If broken at any step → app dies.

Every ticket below either tightens this loop or prevents it from breaking.

---

### V2-01 — Live ₹ Growth After Feed (Dopamine)

**What:** After every feed round is marked done, show immediate ₹ feedback.

**UI:**
```
+₹120 today
Pond Value: ₹1,42,300 → ₹1,42,450  ▲
```

**Upgrade:** Micro-animation — value counts up visually (₹1,42,300 → ₹1,42,450 over 1 second). Feels like earning, not logging.

**Rules:**
- Always show the **delta** (₹ gained today), not just the total
- Delta = `PondValueEngine.delta` × rounds completed today
- Source: `PondValueEngine` (Section 8.11)

**Why it works:** Farmers don't care about kg. They care about ₹. Immediate ₹ reward closes the dopamine loop after every action.

---

### V2-02 — Today Progress Bar (Habit Loop)

**What:** Visual progress bar showing feed rounds completed today.

**UI:**
```
Feeding Today:
● ● ○ ○   2/4 feeds completed
```

**Behavior:**
- Each dot fills when round is marked done
- Subtle haptic vibration + soft sound on fill
- Bar turns fully green when all rounds done ("🎉 All done!")

**Why it works:** Humans are wired for completion. An incomplete bar creates a pull to finish. Same mechanism as a to-do list or progress ring.

---

### V2-03 — Feeding Streak System (Emotional Hook)

**What:** Track consecutive days where all feed rounds are logged.

**Logic:**
- All rounds logged for the day → streak +1
- Any missed round → streak resets to 0
- Streak stored per pond

**UI:**
```
🔥 5 Day Streak
```

**Milestone messages (in Telugu + English):**
| Days | Message |
|------|---------|
| 3 | "మంచి క్రమశిక్షణ! / Good discipline!" |
| 7 | "FCR మెరుగుపడుతోంది / FCR is improving" |
| 15 | "Top Farmer level — మీరు ముందుంటున్నారు!" |
| 30 | "🏆 30 రోజులు — మీ చెరువు గెలిచింది!" |

**Why it works:** Farmers are competitive. Streak = identity + emotional hook. Loss of streak motivates return.

---

### V2-04 — ₹-Framed Smart Nudges (Behavior Control)

**What:** Replace generic instruction warnings with ₹ impact statements.

**Old vs New:**

| Situation | Old (generic) | New (₹-framed) |
|-----------|--------------|----------------|
| Gap warning | "Wait 120 minutes" | "⚠️ Feeding now may waste ₹180 today" |
| Tray missing | "Log your tray" | "Log tray → can save ₹300 in next 2 days" |
| Missed feed | "Feed not logged" | "Missed feed → growth slows → ₹ loss likely" |
| Overfeeding | "Feed excess detected" | "Overfeeding detected — ₹250/day at risk" |

**Rule:** Every warning must answer "how much does this cost me?"

**Why it works:** Loss aversion is the strongest behavioral motivator. ₹ framing converts abstract rules into personal financial stakes.

**Source for ₹ values:** `PondValueEngine.delta` + feed cost per kg (₹ feed price × kg wasted).

---

### V2-05 — Always-Visible Next Action (Critical UX Rule)

**What:** Pond dashboard must always show exactly one "next action" prompt. Never show a blank or ambiguous state.

**Logic (priority order):**

| State | Next Action Shown |
|-------|-------------------|
| Round due | "👉 Feed Round 3 in 1h 20m" |
| Round ready | "👉 Feed Round 2 — Ready now" |
| Tray pending | "👉 Log tray for last feed" |
| All done | "✅ All done today. Come back at 6 AM." |
| Smart mode, no tray | "👉 Check tray before next round" |

**Rule:** The dashboard is never "done" — it always guides the next micro-action.

**Why it works:** Reduces cognitive load. Farmer opens app → sees exactly one thing to do → does it → closes app. Repeat = habit.

---

### V2-06 — "Just Tell Me What To Do" Banner (Decision Simplification)

**What:** Top-of-dashboard recommendation banner that shows the engine's decision in one sentence.

**UI:**
```
Today's Recommendation
Feed 2.5 kg now
[Why?]  ← expandable
```

Expanded:
```
Tray was empty last 3 rounds — shrimp are hungry.
Engine increased feed by 5%.
```

**Rules:**
- Default: show result only (no factors, no numbers)
- "Why?" is always optional and collapsible
- In Telugu by default; toggle to English

**Why it works:** Most farmers don't want to understand the engine — they want to know what to do. Surface the decision, hide the math.

---

### V2-07 — Risk Alert Cards (Loss Avoidance)

**What:** Proactive alerts on the dashboard when the engine detects a risky pattern.

**Alert types:**

| Alert | Trigger | Message |
|-------|---------|---------|
| Overfeeding risk | Tray consistently full | "⚠️ Overfeeding detected — possible waste ₹250/day" |
| Underfeeding risk | Tray consistently empty, no increase logged | "⚠️ Shrimp may be hungry — underfeeding risk" |
| Missed tray risk | No tray data in 3+ days, DOC > 30 | "⚠️ Engine blind — 3 days no tray data" |
| Stale ABW | ABW sample older than 7 days | "⚠️ Weight data stale — estimate accuracy dropped" |
| Feed gap too long | Round missed today (DOC > 7) | "⚠️ Missed round — daily growth target at risk" |

**UI rules:**
- Max 1 alert shown at a time (highest priority first)
- Dismiss button (hides for 24h)
- Tap → opens relevant screen (tray log, sampling, etc.)

---

### V2-08 — Farmer Status / Identity Labels (Psychology)

**What:** Show the farmer a label that reflects their behavior. Identity drives behavior — people act in ways consistent with their self-image.

**Labels (based on discipline score from Section 20.3):**

| Score | Label | Display |
|-------|-------|---------|
| ≥ 85% | Disciplined Farmer | "🏅 Disciplined Farmer" |
| 70–84% | On Track | "✅ Your pond is On Track" |
| 50–69% | Needs Attention | "📋 Logging needs attention" |
| < 50% | At Risk | "⚠️ Pond at risk — missing data" |

**Upgrade (V2.5):** Show regional benchmark: "You are in the top 20% of farmers in Krishna district."

**Why it works:** Farmers are community-oriented and pride-driven. A positive label is a reward. A negative label is a motivator.

---

### V2-09 — Quick Feed Mode (Friction Reduction)

**What:** One-tap feed logging with zero data entry required.

**UI:**
```
[ ⚡ Feed Now — 2.5 kg ]
```

**Behavior:**
- Pre-fills quantity from engine recommendation
- Logs round instantly (no confirmation screen)
- Shows ₹ delta immediately after (V2-01)

**When shown:** When a round is due or overdue and the farmer hasn't logged it yet.

**Why it works:** Every extra tap is a drop-off risk. Farmers at the pond have dirty hands, limited attention. One tap = done = habit formed.

---

### V2-10 — Missed Day Recovery UX (Drop-off Prevention)

**What:** When a farmer opens the app after 1+ missed days, show a recovery screen before the normal dashboard.

**UI:**
```
You missed yesterday.
Let's get back on track today 💪

[ Continue → ]
```

**Behavior:**
- Day 1 miss: gentle message, no penalty shown
- Day 2 miss: show streak reset + ₹ estimate impact
- Day 3+ miss: show "Your pond estimate is now based on old data — log today to improve accuracy"
- Never shame — always frame as "let's recover"

**Why it works:** The biggest drop-off risk is the second missed day. If a farmer feels guilt → avoidance → never returns. Recovery framing breaks the guilt loop.

---

### V2 Implementation Priority

| Priority | Ticket | Effort | Impact |
|----------|--------|--------|--------|
| P1 | V2-05 — Next Action clarity | Low | Highest — fixes blank screen drop-off |
| P1 | V2-04 — ₹ nudges | Low | High — replaces all existing warnings |
| P1 | V2-01 — ₹ delta after feed | Medium | High — closes dopamine loop |
| P2 | V2-06 — Just tell me what to do | Medium | High — removes decision fatigue |
| P2 | V2-02 — Progress bar | Low | Medium — habit formation visual |
| P2 | V2-10 — Recovery UX | Low | High — prevents day-2 drop-off |
| P3 | V2-03 — Streak system | Medium | High — long-term retention |
| P3 | V2-07 — Risk alerts | Medium | Medium — loss avoidance |
| P3 | V2-08 — Identity labels | Low | Medium — pride/identity hook |
| P4 | V2-09 — Quick feed mode | High | High — friction reduction at scale |

### V2 Design Principles

1. **₹ first** — every message answers "what does this cost me?"
2. **One action** — dashboard always shows exactly one next step
3. **Hide math, show result** — engine complexity is invisible; farmer sees output only
4. **Loss framing** — warnings are about ₹ risk, not rules
5. **Telugu first** — all V2 copy written in Telugu, English is secondary
6. **Never shame** — missed days = recovery opportunity, not failure

---

*This document is the single source of truth for AquaRythu. Update it when any engine constant, business rule, or product decision changes. Do not keep rules in two places.*
