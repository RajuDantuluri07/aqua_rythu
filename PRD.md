# AquaRythu (అక్వా రైతు)

**MVP LEAN LAUNCH PRD**  
**CEO / CTO / Dev — Decision Document**

### Key Metrics
| Metric | Value |
| :--- | :--- |
| **Max time to log feed** | 10 sec |
| **Opens per day target** | 3–5× |
| **DAU goal (Day 30)** | >60% |
| **Year 1 ARR target** | ₹1 Cr |

### Overview
| Item | Details |
| :--- | :--- |
| **Audience** | CEO · CTO · Lead Developer | Product
| **Purpose** | Single source of truth for build, launch & revenue decisions |
| **Stack** | Flutter (Android) · Supabase · Riverpod · Razorpay |
| **Beta Target** | 1,000 shrimp farmers — Andhra Pradesh & Telangana |
| **Launch Mode** | Free for all farmers → Paid Pro after trust is built |
| **Version** | MVP V1 — March 2026 |
| **Confidentiality** | CONFIDENTIAL • Internal Use Only |

---

## 1. Product Vision & North Star

AquaRythu is a feed decision engine — not a farm management tool. Every feature exists to answer one question: **How much do I feed my shrimp today?**

### 1.1 The One Thing That Matters
Indian shrimp farmers lose 20–30% of potential profit every crop because of poor feed discipline. They overfeed (wasted cost, bad FCR) or underfeed (slow growth, missed harvest window). This is not a data problem — farmers know they are guessing. This is a habit problem. AquaRythu fixes the habit.

| ❌ WITHOUT AquaRythu | ✅ WITH AquaRythu |
| :--- | :--- |
| Farmer guesses feed quantity | Exact feed per round in 1 tap |
| No record of what was fed yesterday | Full feed log since day 1 |
| FCR unknown until crop ends — too late | FCR visible every day — act now |
| Tray observations lost in memory | Tray status → auto-adjusts next round |
| ₹2–5L loss per bad crop | Save ₹1–3L per crop in feed cost |

### 1.2 Design Principles — Non-Negotiable

| # | Principle | Rule — No Exceptions |
| :--- | :--- | :--- |
| 1 | **Speed first** | Feed log must complete in < 10 seconds. Always. Any feature that slows this down is cut. |
| 2 | **Farmer first** | Designed for a farmer with a Class 8 education, basic Android, fishing village connectivity. |
| 3 | **One action per screen** | No screen asks the farmer to do more than one thing. |
| 4 | **No jargon** | FCR, biomass, ABW — shown only with plain-language explanations. Telugu support in V2. |
| 5 | **Default = correct** | Blank inputs auto-fill with the right value. Farmer never stares at an empty form. |
| 6 | **Zero training needed** | New farmer must complete first feed log within 5 minutes of install — no instructions. |

---


## 2. MVP Scope — What's IN and OUT

**RULE:** If a feature doesn't directly help the farmer log feed faster or make a better feed decision — it is OUT of V1.

### 2.1 Feature Scope Table

| Feature | V1 Status | Reason |
| :--- | :--- | :--- |
| Phone OTP Login | ✅ IN | Required. No alternative auth needed. |
| Create Farm + Pond | ✅ IN | Entry point. Must be < 3 minutes for new farmer. |
| Blind Feed Plan (DOC 1–15) | ✅ IN | Core. Auto-generated on pond creation. Zero input from farmer. |
| Tank Page — Blind Mode | ✅ IN | Core. Round cards + MARK AS FED. One tap logging. |
| Tray Check (DOC 16+) | ✅ IN | Core intelligence. Farmer picks tray status → feed auto-adjusts. |
| Tank Page — Tray Mode | ✅ IN | Core. Shows completed round + tray data + current round. |
| Feed History (30-day ledger) | ✅ IN | Accountability. Farmer sees what was fed, total, delta. |
| Feed Schedule View | ✅ IN | Reference. Farmer can see upcoming plan. |
| Growth Monitoring (Sampling) | ✅ IN | Critical. ABW input → live biomass + feed recalculation. |
| Water Quality Log | ✅ IN | Operational completeness. Health score on save. |
| Harvest Hub (Partial + Final) | ✅ IN | Revenue tracking. Required for Pro upsell. |
| Farm Dashboard (KPI + Weather) | ✅ IN | Daily overview. Perceived-value feature for farmers. |
| Profile + Logout | ✅ IN | Basic account management. 
| Supplement Mix | ✅ IN | end to end as planned
| PDF Export | ⬜ IN | once final harvest done - share complete feed used - suppmimantes - all tanks detailes of that Tank



