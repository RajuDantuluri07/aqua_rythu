# Aqua Rythu — Product Document

**Version:** 1.0 (MVP)  
**Last Updated:** 2026-04-05  
**Platform:** Flutter (Android / iOS)  
**Backend:** Supabase  

---

## 1. Product Overview

**Aqua Rythu** is a mobile farm management app built for shrimp aquaculture farmers. It digitises the daily operational workflow of a shrimp farm: stocking, feeding, water quality monitoring, growth sampling, supplement management, and harvest recording.

The core insight the product is built around is that **most shrimp crop losses are caused by incorrect feeding** — either overfeeding (causing water quality degradation) or underfeeding (causing poor growth). Aqua Rythu provides an intelligent, DOC-aware (Day of Culture) feed schedule that auto-adjusts based on real-world pond signals.

---

## 2. Target Users

| User | Role | Primary Need |
|---|---|---|
| Farm Owner | Manages 1–10 ponds, reviews financials | Track performance, compare ponds |
| Farm Manager | Daily operations lead | Execute feed schedule, log water & trays |
| Field Worker | Feeds shrimp, logs trays | Quick round-by-round feed logging |

---

## 3. Core Features

### 3.1 Authentication
- Email + password sign-up / sign-in via Supabase Auth
- Auto session persistence (stays logged in across app restarts)
- Password reset via email deep link
- OTP screen for mobile verification (sms_autofill)

---

### 3.2 Farm Management
- Create and manage multiple farms
- Each farm has metadata: name, location, farm type (Intensive / Semi-Intensive)
- Farm settings (farm type) affect water quality thresholds and health scoring
- Add / edit / delete farms

---

### 3.3 Pond Management
Each farm contains one or more **Ponds**. A pond represents a single aquaculture unit for one crop cycle.

**Pond setup fields:**
| Field | Description |
|---|---|
| Name | Pond identifier |
| Area (acres) | Used to scale feed amounts |
| Stocking Date | Determines DOC calculation |
| Seed Count (PL) | Post-larvae stocked; basis for biomass |
| PL Size | Post-larvae size at stocking |
| Number of Trays per pond |

**Pond lifecycle states:**
- `active` — crop is running
- `completed` — crop cycle ended (harvested)

After a final harvest, a **New Cycle** can be started (restocking the same pond).

---

### 3.4 Pond Dashboard (Daily Operations Hub)
The central screen for daily work. Farmers see:

1. **Today's Feed Rounds** — 4 feeding rounds per day at 6 AM, 10 AM, 2 PM, 6 PM
2. **Feed Amount per Round** — calculated and stored in the database
3. **Round Status** — Pending / Current / Done / Locked
4. **Tray Logging** — After DOC 30, farmers log tray observations per round 
5. **Quick Links** — Water test, growth sampling, feed history, harvest, supplements

**Round lock logic:** Each round is locked until the previous round is marked done, enforcing sequential feeding.

---

### 3.5 Feed Scheduling (Blind Feeding Phase: DOC 1–30)

The first 30 days of a crop cycle are called the **Blind Feeding Phase** — shrimp are too small to observe directly, so feeding follows a fixed scientific plan.

**How it works:**
1. When a pond is created, a feed plan for DOC 1–30 is automatically generated (4 rounds/day × 30 days = 120 feed round records)
2. Feed amounts are sourced from a `feed_base_rates` table in Supabase, normalised to a target of **235 kg** total for 100,000 PL / 1 acre
3. Feed amounts are scaled by: `(stockingCount / 100,000) × (pondArea / 1 acre)`
4. Each day is split into 4 equal rounds (25% each)
5. Feed types rotate by week: 1R → 1R+2R → 2R → 2R+3S → 3S

**Feed type schedule:**
| DOC | Feed Type |
|---|---|
| 1–7 | 1R |
| 8–14 | 1R + 2R |
| 15–21 | 2R |
| 22–28 | 2R + 3S |
| 29+ | 3S |

**Auto-recovery:** If feed rounds are missing for today (e.g. data was deleted), the dashboard auto-regenerates the feed plan.

---

### 3.6 Smart Feeding Engine (Post-DOC 30 — Future)

> **Status: Disabled for MVP.** The infrastructure exists; it will be enabled post-launch.