| WhatsApp Alerts | ⬜ V2 | Requires WhatsApp Business API approval. Complex. |
| PDF Export | ⬜ V2 | Not blocking beta. Farmers don't need PDFs to log feed. |
| Telugu Language UI | ⬜ V2 | Significant i18n effort. English sufficient for beta. |
| iOS Build | ⬜ V2 | Android = 95%+ penetration in target market. |
| Pond Comparison Analytics | ⬜ V2 | Needs multi-crop data to be meaningful. |
| Supervisor / Multi-farm View | ⬜ V2 | Enterprise feature. V1 targets individual farmers. |
| Subscription / Razorpay | ⬜ V2 | Phase 2. Free first, paid after trust. |
| Offline Queue + Auto-sync | ⬜ V2 | Non-negotiable. Coastal farms = poor connectivity. |


## 3. Core User Flows

### 3.1 The Primary Flow — Must Work Perfectly
This 6-step flow is the entire product. Everything else is secondary. If this flow has a single UX bug on launch day — the app fails.

| Step | Action | Screen State | Time |
| :--- | :--- | :--- | :--- |
| 1 | **Open App** | Phone from lock screen / notification | 0s |
| 2 | **Select Pond** | Pond tabs — 1 tap | 2s |
| 3 | **See Today Feed** | Round card with kg shown + NOW badge | 3s |
| 4 | **MARK AS FED** | Green button — 1 tap | 8s |
| 5 | **Done** | Round turns green ✓, progress advances | < 10s |
| 6 | **Log Tray (DOC 16+)** | Tray Log button enabled → Tap → Input status → Update | 15s |

### 3.2 New Farmer Onboarding Flow
Must complete in under 3 minutes. Zero support calls allowed.

*   Downloads APK from WhatsApp link or QR code → Opens app
*   Login screen: enters 10-digit mobile number → Send OTP →
*   OTP screen: enters 6-digit code → Verify & Continue →
*   New user detected (no farm) → **STEP 2 of 3: Create Farm** → name + location
*   **STEP 3 of 3: Create Pond** → name, acres, stocking date, PL count, num trays
*   Taps 'Save Pond & Generate Feed Plan →'
*   System writes: farms, ponds, stockings, 30× feed_plans rows in Supabase
*   Lands on Tank Page → DOC 1 → Blind Mode → MARK AS FED visible immediately

**Time target:** Install → First MARK AS FED tap < 5 minutes. Measure this on Day 1.

### 3.3 Daily Feed Log — Beginner Mode (DOC 1–15)
**Goal:** Build farmer habit without friction.
*   **UI:** Shows Time + Planned Feed (kg).
*   **Action:** Taps **MARK AS FED** → feed_log row written.
*   **Restrictions:** NO tray check, NO supplements shown.
*   **Flow:** Round becomes DONE → next round unlocks immediately.

### 3.4 Daily Feed Log — Habit Phase (DOC 16–30)
**Goal:** Introduce behavior (tray checking) but do not enforce.
*   **UI:** Same feed cards + **Tray Feed Mode** badge.
*   **Action:** Taps **MARK AS FED**.
*   **Flow:** App shows **Log Tray Check** CTA (Optional).
*   **Rule:** Farmer can log tray OR skip tray check and proceed to next feed.
*   **Supplements:** Hidden.

### 3.5 Daily Feed Log — Precision Mode (DOC 31+)
**Goal:** Controlled, data-driven farming (Strict System).
*   **Action:** Taps **MARK AS FED**.
*   **Flow:** App shows **Log Tray Check** CTA (Mandatory).
*   **Locking:** Next feed round is **LOCKED** 🚫 until tray is logged.
*   **Unlock:** After tray log → Next round unlocks ✅ + Next feed quantity calculated + Supplements appear.
*   **Note:** Supplements shown ONLY after tray data confirms dosage.

### 3.6 Sampling Flow
*   Sampling icon shows 'Due' badge when DOC > 30 + no sampling in 10 days
*   Farmer taps Sampling → Growth Monitoring screen
*   Enters: Sample Count (e.g. 100) + Total Weight (e.g. 350g)
*   System computes live: ABW = 3.5g, Count/kg = 285, Biomass = 2.8k kg
*   Taps **SAVE & UPDATE GROWTH** → sampling row written
*   Next feed plan rounds recalculate using new ABW

### 3.7 Harvest Flow
*   Harvest Window alert shows when ABW ≥ 90% of target
*   Farmer opens Harvest Hub → sees total yield + revenue to date
*   Logs Partial Harvest: qty, size (count/kg), price per kg
*   Revenue auto-computed: revenue = qty × price
*   Final Harvest → 'Close Crop' confirmation → stocking status = completed
*   Final FCR computed: total_feed / total_yield stored

---

## 4. Screen Specifications — Production Complete
Each screen below is the full implementation spec for the developer. No ambiguity.

### 4.1 Login Screen
| Element | Spec | Priority |
| :--- | :--- | :--- |
| Logo | Image.asset logo.png, height: 90 | P0 |
| Headline | 'Welcome Back' — 26pt bold black | P0 |
| Sub | 'Farmer-friendly digital aquaculture tool' — 15pt grey | P0 |
| +91 field | Container with divider + TextField maxLength:10 numeric | P0 |
| Send OTP → | Full-width green button, disabled until 10 digits, shows spinner on tap | P0 |
| Social proof | 3 CircleAvatars + 'Trusted by 1000+ Farmers' green bold | P1 |
| Footer | TERMS • PRIVACY — grey TextButtons | P2 |
| Supabase call | `signInWithOtp(phone: '+91$phone')` | P0 |

### 4.2 OTP Screen
| Element | Spec | Priority |
| :--- | :--- | :--- |
| Heading | 'Verification Code' — 24pt bold | P0 |
| Sub | 'We've sent a 6-digit code to +91 98*** **321' — masked, dynamic | P0 |
| 6 OTP boxes | SizedBox(50px) TextFields — green focus border, auto-advance, auto-submit | P0 |
| Countdown | '00:59 remaining' — bold; Resend link active only when 0 | P0 |
| Verify button | 'Verify & Continue →' — full-width green, spinner on tap | P0 |
| On success | Check if farm exists → route to Farm creation or Dashboard | P0 |
| Supabase call | `verifyOTP(phone, token, OtpType.sms)` → upsert users row | P0 |

### 4.3 Create Farm + Create Pond (Onboarding)
| Screen | Required Fields | Key Behaviours |
| :--- | :--- | :--- |
| **Step 2/3 — Create Farm** | Farm Name* \| Location (optional) | Progress bar `LinearProgressIndicator(0.67)`; 'Create Farm →' green CTA; INSERT farms row |
| **Step 3/3 — Create Pond** | Pond Name* \| Acres* \| Stocking Date* \| PL Count* \| Num Trays (choice: 2 or 4, or 6 default 4) | Progress bar (1.0); 'Save Pond & Generate Feed Plan →'; writes ponds, stockings, 30× feed_plans in batch |

**Note:** Blind plan generation: 30 rows × (4 rounds) = ~150 feed_plan rows. Use batch insert (chunks of 50). This must succeed before navigating to Tank Page.

### 4.4 Tank Page — The Most Important Screen
This screen is opened 3–5× per day by every farmer. It must be perfect.

| Component | Blind Mode (DOC ≤ 15) | Tray Mode (DOC > 15) |
| :--- | :--- | :--- |
| **Mode badge** | BEGINNER MODE (Blind) | HABIT (16–30) / PRECISION (31+) |
| **Progress bar** | X.X / Y.Y kg — green fill | X.X / Y.Y kg + On Track/Behind status |
| **FCR trend** | Not shown | 'FCR Trend: Improving ↑' or 'Declining ↓' |
| **Info notice** | Amber: 'Tray Feeding starts at DOC 16' | Not shown |
| **Round cards** | Timeline dot+line; DONE(green)/NOW(amber)/UPCOMING(grey) | Same + DONE shows tray grid |
| **Completed card** | Green check, kg logged | Tray grid: Shows all 2 or 4 trays (e.g. T1 EMPTY \| T2 10%...) |
| **Current card** | Amber border, NOW badge, MARK AS FED button | **DOC 31+:** Next round LOCKED 🚫 until current tray logged |
| **MARK AS FED** | Tap → write feed_log, is_blind=true | Tap → write feed_log → auto-open Tray Check |
| **Tank Ops row** | Sampling \| Water Test \| Harvest \| History icons | Same, with Due/Today badges |

**Note:** In DOC 31+ (Precision Mode), the "Next Round" card is visually disabled (greyed out) with a lock icon until the previous round's tray check is completed.