After DOC 30, shrimp are large enough that feeding should be adjusted daily based on observed signals. The Smart Feed Engine (`MasterFeedEngine`) calculates a recommended daily feed using 7 layers of logic:

| Step | Engine | What it does |
|---|---|---|
| 1 | `FeedCalculationEngine` | Base feed = biomass × feeding rate (from ABW/DOC curves) |
| 2 | `AdjustmentEngine` | Adjusts ±% based on water quality + feeding response |
| 3 | `TrayEngine` | Further adjusts based on leftover feed in trays |
| 4 | `FCREngine` | Rewards low FCR (efficient fish), penalises high FCR |
| 5 | `EnforcementEngine` | Corrects for yesterday's over/underfeeding |
| 6 | Safety Clamp | Keeps final feed between 50–130% of base feed |
| 7 | `FeedInputValidator` | Final sanity check; falls back to base feed if anomaly detected |

**Adjustment Engine rules:**
| Signal | Change |
|---|---|
| Feeding score ≥ 4 | +5% |
| Feeding score = 3 | -10% |
| Feeding score ≤ 2 | -25% |
| Intake > 95% | +5% |
| Intake < 85% | -10% |
| Intake < 70% | -25% |
| DO < 4 ppm | **STOP feeding (0%)** |
| DO < 5 ppm | -30% |
| Temperature > 32°C | -10% |
| pH change > 0.5 | -10% |
| Ammonia > 0.1 | -20% |
| Mortality ≥ 5%/day | -20% |
| Mortality 2–5%/day | -10% |
| Mortality < 2%/day | -5% |

---

### 3.7 Feed Tray Logging

Feed trays are physical feeding checkpoints placed in each pond. After each feed round (post DOC 30), the farmer checks the tray to see how much feed remains.

**Tray statuses:**
- `full` — tray is full of leftover feed (overfeeding)
- `partial` — some leftover remains
- `empty` — all feed consumed (good response)

Multiple trays per pond are aggregated by average score into a single round-level tray status.

---

### 3.8 Water Quality Testing

Farmers log water test results to track pond health.

**Parameters tracked:**
| Parameter | Unit | Concern Threshold |
|---|---|---|
| pH | — | < 7.5 or > 8.5 |
| Dissolved Oxygen | ppm | < 4 (critical), < 5 (warning) |
| Salinity | ppt | < 8 or > 28 |
| Ammonia | ppm | > 0.1 (warning), > 0.3 (critical) |
| Nitrite | ppm | > 0.1 (warning), > 0.3 (critical) |
| Alkalinity | mg/L | < 100 or > 200 |

**Health score:** Each log generates a 0–100 health score. Score ≥ 80 = Excellent, 60–80 = Moderate, < 60 = Critical.

Thresholds are calibrated by farm type: **Semi-Intensive** farms get more lenient DO and ammonia thresholds.

Actionable recommendations are generated for each alert condition (e.g. "Add agricultural lime to raise pH").

> **Note:** Water logs are currently stored in-memory only (not persisted to Supabase). This is a known MVP limitation.

---

### 3.9 Growth Sampling

Farmers periodically net a sample of shrimp and weigh them to measure **Average Body Weight (ABW)**.

**Data captured:**
- DOC at sampling
- Number of shrimp sampled
- Total weight of sample
- Calculated ABW

ABW data feeds into the Smart Feed Engine to replace the standard growth curve with actual observed growth.

> **Note:** Growth logs are currently in-memory only.

---

### 3.10 Supplements Management

Farmers apply probiotics, vitamins, mineral mixes, and water treatments on a schedule.

**Two supplement types:**

| Type | Dosage Basis | Timing |
|---|---|---|
| Feed Mix | Per kg of feed applied | Per feeding round (R1–R4) |
| Water Mix | Per acre of pond area | Time-based schedule |