### 4.5 Log Tray Check
| Component | Spec |
| :--- | :--- |
| **Header** | 'Log Tray Check' + 'Tray X of N' (2 or 4) chip top-right — NO AppBar |
| **Sub** | 'Pond 1 • Round X' grey |
| **Status options** | 4 full-width cards (radio-style): Empty 🟢 (+8%) \| Small 🟡 (+3%) \| Half 🟠 (0%) \| Full 🔴 (-8%) |
| **Each option** | Circle icon + label + description. Selected = colour fill + check icon |
| **Requirement** | **Farmer must update status for EACH tray (1..2 or 1..4) defined for the tank** |
| **Observations** | Multi-select FilterChips (optional): Dead shrimp \| Red legs \| White gut \| Weak feeding \| Uneven size |
| **Placeholder** | 'Tray not checked' grey italic — shown until tap |
| **Save button** | 'Next: Tray X →' or 'Save Tray Check' — sticky bottom; writes tray_checks row |
| **On complete** | Compute avg multiplier → update next round planned_qty_kg badge on Tank Page |

### 4.6 Feed History
| Column | Data | Styling |
| :--- | :--- | :--- |
| **DATE** | DD Mon format | Today row = green text, amber background |
| **DOC** | Integer | Plain |
| **R1–R4** | Per-round kg, '—' if skipped | Plain 13pt |
| **TOT** | Sum of R1–R4 | Bold black |
| **Δ (Delta)** | vs previous day | Green ↑ if positive, red ↓ if negative |
| **CUM** | Running total since stocking | Grey 12pt |
| **ST (Status)** | ✓ if complete, ⚠ if partial | Green check / amber warning icon |

### 4.7 Growth Monitoring (Sampling)
| Component | Spec |
| :--- | :--- |
| **ABW Card** | Big number: CURRENT ABW X.Xg \| TARGET X.Xg right corner \| last 3 samples as mini chips |
| **Inputs** | Sample Count (people icon) + Total Weight g (hourglass icon) — side by side |
| **Live compute** | As farmer types: AVG WEIGHT \| COUNT/KG \| BIOMASS — auto-updates 3 green stat chips |
| **Save CTA** | 'SAVE & UPDATE GROWTH' — full-width green |
| **Ledger** | DATE \| DOC \| AVG.WT \| COUNT table — last 5 rows shown |

### 4.8 Water Quality Log
| Component | Spec |
| :--- | :--- |
| **Health Score box** | Amber background, 'Health Score: XX/100.' + 1-sentence AI interpretation |
| **Parameters** | 7 fields: Temp°C \| Salinity PPT \| DO mg/L \| pH \| NH3 mg/L \| NO2 mg/L \| Alkalinity PPM |
| **Display cards** | Each saved value shown as card with coloured left bar: green=in range, amber=warning, red=critical |
| **Health score algo** | Start 100; deduct: DO<4=-20, DO<5=-10, pH outside 7.5–8.5=-10, NH3>0.1=-10, NH3>0.3=-20, NO2>0.1=-10, NO2>0.3=-20 |
| **Save CTA** | 'SAVE & ANALYZE WATER' — writes water_log, computes health_score, fires alert if score<50 |

### 4.9 Harvest Hub
| Component | Spec |
| :--- | :--- |
| **Header** | 'Harvest Hub' + DOC chip + total yield + kebab menu |
| **Log Partial button** | Outlined green — opens modal: date, qty kg, size count/kg, price ₹/kg, auto-shows revenue |
| **Final Harvest button** | Solid green 🏁 — confirmation dialog → closes stocking → computes final FCR |
| **Ledger table** | DATE \| DOC \| TYPE(PARTIAL/FINAL chip) \| QTY \| SIZE \| PRICE |
| **Footer** | TOTAL YIELD: X,XXX kg \| TOTAL REVENUE: ₹X,XX,XXX (green bold) |

### 4.10 Farm Dashboard
| KPI Card | Value Source | Trend Label |
| :--- | :--- | :--- |
| **FEED CONSUMED** | SUM(feed_logs.quantity_kg) current crop | +X% vs last crop |
| **EST. BIOMASS** | SUM(latest sampling.biomass_kg per pond) | Sampling in Xd |
| **FEED EFFICACY** | FCR = totalFeed / totalBiomassGain | ±X.XX from target (1.2) |
| **AVG. GROWTH** | Avg ABW delta per day across ponds | +X.XX g/day vs last week |

*Weather card: static for V1 (Amalapuram, AP). Real API in V1.1.*

---

## 5. Data Model — Supabase Schema
All tables have RLS enabled. Users can only read/write their own farm data. Run `schema.sql` in Supabase SQL Editor (Mumbai region ap-south-1).

### 5.1 Table Overview
| Table | Rows / farmer / crop | Writes per day | Key Purpose |
| :--- | :--- | :--- | :--- |
| **users** | 1 | ~0 | Auth + subscription plan |
| **farms** | 1–3 | 0 | Farm details |
| **ponds** | 1–8 | 0 | Pond config + num_trays (2 or 4) |
| **stockings** | 1 per pond | 0 (on close only) | Crop lifecycle, DOC source |
| **feed_plans** | ~150 per stocking | 0 (generated once) | Blind plan reference |
| **feed_logs** | 4–6 per pond | 4–6 ← CORE TABLE | Every MARK AS FED write |
| **tray_checks** | 4 per feed_log (DOC>15) | 4–6 | Tray status per round |
| **sampling** | 1 per 10 days | 0.1 | ABW + biomass update |
| **water_log** | 2–3 per week | 0.3 | Water quality tracking |
| **harvests** | 1–5 per crop | 0 | Revenue recording |
| **mortality_log** | Optional | 0.1 | Survival tracking |

### 5.2 Critical Schema Rules
*   `feed_logs` is the most-written table — enable Realtime on it.
*   DOC is always computed in app: `DOC = today - stockings.stocking_date + 1`.
*   Blind plan (DOC 1–30) generated in batch on pond creation — ~150 rows, insert in chunks of 50.
*   Tray multiplier caps: never below 60% or above 125% of planned feed.
*   Health score is computed in Dart and stored — no DB triggers needed.
*   Revenue is computed in Dart: `qty_kg × price_per_kg` — not a DB generated column.

### 5.3 Feed Engine Formula

| ABW Range | Feed Rate |
| :--- | :--- |
| < 1g | 15% |
| < 3g | 10% |
| < 5g | 8% |
| < 8g | 6% |

| ABW Range | Feed Rate |
| :--- | :--- |
| < 12g | 4.5% |
| < 18g | 3.5% |
| < 25g | 3.0% |
| ≥ 25g | 2.5% |

**Calculations:**
*   Biomass = `PL_Count × Survival% × ABW_g ÷ 1,000`
*   Daily Feed = `Biomass × FeedRate%`
*   Per-Round = `Daily Feed ÷ NumRounds`

### 5.4 Tray Multiplier Rules
| Tray Status | Label | Multiplier | Next Round Effect |
| :--- | :--- | :--- | :--- |
| **empty** | Empty (0%) | 1.08 | +8% — all feed eaten, increase |
| **small** | Small Leftover (~10%) | 1.03 | +3% — normal, slight increase |
| **half** | Half Left (~50%) | 1.00 | 0% — no change |
| **full** | Full / Untouched (100%) | 0.92 | −8% — overfeeding, reduce |

**Logic:**
*   Weighted average multiplier = `Σ(tray_multiplier) ÷ num_trays` (2 or 4)
*   Next round feed = `planned_qty_kg × avg_multiplier` — capped at [0.6, 1.25] of plan

### 5.5 Rounds Per Day by DOC
| DOC Range | Rounds/Day | Times |
| :--- | :--- | :--- |
| DOC 1–15 | 6 | 06:00 08:30 11:00 13:30 16:00 18:30 |
| DOC 16–30 | 5 | 06:00 09:00 12:00 15:00 18:00 |
| DOC 31–60 | 4 | 06:00 10:00 14:00 18:00 |
| DOC 61+ | 3 | 06:00 12:00 18:00 |

### 5.6 Core System Logic & Feed Modes
Strict logic to transform farmer behavior from follower to optimizer.

**1. Mode Detection**
*   **Beginner (Blind):** DOC 1–15 → No tray, no supplements.
*   **Habit (Optional Tray):** DOC 16–30 → Tray optional, next feed unlocked.
*   **Precision (Strict Tray):** DOC 31+ → Tray mandatory to unlock next feed.

**2. Locking Rules (DOC 31+)**
*   `isNextFeedLocked(round)` returns **TRUE** if:
    *   Current round is FED (`feedDone[round] == true`)
    *   AND Tray NOT logged (`!trayResults.containsKey(round)`)
*   **Result:** User cannot mark next round as fed until tray is logged.

**3. Supplement Visibility**
*   Show supplements **ONLY** in Precision Mode (DOC 31+).
*   **AND** only after previous round tray is logged (dosage depends on consumption).

**4. CTA Visibility Rules**
*   **Mark Feed Done:** Visible if `!isFeedDone`.
*   **Log Tray CTA:** Visible if `isFeedDone` AND (Habit OR Precision Mode) AND `!hasTray`.

**Avoid Mistakes:**
*   ❌ Don’t show tray early (DOC < 16).
*   ❌ Don’t force tray in DOC 16–30 (causes abandonment).
*   ❌ Don’t unlock next feed without tray in DOC 31+ (breaks precision).

---

## 6. Monetisation Strategy