**Supplement features:**
- Define supplement plans with start/end DOC
- Set which feeding rounds or time of day to apply
- Pause/resume plans
- Auto-calculate dosage at the time of feeding
- Log applications (idempotent — won't double-log per round/day)
- Support goals: Growth Boost, Disease Prevention, Water Correction, Stress Recovery

---

### 3.11 Harvest Tracking

Farmers log harvest events (partial, intermediate, or final harvests).

**Data captured:**
- Date, DOC
- Quantity harvested (kg)
- Count per kg (shrimp size)
- Price per kg
- Expenses
- Notes
- Type: `partial` / `intermediate` / `final`

**Computed metrics:**
- Total revenue = quantity × price
- Profit = revenue − expenses
- A final harvest marks the crop cycle as complete

> **Note:** Harvest data is currently in-memory only.

---

### 3.12 FCR Tracking

**Feed Conversion Ratio (FCR)** = Total feed given ÷ Total weight gain

The app tracks cumulative feed through the `feed_history_logs` table. FCR is used by the Smart Feed Engine to reward efficient ponds and reduce feed for inefficient ones.

| FCR | Rating | Feed Adjustment |
|---|---|---|
| ≤ 1.0 | Exceptional | +15% |
| ≤ 1.2 | Very Good | +10% |
| ≤ 1.3 | Good | +5% |
| ≤ 1.4 | Acceptable | 0% |
| ≤ 1.5 | Poor | -10% |
| > 1.5 | Wasteful | -15% |

---

## 4. Data Architecture (Supabase Tables)

| Table | Purpose |
|---|---|
| `profiles` | User profile records linked to Supabase Auth |
| `farms` | Farm metadata per user |
| `ponds` | Pond details per farm |
| `feed_rounds` | Feed schedule: one row per (pond, DOC, round) |
| `feed_base_rates` | Reference table: base feed kg per DOC |
| `feed_history_logs` | Daily feed summary logs |
| `water_tests` | (Planned) Water quality logs |

**Key column:** `feed_rounds.is_manual` — flags rounds where a farmer manually overrode the calculated amount.

---

## 5. Feed Plan Architecture Summary

```
Pond Created
    └─► generateFeedSchedule() [PondService]
            └─► Inserts 120 rows (DOC 1–30, 4 rounds each)
                    All amounts = 2.5 kg (flat placeholder)

Feed Schedule Screen
    └─► generateFeedPlan() [FeedPlanGenerator]
            └─► Fetches base rates from Supabase
            └─► Normalises to 235 kg baseline
            └─► Scales by (seedCount/100K) × (area/1 acre)
            └─► Updates feed_rounds with correct amounts

Daily Dashboard
    └─► PondService.getTodayFeed()
            └─► Reads feed_rounds for today's DOC
            └─► Displays 4 rounds to farmer
            └─► Auto-recovers if data missing
```

---

## 6. Known MVP Limitations

| Area | Limitation |
|---|---|
| Water logs | In-memory only, cleared on app restart |
| Growth logs | In-memory only |
| Harvest data | In-memory only |
| Smart Feed (DOC 31+) | Engine exists but disabled; falls back to empty |
| Feed history | Logged to DB but UI doesn't surface trends |
| Multi-farm switch | Supported but no farm-level analytics |
| Offline mode | No offline support; all data requires network |
| Push notifications | Not implemented (round reminders, alerts) |

---

## 7. Screens Map

```
App Start
 └─ Splash (2s)
     └─ AuthGate
         ├─ LoginScreen (unauthenticated)
         └─ DashboardScreen (authenticated)
             ├─ FarmSelector
             ├─ PondDashboardScreen (per pond)
             │   ├─ FeedRoundCards (×4)
             │   ├─ TrayLogScreen
             │   ├─ WaterTestScreen
             │   ├─ SamplingScreen
             │   ├─ FeedScheduleScreen
             │   ├─ FeedHistoryScreen
             │   ├─ HarvestScreen / HarvestSummaryScreen
             │   ├─ SupplementMixScreen
             │   └─ NewCycleSetupScreen
             └─ ProfileScreen
```

---

## 8. Glossary

| Term | Definition |
|---|---|
| DOC | Day of Culture — number of days since stocking date |
| ABW | Average Body Weight of shrimp (grams) |
| PL | Post-Larvae — shrimp seedlings stocked into the pond |
| FCR | Feed Conversion Ratio = feed given ÷ weight gained |
| Blind Feeding | Feed schedule for DOC 1–30 when shrimp are too small to observe |
| Tray | Physical feeding tray placed in pond to monitor feed intake |
| Round | One feeding session per day (4 rounds/day) |
| Biomass | Total estimated weight of live shrimp in pond |
| Smart Feed | AI-driven feed adjustment post-DOC 30 based on real signals |