**Phase 1:** FREE for all farmers. No paywall. Build the habit first.
**Phase 2:** Introduce Pro AFTER farmers trust the app and have 30+ days of data.

### 6.1 Why Free First
| Risk If We Paywall Now | Mitigation — Free First |
| :--- | :--- |
| Farmers won't install if they have to pay upfront | Free removes the adoption barrier entirely |
| No data means no proof of value | 30 days of data creates undeniable proof |
| Word of mouth is the growth channel — paid kills it | Free farmers tell their village friends |
| Trust takes time in rural India | Free builds trust; paid comes from trust |
| Competitor copies and offers free | We have data moat by the time they catch up |

### 6.2 Free vs Pro Tiers

| FREE FOREVER (₹0) | PRO ⭐ (₹499/mo OR ₹3,999/year) |
| :--- | :--- |
| ✓ Phone OTP Login | **Everything in Free, plus:** |
| ✓ Unlimited farms + ponds | ✓ FCR insights + trend graphs |
| ✓ Feed logging (all rounds) | ✓ Abnormal feed alerts |
| ✓ Blind plan + Tray mode | ✓ Harvest readiness prediction |
| ✓ Sampling + Water logs | ✓ WhatsApp push alerts |
| ✓ Basic harvest tracking | ✓ PDF crop summary export |
| ✓ Feed history (30 days) | ✓ Pond comparison analytics |
| ✗ FCR insights + trend | ✓ Unlimited crop history |
| ✗ Abnormal feed alerts | ✓ Supervisor multi-farm view |
| ✗ Harvest readiness prediction | |
| ✗ WhatsApp alerts | |
| ✗ PDF crop report export | |

### 6.3 When to Introduce Pro
| Milestone | Action |
| :--- | :--- |
| **1,000 farmers installed + 30 days active** | Analyse usage data — identify power users (avg feed_logs > 3.5). Product is sticky enough to charge for. |
| **200+ farmers complete a full crop** | Have real ROI stories to sell Pro with. Run 'Your FCR improved 0.2 with AquaRythu' campaign. |
| **Pro page built + Razorpay live** | Soft launch Pro to top 20% most active farmers first. |
| **10% conversion achieved** | Activate Pro paywall for new users. |

### 6.4 Revenue Projections
| Scenario | Pro Conversion | MRR | ARR |
| :--- | :--- | :--- | :--- |
| Conservative — 10% of 1,000 beta | 100 Pro subscribers | ₹49,900 | ₹5.99L |
| Base Case — 20% of 1,000 beta | 200 Pro subscribers | ₹99,800 | ₹11.98L |
| Optimistic — 30% of 1,000 beta | 300 Pro subscribers | ₹1,49,700 | ₹17.96L |
| **Year 1 Target (2,000 Pro total)** | **2,000 subscribers** | **₹9,98,000** | **₹1.00 Cr** |
| **Year 2 Target (15,000 Pro total)** | **15,000 subscribers** | **₹74,85,000** | **₹8.98 Cr** |

---

## 7. Success Metrics

**The ONE metric:** Average feed logs per farmer per day. Everything else is secondary. If this number is ≥ 3.5, the product is working.

### 7.1 Primary Success Metrics
| Metric | Target (Day 30) | Target (Day 90) | How to Measure |
| :--- | :--- | :--- | :--- |
| **Feed logs per farmer per day (avg)** | ≥ 3.5 | ≥ 4.0 | `COUNT(feed_logs) / active_users / days` |
| **Daily Active Users (DAU)** | ≥ 60% | ≥ 70% | `Users with ≥1 feed_log today / total_installed` |
| **Time to log feed (median)** | < 10 sec | < 8 sec | App timing event: tap MARK AS FED → log confirmed |
| **7-day retention** | ≥ 50% | ≥ 65% | Users who logged on Day 1 and are still active Day 8 |
| **30-day retention** | ≥ 35% | ≥ 50% | Users active in Week 4 vs Week 1 |
| **Onboarding completion** | ≥ 80% | ≥ 90% | Users who reach first MARK AS FED tap |
| **Crash-free sessions** | ≥ 98% | ≥ 99% | Firebase Crashlytics |
| **Tray check completion (DOC>15)** | ≥ 70% | ≥ 80% | `tray_checks / expected_tray_checks` |

### 7.2 Health Signals to Watch
| Signal | Warning Level | Critical Level | Action |
| :--- | :--- | :--- | :--- |
| Feed logs / day / farmer | < 3.0 | < 2.0 | UX review — Mark as Fed too hard to reach |
| DAU | < 45% | < 30% | Push notification + field agent follow-up |
| Crash rate | ≥ 2% | ≥ 5% | Hotfix release within 24 hours |
| OTP failure rate | ≥ 10% | ≥ 20% | Switch SMS provider immediately |
| Offline sync failures | ≥ 5% | ≥ 15% | Fix queue retry logic |
| Onboarding dropoff | ≥ 25% | ≥ 40% | Simplify farm/pond creation flow |
| 7-day churn | ≥ 60% | ≥ 75% | Emergency: product-market fit investigation |

### 7.3 The North Star Query
Run this in Supabase SQL every morning:

```sql
SELECT
  DATE(logged_at) AS day,
  COUNT(*) AS total_logs,
  COUNT(DISTINCT pond_id) AS active_ponds,
  ROUND(COUNT(*)/COUNT(DISTINCT pond_id),2) AS logs_per_pond
FROM feed_logs
WHERE logged_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(logged_at) ORDER BY day DESC;
```
**Target:** `logs_per_pond` ≥ 3.5 consistently. This number is the product health score.

---

## 8. Beta Launch Strategy — 1,000 Farmers

### 8.1 Target Farmer Profile
| Attribute | Profile |
| :--- | :--- |
| **Geography** | Nellore, Krishna, West Godavari, East Godavari (AP) · Khammam (TG) |
| **Farm Size** | 2–10 acres, 1–6 ponds |
| **Species** | L. vannamei (Pacific white shrimp) — 95%+ of coastal AP farms |
| **Device** | Android smartphone, basic literacy, WhatsApp user |
| **Pain Point** | No idea of current FCR, guessing feed quantities, no crop records |
| **Best Early Adopter** | Farmer who lost ₹2L+ in last crop and is actively looking for solutions |
| **Acquisition Channel** | Field agents, local input dealers, WhatsApp shrimp farming groups |

### 8.2 Distribution Plan
1.  Build APK → upload to Firebase App Distribution
2.  WhatsApp broadcast to field agent network: APK link + QR code
3.  Field agent does first install + onboarding on-farm (first 100 farmers)
4.  Field agent records: install time, first log time, any confusion points
5.  Iterate on UX issues from first 100 before scaling to 1,000

**CRITICAL:** Measure install-to-first-feed-log time for every farmer. If > 5 minutes → fix onboarding before scaling.

### 8.3 Beta Validation Gates
Before proceeding to each phase, these gates must be passed:

| Gate | Criterion | If Failed |
| :--- | :--- | :--- |
| **Gate 1 (Day 3)** | Crash-free rate ≥ 95% on first 100 farmers | Hotfix release; do not scale |
| **Gate 2 (Day 7)** | Onboarding completion ≥ 75% for first 100 | Simplify farm/pond creation |
| **Gate 3 (Day 14)** | Feed logs/farmer/day ≥ 2.5 avg | Review MARK AS FED UX + notification strategy |
| **Gate 4 (Day 30)** | 7-day retention ≥ 45% | Product-market fit review before scaling to 1,000 |
| **Gate 5 (Day 30)** | Feed logs/farmer/day ≥ 3.5 | Scale to 1,000 farmers; begin Pro development |
| **Gate 6 (Day 90)** | 200+ farmers complete a full crop | Begin Pro paid plan activation |

### 8.4 Go/No-Go Decision Framework
| Decision Point | Go Criteria | No-Go Action |
| :--- | :--- | :--- |
| **Scale to 1,000 (Day 30)** | All Gates 1–5 pass | Fix blocking issues; re-test at Day 45 |
| **Launch Pro tier (Day 90)** | Gate 6 + 10+ farmer FCR improvement stories | Extend free period; gather more data |
| **Year 2 expansion** | ₹50L ARR run-rate + team hired | Raise seed funding first |

---

## 9. Build Order — 72-Hour Production Sprint

### 9.1 Hour-by-Hour Sprint
| Block | Hours | Tasks | Done When |
| :--- | :--- | :--- | :--- |
| **A — Supabase Foundation** | 0–4h | Create Mumbai project · Run schema.sql · Enable phone auth · Enable Realtime · Get URL + key | flutter analyze passes, Supabase dashboard shows tables |
| **B — Auth Flow** | 4–8h | Paste Supabase URL+key · flutter pub get · Test real OTP · Verify new user → onboarding routing | Login → OTP → Create Farm → Create Pond works end-to-end |
| **C — Core Feed Flow** | 8–18h | Pond creation generates 30 blind plan rows · MARK AS FED writes to DB · Tray Check writes · Next round auto-adjusts | Can log 4 complete rounds in a single day; data visible in Supabase |
| **D — Analytics Screens** | 18–28h | Sampling writes avg_weight_g · Water log writes health_score · Harvest modal saves · Feed history reads · Dashboard reads live KPIs | All 10 screens functional with real Supabase data |
| **E — Offline Queue** | 28–34h | SharedPreferences queue · Connectivity detection · Feed log writes go to queue first · Sync on reconnect | Feed logs survive 15-minute network outage and sync correctly |
| **F — Polish + APK** | 34–48h | Remove all print() · Verify applicationId · minSdk = 23 · flutter analyze clean · flutter build apk | APK < 50MB · installs on Android 6.0+ · no crashes |
| **G — Field Test** | 48–72h | Install on 10 real farmer phones · Measure metrics · Fix blockers · Distribute to first 100 beta farmers | All 10 test farmers complete first feed log without assistance |

### 9.2 Pre-Launch Checklist
| # | Check | How to Verify |
| :--- | :--- | :--- |
| 1 | `applicationId = com.aquarythu.app` | android/app/build.gradle |
| 2 | Supabase URL + anon key are production values | lib/main.dart — not placeholder |
| 3 | `initialRoute = AppRoutes.splash` (NOT dashboard) | lib/main.dart |
| 4 | OTP '123456' hardcode removed | `grep '123456' lib/` — must return 0 results |
| 5 | INTERNET + SMS permissions in AndroidManifest | android/.../AndroidManifest.xml |
| 6 | RLS policies active on all tables | Supabase dashboard → Auth → Policies |
| 7 | Realtime enabled on feed_logs | Supabase → Database → Replication |
| 8 | All `print()` removed | flutter analyze → 0 warnings |
| 9 | `debugShowCheckedModeBanner: false` | lib/main.dart |
| 10 | Offline queue tested | Manual test: log in airplane mode → reconnect → data in Supabase |
| 11 | OTP works on Airtel, Jio, BSNL, Vi SIM cards | Test all 4 carriers |
| 12 | Blind plan generation: 30 rows written | Supabase feed_plans table check |
| 13 | Tray check: next round shows AUTO ADJUSTED badge | Manual test DOC > 15 pond |
| 14 | Harvest close: stocking status = 'completed' | Supabase stockings table check |
| 15 | APK tested on Samsung SM E146B (Android 15) | 30 min session test — no crashes |

---

## 10. What Success Looks Like

*   **Day 30**: 1,000 farmers onboarded
*   **Day 60**: avg 3.5+ logs/day/farmer
*   **Day 90**: 200+ crops tracked
*   **Month 6**: ₹50L+ ARR

### 10.1 The Flywheel
| Stage | What Happens | Outcome |
| :--- | :--- | :--- |
| **1. Habit** | Farmer logs feed every day for 30 days | High retention + trust |
| **2. Insight** | FCR data accumulates → farmer sees improvement | Proof of value |
| **3. Upgrade** | Farmer pays for Pro to keep and improve insights | Revenue |
| **4. Advocacy** | Pro farmer shows results to village neighbours | Word-of-mouth growth |
| **5. Network** | More farms → better benchmarks → smarter alerts | Product improves |
| **6. Moat** | 2 years of crop data per farmer = impossible to switch | Retention lock-in |

### 10.2 Unit Economics at Scale
| Metric | Month 1 | Month 6 | Month 12 | Month 24 |
| :--- | :--- | :--- | :--- | :--- |
| **Farmers Installed** | 1,000 | 5,000 | 15,000 | 50,000 |
| **Pro Subscribers** | — | 300 | 2,000 | 15,000 |
| **MRR** | ₹0 | ₹1.49L | ₹9.98L | ₹74.85L |
| **ARR** | ₹0 | ₹17.96L | ₹1.00 Cr | ₹8.98 Cr |
| **CAC (cost/farmer)** | ₹200 | ₹150 | ₹100 | ₹80 |
| **LTV (Pro, annual plan)** | ₹3,999 | ₹3,999 | ₹3,999 | ₹3,999 |
| **LTV/CAC** | — | 26:1 | 40:1 | 50:1 |
| **Gross Margin** | — | ~85% | ~87% | ~90% |

### 10.3 The Founding Insight
Every shrimp farmer in India will eventually use a digital tool to manage feed. The question is only which app. AquaRythu wins by being the **fastest to log**, **first to build trust**, and **deepest in the data** by the time competitors arrive.

> **BUILD FAST. LOG EVERY FEED. SAVE EVERY SHRIMP.**  
> AquaRythu — Amalapuram to ₹100 Cr ARR