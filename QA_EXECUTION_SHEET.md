# Aqua Rythu — QA Execution Sheet

> **Version:** 1.0 | **Date:** 2026-05-17 | **Total Cases:** 125
> **Columns:** Test Case ID · Module · Scenario · Steps · Expected Result · Priority · Severity · Status · QA Notes · Bug ID · Retest Status · Tested By · Test Date
> **Status Values:** Pass · Fail · Blocked · Skip · In Progress
> **Retest Values:** Pass · Fail · Pending · N/A

---

## How to Use
- **Status**: Update to Pass/Fail/Blocked after each execution
- **QA Notes**: Record actual result if different from expected; note environment details
- **Bug ID**: Fill with issue tracker ID (e.g., BUG-042) when test fails
- **Retest Status**: Update after bug fix is deployed
- **Tested By**: Tester initials or name
- **Test Date**: DD-MMM-YYYY format

---

## MODULE 1 — Authentication

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-AUTH-001 | Authentication | Successful login with valid credentials | 1. Launch app → 2. Wait for session check → 3. Enter email farmer@test.com → 4. Enter password Test@1234 → 5. Tap Login | HomeScreen loads; farm data visible; bottom nav shows 3 tabs; no error snackbar | P0 | S1 | | | | | | |
| TC-AUTH-002 | Authentication | Wrong password shows user-friendly error | 1. Open Login → 2. Enter valid email → 3. Enter WrongPass999 → 4. Tap Login | Friendly error shown; no raw Supabase error; stays on Login screen; no crash | P0 | S1 | | | | | | |
| TC-AUTH-003 | Authentication | Session persists across force-close and relaunch | 1. Log in → 2. Verify HomeScreen → 3. Force-close app → 4. Relaunch app | Navigates directly to HomeScreen; no re-login required; existing data visible | P0 | S1 | | | | | | |
| TC-AUTH-004 | Authentication | Onboarding shown once on first install | 1. Fresh install, clear SharedPrefs → 2. Launch app → 3. Complete onboarding → 4. Relaunch | Onboarding shown first launch only; never shown again; `has_seen_onboarding` flag set | P1 | S3 | | | | | | |
| TC-AUTH-005 | Authentication | New user signup creates account and navigates home | 1. Tap Sign Up → 2. Enter unique email+password → 3. Tap Create Account | Account created; HomeScreen shown with empty state; users table row inserted | P1 | S1 | | | | | | |
| TC-AUTH-006 | Authentication | Rate limiting after repeated failed logins | 1. Enter wrong password 6× rapidly → 2. Attempt 7th login | Rate-limit message shown in plain language; no crash; app remains usable | P2 | S3 | | | | | | |

---

## MODULE 2 — Farm Management

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-FARM-001 | Farm Management | Create first farm successfully | 1. Tap Add Farm → 2. Enter name: Coastal Shrimp Farm, location: Nellore AP → 3. Tap Create Farm | Farm created; farms table row inserted with correct user_id; HomeScreen reflects new farm | P0 | S1 | | | | | | |
| TC-FARM-002 | Farm Management | FREE tier farm limit blocks second farm | 1. FREE user with 1 farm → 2. Attempt to create 2nd farm | farm_limit_bottom_sheet appears; add-farm form not shown; upgrade CTA visible | P0 | S1 | | | | | | |
| TC-FARM-003 | Farm Management | Edit farm name updates everywhere | 1. Navigate to farm settings → 2. Change name to Delta Aqua Farm → 3. Save | Name updated in DB; all UI references (header, switcher, profile) reflect new name immediately | P1 | S3 | | | | | | |
| TC-FARM-004 | Farm Management | Delete farm cascades to all child records | 1. Farm with 2 ponds with full data → 2. Tap Delete Farm → 3. Confirm | All child records deleted; farm removed from list; no orphaned rows in DB | P1 | S2 | | | | | | |
| TC-FARM-005 | Farm Management | Farm switcher changes active farm context | 1. PRO user with Farm A (2 ponds) and Farm B (1 pond) → 2. Open farm switcher → 3. Select Farm B | HomeScreen updates to Farm B's 1 pond; KPIs recalculate; no Farm A data mixed in | P2 | S2 | | | | | | |

---

## MODULE 3 — Pond Management

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-POND-001 | Pond Management | Create pond with atomic feed schedule | 1. Tap Add Pond → 2. Fill: name, area=1.2ac, seed=150K, PL10, today, HatcherySmall, trays=4, feed brand → 3. Tap Create | Pond + 30 feed_rounds created atomically via RPC; pond card on HomeScreen; Feed tab shows plan | P0 | S1 | | | | | | |
| TC-POND-002 | Pond Management | Pond creation idempotent on double-tap | 1. Fill form → 2. Double-tap Create Pond before navigation | Exactly 1 pond created; operationId dedup prevents second insert; DB count = 1 | P0 | S1 | | | | | | |
| TC-POND-003 | Pond Management | FREE tier pond limit blocks 4th pond | 1. FREE user with 3 ponds → 2. Attempt 4th pond | pond_limit_bottom_sheet appears; form not shown; upgrade CTA visible | P0 | S1 | | | | | | |
| TC-POND-004 | Pond Management | Edit pond seed count mid-cycle updates engine | 1. Navigate to Edit Pond → 2. Change seed count 150K→120K → 3. Save | Pond updated; next feed recommendation uses 120K; existing feed_logs unmodified | P1 | S2 | | | | | | |
| TC-POND-005 | Pond Management | Delete pond cascades all associated data | 1. Pond at DOC=45 with full data → 2. Tap Delete → 3. Confirm | All records deleted; pond removed; HomeScreen KPIs recalculate without deleted pond | P1 | S2 | | | | | | |
| TC-POND-006 | Pond Management | New cycle setup resets DOC and clears cycle data | 1. Log final harvest → 2. Tap Start New Cycle → 3. Enter new stocking details → 4. Confirm | DOC resets to 1; cycle tables cleared; 30 new feed_rounds generated; old harvests preserved | P1 | S2 | | | | | | |
| TC-POND-007 | Pond Management | Seed count above 500K is rejected | 1. Enter seed count = 600,000 → 2. Submit form | Validation error: must be ≤ 500,000; form not submitted | P2 | S3 | | | | | | |
| TC-POND-008 | Pond Management | Future stocking date shows DOC ≥ 1 | 1. Set stocking date = 3 days in future → 2. Submit | DOC = 1 (clamped, not negative); no crash; consistent behavior communicated | P2 | S3 | | | | | | |

---

## MODULE 4 — DOC Calculation

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-DOC-001 | DOC Calculation | DOC = 1 on stocking day | 1. Create pond with stocking_date = today → 2. Navigate to Overview tab | DOC shows exactly 1 (formula: 0 days elapsed + 1 = 1) | P0 | S1 | | | | | | |
| TC-DOC-002 | DOC Calculation | DOC = 31 after 30 days elapsed | 1. Pond stocked 30 days ago → 2. Navigate to Overview | DOC = 31 (30 + 1); not 30 or 32 | P0 | S1 | | | | | | |
| TC-DOC-003 | DOC Calculation | DOC gates blind vs smart feed mode | 1. Pond A DOC=29; Pond B DOC=31; PRO → 2. Check feed mode on each | Pond A = blind only; Pond B = smart with ramp factor (0.75 at DOC 31) | P0 | S1 | | | | | | |
| TC-DOC-004 | DOC Calculation | Null stocking_date handled gracefully | 1. Set stocking_date = NULL in DB → 2. Open affected pond | No app crash; error state shown; other ponds unaffected; edit-to-fix CTA shown | P0 | S1 | | | | | | |
| TC-DOC-005 | DOC Calculation | DOC increments correctly at local midnight | 1. Device in IST → 2. Check DOC at 11:30 PM IST → 3. Check at 12:01 AM next day | DOC increments at consistent boundary; no off-by-one across midnight | P1 | S2 | | | | | | |
| TC-DOC-006 | DOC Calculation | Feed schedule highlights today's DOC | 1. Pond at DOC=15 → 2. Navigate to Feed Schedule screen | DOC 15 row highlighted; correct feed amount for DOC 15; 4 meals (Hatchery ≥ DOC 7) | P1 | S2 | | | | | | |
| TC-DOC-007 | DOC Calculation | DOC 186 renders without crash | 1. Set stocking_date = 185 days ago via DB → 2. Navigate to pond | DOC = 186 shown; feed recommendation valid and within bounds; no UI overflow | P2 | S2 | | | | | | |
| TC-DOC-008 | DOC Calculation | Each pond card shows its own DOC | 1. Farm with ponds at DOC 5, 30, 60 → 2. View HomeScreen pond cards | Each card shows its own correct DOC; no cross-pond DOC contamination | P2 | S2 | | | | | | |

---

## MODULE 5 — Feed Engine Calculations

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-FEED-001 | Feed Engine | Base feed = 1.5 kg on DOC 1 for 100K seed | 1. Pond: 100K seed, DOC=1 → 2. Navigate to Feed tab | Feed = 1.5 kg; 2 meals; 0.75 kg/meal; no tray or FCR corrections applied | P0 | S1 | | | | | | |
| TC-FEED-002 | Feed Engine | Density scaling: 300K seed = 4.5 kg | 1. Pond: 300K seed, DOC=1 → 2. Navigate to Feed tab | Feed = 4.5 kg (1.5 × 300K/100K); density scaling confirmed | P0 | S1 | | | | | | |
| TC-FEED-003 | Feed Engine | Daily increment +0.2 kg/day for DOC 1–7 | 1. Pond: 100K seed → 2. Observe feed at DOC 1 through 7 | DOC1=1.5, DOC2=1.7, DOC3=1.9, DOC4=2.1, DOC5=2.3, DOC6=2.5, DOC7=2.7 kg exactly | P0 | S1 | | | | | | |
| TC-FEED-004 | Feed Engine | Hard limit clamps feed at 50 kg for max seed | 1. Pond: 1,000,000 seed, DOC=25 → 2. Navigate to Feed tab | Feed ≤ 50.0 kg (kAbsoluteMaxFeed); not 150 kg unclamped value | P0 | S1 | | | | | | |
| TC-FEED-005 | Feed Engine | Feed round completion creates feed_log entry | 1. Pond DOC=10 → 2. Complete Round 1 (2.1 kg) | feed_logs row inserted with pond_id, doc=10, round=1, feed_given=2.1; status = Completed | P0 | S1 | | | | | | |
| TC-FEED-006 | Feed Engine | Double-tap complete creates only one feed_log | 1. Tap Complete Round 1 → 2. Tap again before response | Exactly 1 feed_log row; second call returns operationDuplicate=true; no duplication | P0 | S1 | | | | | | |
| TC-FEED-007 | Feed Engine | Ramp mode applies 0.75 factor on DOC 31 | 1. PRO user, DOC=31, no tray or water data → 2. Navigate to Feed tab | Feed = blind_base(31) × 0.75; no cliff; ramp factor visible in breakdown | P1 | S1 | | | | | | |
| TC-FEED-008 | Feed Engine | Daily cumulative total sums all rounds | 1. Log 4 rounds at DOC=10 (2.1 kg each) → 2. View Feed History | DOC 10 total = 8.4 kg; last-row-wins not conflated with per-round sum | P1 | S2 | | | | | | |
| TC-FEED-009 | Feed Engine | Manual override updates continuity guard | 1. Override round to 2.5 kg (rec=3.0) → 2. Submit | feed_logs: actual=2.5, base=3.0; tomorrow's continuity guard uses 2.5 kg (actual) | P1 | S2 | | | | | | |
| TC-FEED-010 | Feed Engine | Continuity guard clamps ±30% from yesterday | 1. Yesterday actual=5.0 kg → 2. Engine calculates 8.0 kg → 3. View recommendation | Recommendation clamped to 6.5 kg (5.0 × 1.30 max); not 8.0 kg | P2 | S2 | | | | | | |

---

## MODULE 6 — Smart Feeding Logic

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SMART-001 | Smart Feed | FREE user gets no smart corrections | 1. FREE user, DOC=40, all-Empty trays, DO=6.5 → 2. Navigate to Feed tab | Base feed only; no tray/FCR/env corrections; upgrade prompt visible | P0 | S1 | | | | | | |
| TC-SMART-002 | Smart Feed | PRO user — tray + FCR corrections compound | 1. PRO, DOC=45, tray=INCREASE(+5%), FCR=1.3(+5%), env=normal → 2. Read recommendation | Final = base × 1.05 × 1.05 = 1.1025×; breakdown shows each factor separately | P0 | S1 | | | | | | |
| TC-SMART-003 | Smart Feed | DO < 3.5 triggers STOP FEEDING | 1. PRO, DOC=50, water DO=3.2 mg/L → 2. Navigate to Feed tab | All rounds show 0.0 kg; STOP FEEDING alert visible; alert explains low DO | P0 | S1 | | | | | | |
| TC-SMART-004 | Smart Feed | Temperature > 36°C triggers STOP FEEDING | 1. PRO, DOC=40, water temp=37°C → 2. Navigate to Feed tab | All rounds show 0.0 kg; temperature warning visible | P0 | S1 | | | | | | |
| TC-SMART-005 | Smart Feed | Stale water (>48h) uses safe defaults | 1. PRO, DOC=40, last water log 50h ago → 2. Navigate to Feed tab | Safe defaults applied (DO=6.0, T=28°C); feed NOT stopped; stale water warning shown | P1 | S1 | | | | | | |
| TC-SMART-006 | Smart Feed | High FCR reduces recommendation | 1. PRO, DOC=60, FCR=1.6 → 2. Navigate to Feed tab | Feed = base × 0.85 (-15% correction); FCR badge red; breakdown shows FCR factor | P1 | S2 | | | | | | |
| TC-SMART-007 | Smart Feed | Kill switch disables engine globally | 1. Set app_config feed_kill_switch=true → 2. Restart app → 3. Navigate to Feed tab | Recommendations disabled; safe message shown; manual logging still works | P1 | S2 | | | | | | |
| TC-SMART-008 | Smart Feed | Global feed multiplier applied to all ponds | 1. Set global_feed_multiplier=1.1 → 2. Check recommendation (base=5.3 kg) | Recommendation = 5.3 × 1.1 = 5.83 kg; applied across all ponds | P2 | S3 | | | | | | |

---

## MODULE 7 — Tray Adjustment Logic

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-TRAY-001 | Tray Logic | All-Empty trays → INCREASE +5% | 1. PRO, DOC=40, 4 trays → 2. Log 3 sessions all-Empty → 3. Check Feed tab | avg_score=1.0 ≥ 0.6; INCREASE decision; feed = base × 1.05; breakdown confirms | P0 | S1 | | | | | | |
| TC-TRAY-002 | Tray Logic | All-Heavy trays → REDUCE -10% | 1. PRO, DOC=40, 4 trays → 2. Log 3 sessions all-Heavy → 3. Check Feed tab | avg_score=-1.0 ≤ -0.6; REDUCE decision; feed = base × 0.90; breakdown confirms | P0 | S1 | | | | | | |
| TC-TRAY-003 | Tray Logic | Mixed trays → MAINTAIN (noise absorption) | 1. PRO, DOC=40 → 2. Log 3 sessions: 2 Empty + 2 Heavy each → 3. Check Feed | avg_score=0.0; within ±0.6; MAINTAIN; feed unchanged | P0 | S1 | | | | | | |
| TC-TRAY-004 | Tray Logic | <4 trays forces MAINTAIN regardless of scores | 1. PRO, pond with 3 trays, DOC=40 → 2. Log 3 all-Empty sessions → 3. Check Feed | MAINTAIN forced; insufficient tray count message in breakdown | P1 | S2 | | | | | | |
| TC-TRAY-005 | Tray Logic | Wizard back navigation — no partial submission | 1. Open wizard → 2. Log Tray 1=Empty → 3. Back on Tray 2 → 4. Forward to Tray 3 | Confirmation dialog on back; all-or-nothing submit; no partial tray data saved | P1 | S2 | | | | | | |
| TC-TRAY-006 | Tray Logic | Consecutive INCREASE dampened to +3% | 1. PRO, DOC=45, previous day = INCREASE → 2. Today all-Empty again | Second consecutive INCREASE = +3% (not +5%); dampen rule applied | P1 | S2 | | | | | | |
| TC-TRAY-007 | Tray Logic | DOC ≤ 30 ignores tray signal | 1. PRO, DOC=28 → 2. Log 3 sessions all-Empty → 3. Check Feed | MAINTAIN forced; blind phase rule overrides tray signal for any subscription | P2 | S2 | | | | | | |
| TC-TRAY-008 | Tray Logic | Rolling window uses only last 3 sessions | 1. Log 5 sessions: 2 all-Heavy (old), 3 all-Empty (recent) → 2. Check Feed | Only last 3 (all-Empty) used; avg_score=1.0; INCREASE; old Heavy sessions excluded | P2 | S3 | | | | | | |

---

## MODULE 8 — Sampling System

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SAMP-001 | Sampling | ABW calculated correctly from sample inputs | 1. Navigate to Growth → Sampling → 2. Enter weight=50g, pieces=10 → 3. Submit | ABW = 5.0g (50/10); saved with correct DOC; samplings row inserted | P1 | S2 | | | | | | |
| TC-SAMP-002 | Sampling | Duplicate sample for same DOC blocked | 1. Sample already logged for DOC=30 → 2. Attempt another sample for DOC=30 | Error shown: already logged for this DOC; or update existing; no silent duplicate | P1 | S2 | | | | | | |
| TC-SAMP-003 | Sampling | Sample older than 7 days treated as stale | 1. Sample logged 8 days ago → 2. Navigate to Growth tab and Feed tab | ABW signal disabled; expected table used; FCR not computed; stale warning shown | P1 | S2 | | | | | | |
| TC-SAMP-004 | Sampling | Fresh sample at DOC ≥ 40 enables intelligent mode | 1. PRO, DOC=45 → 2. Log sample ABW=10g today → 3. Navigate to Feed | Feed mode = Intelligent; actual ABW drives FCR; breakdown confirms sampled ABW used | P2 | S3 | | | | | | |
| TC-SAMP-005 | Sampling | Zero piece count rejected | 1. Enter weight=50g, pieces=0 → 2. Submit | Validation error: pieces must be ≥ 1; form not submitted; no div-by-zero | P2 | S2 | | | | | | |

---

## MODULE 9 — ABW Calculations

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ABW-001 | ABW Engine | Expected ABW interpolated from reference table | 1. No sampling data → 2. Pond at DOC=45 → 3. View Growth tab | ABW = 13.5g (interpolated between DOC30=5.0g and DOC60=22.0g); labeled Expected | P1 | S2 | | | | | | |
| TC-ABW-002 | ABW Engine | Sampled ABW overrides expected value | 1. DOC=45, expected=13.5g → 2. Log sample ABW=11g → 3. View dashboard | ABW shows 11g (Sampled); FCR and feed engine use 11g, not 13.5g | P1 | S1 | | | | | | |
| TC-ABW-003 | ABW Engine | Zero weight input rejected | 1. Enter weight=0g, pieces=10 → 2. Submit | Validation error: weight must be > 0; engine not called; no division error | P2 | S2 | | | | | | |
| TC-ABW-004 | ABW Engine | ABW trend chart renders multi-sample history | 1. Log 5 samples at DOC 10,20,30,40,50 → 2. View Growth tab | Chart shows 5 ascending data points; expected reference line separate; no rendering errors | P2 | S3 | | | | | | |

---

## MODULE 10 — FCR Calculations

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-FCR-001 | FCR Engine | Correct FCR formula computes 1.11 | 1. PRO, seed=100K, ABW=18g, total_feed=1800 kg → 2. View Overview | biomass=1620 kg; FCR=1800/1620=1.11; adjustment=+10% (FCR ≤ 1.2) | P0 | S1 | | | | | | |
| TC-FCR-002 | FCR Engine | FCR below 0.5 discarded as corrupted | 1. Conditions producing FCR < 0.5 → 2. View Feed tab | FCR correction = 0%; no crash; base feed used; no corrupted value applied | P0 | S1 | | | | | | |
| TC-FCR-003 | FCR Engine | Biomass < 1 kg guard prevents div-by-zero | 1. Pond: 1K seed, DOC=5, ABW=0.1g → 2. View Feed tab | FCR not computed; no division error; feed continues using base engine | P0 | S1 | | | | | | |
| TC-FCR-004 | FCR Engine | FCR ≤ 1.0 triggers +15% feed increase | 1. PRO, FCR=0.8 → 2. View Feed tab | +15% correction applied; breakdown shows FCR exceptional; feed higher than base | P1 | S2 | | | | | | |
| TC-FCR-005 | FCR Engine | FCR > 1.5 triggers -15% feed decrease | 1. PRO, FCR=1.6 → 2. View Feed tab | -15% correction; FCR badge red; breakdown shows reduction; feed < base | P1 | S2 | | | | | | |
| TC-FCR-006 | FCR Engine | FCR recalculates on new ABW sample | 1. FCR computed with ABW=12g → 2. Log new sample ABW=15g → 3. View Feed | FCR recalculates with 15g; new value shown; old value no longer used | P1 | S2 | | | | | | |
| TC-FCR-007 | FCR Engine | Last-row-wins resolves duplicate round entries | 1. DOC=20 Round 1: two rows (3.0 kg then 2.8 kg) → 2. Check FCR total | FCR uses 2.8 kg (last row); not 3.0 or 5.8; RPC upsert confirmed | P2 | S2 | | | | | | |
| TC-FCR-008 | FCR Engine | FCR shows N/A when not computable | 1. Stale ABW or biomass < 1 kg → 2. Navigate to Overview | FCR shows N/A or "—"; not 0.00 or null; color-coding: green ≤ 1.3; red > 1.5 | P2 | S3 | | | | | | |

---

## MODULE 11 — Dashboard Metrics

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-DASH-001 | Dashboard | Pond card KPIs match pond overview | 1. Pond DOC=30, ABW=5g, FCR=1.3 → 2. View HomeScreen pond card | Card shows DOC=30, ABW=5.0g, FCR=1.30; matches Overview tab exactly | P1 | S2 | | | | | | |
| TC-DASH-002 | Dashboard | Farm-level KPIs aggregate all ponds | 1. Pond A: feed=500 kg, rev=₹50K; Pond B: feed=300 kg, rev=₹30K → 2. View HomeScreen | Total feed=800 kg; total revenue=₹80K; correct sum aggregation | P1 | S2 | | | | | | |
| TC-DASH-003 | Dashboard | Empty state shown when farm has no ponds | 1. Farm with 0 ponds → 2. Navigate to HomeScreen | Illustration + Add Pond CTA; no crash; no null text; no blank white screen | P2 | S2 | | | | | | |
| TC-DASH-004 | Dashboard | Feed trend chart shows 7-day history accurately | 1. 7 days of feed logged → 2. View Feed Trend card | 7-bar chart; correct daily totals; today highlighted; 0-feed days show empty bar | P2 | S3 | | | | | | |
| TC-DASH-005 | Dashboard | Biomass estimation formula correct | 1. Pond: seed=200K, ABW=8g → 2. Navigate to Overview | Biomass = 200K × 0.90 × 0.008 = 1,440 kg; 90% survival assumption noted | P2 | S3 | | | | | | |

---

## MODULE 12 — Cost Tracking

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-COST-001 | Cost Tracking | Log feed expense saves correctly | 1. Tap Add Expense → 2. Category=Feed, Amount=₹12500 → 3. Submit | Expense saved; amount=12500; category=feed; monthly total updates; expenses table row inserted | P1 | S2 | | | | | | |
| TC-COST-002 | Cost Tracking | Monthly aggregation groups by week correctly | 1. Log expenses ₹10K+₹5K+₹2K in current month → 2. View Monthly tab | Total=₹17,000; correct category split; no cross-month leakage | P1 | S2 | | | | | | |
| TC-COST-003 | Cost Tracking | Feed completion auto-deducts inventory | 1. Inventory=100 kg feed → 2. Complete 4.5 kg round → 3. View Inventory Dashboard | Stock = 95.5 kg; inventory_consumption row inserted | P1 | S3 | | | | | | |
| TC-COST-004 | Cost Tracking | Low-stock warning appears below 20 kg | 1. Set inventory = 15 kg → 2. View Inventory Dashboard | Warning indicator visible on item; no warning at exactly 20 kg (boundary check) | P2 | S3 | | | | | | |
| TC-COST-005 | Cost Tracking | Profit = revenue minus expenses | 1. Harvest=₹2,50,000 revenue; Expenses=₹1,80,000 → 2. View Profit Summary | Profit=₹70,000; correct formula; both scoped to same crop_id | P2 | S3 | | | | | | |

---

## MODULE 13 — Sync & Offline Behavior

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SYNC-001 | Sync/Offline | Feed round queued when device is offline | 1. Enable airplane mode → 2. Complete feed round (4.5 kg) | Round shows Completed (optimistic); 1 op in FeedSyncQueue; no crash | P0 | S1 | | | | | | |
| TC-SYNC-002 | Sync/Offline | Queued round syncs automatically on reconnect | 1. Offline feed round queued → 2. Disable airplane mode → 3. Wait 30 seconds | feed_logs row inserted within 30s; queue cleared; warning bar disappears | P0 | S1 | | | | | | |
| TC-SYNC-003 | Sync/Offline | No duplicate created on sync replay | 1. Queue feed round → 2. Simulate partial sync failure → 3. Full sync succeeds | Exactly 1 feed_log row; second RPC returns operationDuplicate=true | P0 | S1 | | | | | | |
| TC-SYNC-004 | Sync/Offline | Exponential backoff timing with ±20% jitter | 1. Server returning 500 errors → 2. Observe retry timings | Retries: ~5s, ~10s, ~20s, ~40s, ~80s each with ±20% jitter | P1 | S2 | | | | | | |
| TC-SYNC-005 | Sync/Offline | Permanent failure after 5 retry attempts | 1. Force 5 consecutive sync failures | Op marked failed; warning bar shows permanent failure; no further auto-retry | P1 | S2 | | | | | | |
| TC-SYNC-006 | Sync/Offline | Queue survives app force-kill | 1. Queue op offline → 2. Force-close app → 3. Reconnect → 4. Relaunch | Queue retained in SharedPrefs; syncs on app startup; feed_logs row created | P1 | S1 | | | | | | |
| TC-SYNC-007 | Sync/Offline | Synced ops pruned after 24 hours | 1. 10 ops synced 25h ago → 2. Trigger processQueue | Synced ops pruned; failed ops retained; queue size reduced; storage freed | P2 | S3 | | | | | | |

---

## MODULE 14 — Multi-Pond Logic

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-MULTI-001 | Multi-Pond | Feed recommendations are independent per pond | 1. Pond A: DOC=20, 100K seed → 2. Pond B: DOC=45, 200K seed PRO → 3. Compare Feed tabs | Each pond uses own DOC + seed count; different amounts; no cross-contamination | P1 | S1 | | | | | | |
| TC-MULTI-002 | Multi-Pond | Feed completion on Pond A doesn't affect Pond B | 1. Pond A DOC=15, Pond B DOC=30 → 2. Complete Round 1 on Pond A → 3. Check Pond B | Pond B rounds still show Planned; Pond A completion isolated to its own provider | P1 | S1 | | | | | | |
| TC-MULTI-003 | Multi-Pond | HomeScreen shows all ponds with correct data | 1. Farm with 3 ponds: different DOC/ABW/status → 2. View HomeScreen | All 3 cards visible; each shows correct pond-specific data; no data mix | P2 | S2 | | | | | | |
| TC-MULTI-004 | Multi-Pond | Tray logs scoped to correct pond | 1. Log tray data for Pond A (all-Empty) → 2. Navigate to Pond B Trays tab | Pond B shows its own tray data; Pond A trays not visible in Pond B | P2 | S1 | | | | | | |
| TC-MULTI-005 | Multi-Pond | Offline queue handles ops for multiple ponds | 1. Offline: Complete Round 1 on Pond A + Round 2 on Pond B → 2. Reconnect | Both sync independently; correct feed_logs per pond; no cross-pond rows | P2 | S2 | | | | | | |

---

## MODULE 15 — Role-Based Access

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-ROLE-001 | Role Access | PRO user can add farm member | 1. PRO user → 2. Farm Settings → 3. Add member: worker@farmtest.com, role=Worker | farm_members row inserted; member in list; role=worker | P1 | S3 | | | | | | |
| TC-ROLE-002 | Role Access | FREE user blocked from adding members | 1. FREE user → 2. Tap Add Member | role_limit_bottom_sheet shown; add-member form not accessible | P1 | S2 | | | | | | |
| TC-ROLE-003 | Role Access | Worker role cannot access admin actions | 1. Log in as Worker → 2. Attempt: delete pond, view profit, manage billing | Delete/billing/profit actions not accessible; feed/tray logging works for worker | P2 | S2 | | | | | | |
| TC-ROLE-004 | Role Access | Farm owner retains full permissions | 1. PRO farm owner → 2. Attempt all admin actions | All actions succeed; owner not accidentally downgraded by farm_members entry | P2 | S2 | | | | | | |

---

## MODULE 16 — Subscription & Paywall

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-SUB-001 | Subscription | PRO subscription activated via Razorpay | 1. FREE user → 2. Navigate to Upgrade → 3. Select PRO → 4. Complete Razorpay test payment | Subscription activated; subscriptions row inserted; smart feed unlocked; PRO badge shown | P0 | S1 | | | | | | |
| TC-SUB-002 | Subscription | Server entitlement overrides local state | 1. Manually set local PRO state → 2. Server returns FREE → 3. Navigate to smart feed | FREE features only; server authority prevails; no client-side bypass | P0 | S1 | | | | | | |
| TC-SUB-003 | Subscription | Payment failure keeps user on FREE | 1. Initiate payment → 2. Use Razorpay failure test card | Friendly error shown; user remains FREE; no partial subscription created | P0 | S1 | | | | | | |
| TC-SUB-004 | Subscription | Expired subscription downgrades to FREE | 1. Set subscriptions.expires_at = yesterday → 2. Launch app | FREE features shown; smart feed locked; expiry message visible | P1 | S1 | | | | | | |
| TC-SUB-005 | Subscription | Boot race — hydration protects PRO gate | 1. PRO user, simulate slow network → 2. Navigate to Feed before hydration completes | PRO features hidden until hydrationFuture resolves; no flash of PRO state | P1 | S2 | | | | | | |
| TC-SUB-006 | Subscription | Upgrade screen shows correct plans | 1. FREE user → 2. Navigate to Upgrade → 3. Toggle billing cycle | Correct feature list; price updates on toggle; CTA functional | P2 | S3 | | | | | | |

---

## MODULE 17 — Data Persistence

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-DATA-001 | Data Persistence | Feed logs survive app force-close | 1. Complete 3 feed rounds → 2. Force-close app → 3. Relaunch → 4. View Feed History | All 3 rounds in history; no data loss; Supabase is source of truth | P0 | S1 | | | | | | |
| TC-DATA-002 | Data Persistence | ABW sample drives next session's feed recommendation | 1. Log sample ABW=12g → 2. Force-close → 3. Relaunch → 4. View Growth+Feed | ABW=12g shown; engine uses 12g for recommendation; no re-entry required | P1 | S1 | | | | | | |
| TC-DATA-003 | Data Persistence | Offline queue survives app force-kill | 1. Queue feed round offline → 2. Force-close → 3. Relaunch (still offline) | Queue retained in SharedPrefs; op present; syncs when reconnected | P1 | S1 | | | | | | |
| TC-DATA-004 | Data Persistence | Expenses scoped to current crop cycle | 1. Expense logged in Cycle 1 → 2. Start Cycle 2 → 3. View Cycle 2 expenses | Cycle 2 shows ₹0 or empty; Cycle 1 expenses not leaked across crop_id | P2 | S2 | | | | | | |

---

## MODULE 18 — API Failure Handling

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-API-001 | API Failure | Feed RPC 503 error triggers offline queue | 1. Server returns 503 for complete_feed_round RPC → 2. Complete feed round | Op queued; UI shows Completed (optimistic); no error dialog; no crash | P0 | S1 | | | | | | |
| TC-API-002 | API Failure | Pond creation 500 error — clean rollback | 1. Server returns 500 on create_pond RPC → 2. Submit pond form | Error shown; form values preserved; no partial pond in DB; retry with same operationId | P1 | S1 | | | | | | |
| TC-API-003 | API Failure | Entitlement check failure defaults to FREE | 1. get_active_entitlement returns error → 2. Navigate to smart feed features | App defaults to FREE; no PRO features shown; no crash; FREE functions work | P1 | S1 | | | | | | |
| TC-API-004 | API Failure | Farm list query failure shows retry UI | 1. farms table query returns error after login | Loading → error state with Retry button; no crash; auth session preserved | P1 | S2 | | | | | | |
| TC-API-005 | API Failure | Sampling save failure preserves form values | 1. Fill sampling form → 2. Network drops on submit | Error shown; form values preserved; user can retry; no data loss | P2 | S3 | | | | | | |
| TC-API-006 | API Failure | Payment order creation failure prevents checkout | 1. create-razorpay-order returns 500 → 2. Tap Upgrade | Error shown; Razorpay checkout NOT opened; user stays FREE; no invalid pending order | P2 | S2 | | | | | | |

---

## MODULE 19 — Navigation & State Consistency

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-NAV-001 | Navigation | Bottom nav preserves tab and scroll state | 1. On Pond Dashboard, Feed tab, scrolled to bottom → 2. Tap Home → 3. Tap Ponds | Returns to Feed tab at scroll position; not reset to Overview tab | P1 | S3 | | | | | | |
| TC-NAV-002 | Navigation | Deep back-stack navigates correctly | 1. Home → Pond → Feed Schedule → Feed History → 2. Press Back 3× | Back: History → Schedule → Dashboard → Home; no crash; no duplicate screens | P1 | S2 | | | | | | |
| TC-NAV-003 | Navigation | Pond dashboard reflects edits immediately | 1. Edit pond seed count 150K→120K → 2. Save → 3. Return to Dashboard | Updated seed count and recalculated feed visible immediately; no stale data | P1 | S2 | | | | | | |
| TC-NAV-004 | Navigation | Tray wizard exit mid-flow requires confirmation | 1. Open wizard, log Tray 1 → 2. Press Back on Tray 2 | Confirmation dialog: Discard? Yes = wizard closes, no data saved; No = stay on Tray 2 | P2 | S2 | | | | | | |
| TC-NAV-005 | Navigation | Logout clears all state before next user | 1. Log in as User A → 2. Logout → 3. Log in as User B | User B sees only their data; User A farms/ponds not visible; Riverpod fully reset | P2 | S1 | | | | | | |

---

## MODULE 20 — Crash Risk & Performance

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-PERF-001 | Performance | Cold launch time under 3 seconds | 1. Force-close app (user logged in) → 2. Relaunch → 3. Measure to HomeScreen visible | Cold launch < 3s on mid-range Android; no blank screen > 1s; splash screen shown | P1 | S3 | | | | | | |
| TC-PERF-002 | Performance | Feed engine completes within 500ms | 1. Pond: 1M seed, DOC=60, all smart corrections active → 2. Navigate to Feed tab | Recommendation visible within 500ms; no ANR; no UI jank | P1 | S2 | | | | | | |
| TC-PERF-003 | Performance | 720-row feed history loads smoothly | 1. Pond at DOC=180 with all rounds logged → 2. Navigate to Feed History → 3. Scroll | Loads in <2s; 60fps scrolling; no OOM crash on low-RAM devices | P2 | S3 | | | | | | |
| TC-PERF-004 | Crash Risk | No crash with empty Riverpod providers | 1. New user, no farms, no ponds → 2. Navigate through all screens | No crash; no null errors; correct empty state on every screen | P0 | S1 | | | | | | |
| TC-PERF-005 | Crash Risk | Rapid screen switching causes no memory leak | 1. Switch tabs 20× in 10 seconds → 2. Navigate in/out of Pond Dashboard 10× | No setState-on-disposed errors; memory usage stable over 5 minutes | P1 | S2 | | | | | | |
| TC-PERF-006 | Crash Risk | NaN input to feed engine handled safely | 1. Inject NaN as DO value → 2. Observe recommendation | Validator catches NaN; safe default (DO=6.0) used; valid recommendation returned; no crash | P1 | S1 | | | | | | |
| TC-PERF-007 | Crash Risk | DB timeout shows error with retry option | 1. Simulate >30s Supabase response delay → 2. Open HomeScreen | Timeout fires; error state with Retry button shown; no infinite spinner; no crash | P2 | S2 | | | | | | |

---

## MODULE 21 — Regression Scenarios

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-REG-001 | Regression | Feed brand UUID persists after pond creation | 1. Create pond with Feed Brand selected → 2. View pond dashboard | feed_brand_id stored as UUID (not null, not TEXT); correct brand shown on dashboard | P0 | S1 | | | | | | |
| TC-REG-002 | Regression | Feed round cards visible immediately after pond creation | 1. Create new pond → 2. Immediately navigate to Feed tab (no restart) | 30 feed_rounds visible; no empty state; feedScheduleProvider invalidated post-creation | P0 | S1 | | | | | | |
| TC-REG-003 | Regression | Seed count max = 500K (BUG-12 fix) | 1. Enter seed count = 600,000 → 2. Submit form | Validation error: max is 500,000; form blocked; confirms BUG-12 regression fix held | P0 | S2 | | | | | | |
| TC-REG-004 | Regression | Feed history updates without app refresh (BUG-5 fix) | 1. Complete feed round → 2. Navigate to Feed History immediately | New entry visible without restart; feedHistoryProvider invalidated on completion | P1 | S2 | | | | | | |
| TC-REG-005 | Regression | Tray logging triggers feed pipeline (TASK-2 check) | 1. PRO, DOC>30 → 2. Submit tray statuses → 3. Navigate to Feed tab | Feed recommendation reflects tray signal; debug log confirms TRAY LOGGED trigger chain | P1 | S2 | | | | | | |

---

## MODULE 22 — Integration Test Scenarios

| Test Case ID | Module | Scenario | Steps | Expected Result | Priority | Severity | Status | QA Notes | Bug ID | Retest Status | Tested By | Test Date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-INT-001 | Integration | Full daily farming workflow end-to-end | 1. DOC=45 PRO pond → 2. Check Overview KPIs → 3. Read feed rec → 4. Complete all 4 rounds → 5. Log tray → 6. View Feed History | All 4 rounds logged; KPIs correct; DOC/ABW/FCR consistent; no cross-module failures | P0 | S1 | | | | | | |
| TC-INT-002 | Integration | Full crop cycle: stocking to harvest to new cycle | 1. Create pond → 2. Simulate DOC=91 via DB → 3. Log sample → 4. Log Final Harvest → 5. Start New Cycle → 6. Confirm DOC=1 | Full lifecycle works; harvest saved; new cycle DOC=1; old harvest data preserved | P0 | S1 | | | | | | |
| TC-INT-003 | Integration | Offline sync across multiple ponds | 1. Offline: Round 1 for Pond A + Round 2 for Pond B + tray for Pond C → 2. Reconnect | All 3 ops sync; correct feed_logs per pond; no contamination; queue cleared | P1 | S1 | | | | | | |
| TC-INT-004 | Integration | Active supplement shown on feed round | 1. Active supplement: Probiotics at Round 2 → 2. Navigate to Feed Round 2 | Supplement chip visible on Round 2; applied on completion; supplement schedule updated | P1 | S2 | | | | | | |
| TC-INT-005 | Integration | Profit = harvest revenue minus all expenses | 1. Expenses=₹1,05,000 (feed+labor+misc); Harvest=3000 kg × ₹200 → 2. View Profit Summary | Profit=₹4,95,000; cost/kg=₹35; margin=82.5%; both scoped to same crop_id | P1 | S2 | | | | | | |

---

## Summary Tracker

| Module | Total Cases | P0 | P1 | P2 | P3 | Pass | Fail | Blocked | Not Run |
|---|---|---|---|---|---|---|---|---|---|
| Authentication | 6 | 2 | 2 | 2 | 0 | | | | |
| Farm Management | 5 | 2 | 2 | 1 | 0 | | | | |
| Pond Management | 8 | 3 | 3 | 2 | 0 | | | | |
| DOC Calculation | 8 | 4 | 2 | 2 | 0 | | | | |
| Feed Engine | 10 | 6 | 3 | 1 | 0 | | | | |
| Smart Feed | 8 | 4 | 2 | 1 | 0 | | | | |
| Tray Logic | 8 | 3 | 3 | 2 | 0 | | | | |
| Sampling | 5 | 0 | 3 | 2 | 0 | | | | |
| ABW Engine | 4 | 0 | 2 | 2 | 0 | | | | |
| FCR Engine | 8 | 3 | 3 | 2 | 0 | | | | |
| Dashboard | 5 | 0 | 2 | 3 | 0 | | | | |
| Cost Tracking | 5 | 0 | 3 | 2 | 0 | | | | |
| Sync/Offline | 7 | 3 | 3 | 1 | 0 | | | | |
| Multi-Pond | 5 | 0 | 2 | 3 | 0 | | | | |
| Role Access | 4 | 0 | 2 | 2 | 0 | | | | |
| Subscription | 6 | 3 | 2 | 1 | 0 | | | | |
| Data Persistence | 4 | 1 | 2 | 1 | 0 | | | | |
| API Failure | 6 | 1 | 3 | 2 | 0 | | | | |
| Navigation | 5 | 0 | 3 | 2 | 0 | | | | |
| Performance/Crash | 7 | 1 | 3 | 3 | 0 | | | | |
| Regression | 5 | 3 | 2 | 0 | 0 | | | | |
| Integration | 5 | 2 | 3 | 0 | 0 | | | | |
| **TOTAL** | **125** | **41** | **56** | **35** | **0** | | | | |

---

## Excel Import Instructions

To import `QA_EXECUTION_SHEET.csv` into Excel:
1. Open Excel → Data → From Text/CSV
2. Select `QA_EXECUTION_SHEET.csv`
3. Set encoding: **UTF-8**
4. Set delimiter: **Comma**
5. Set text qualifier: **Double Quote (")**
6. Click Load
7. Freeze the first row (View → Freeze Panes → Freeze Top Row)
8. Add filters to all columns (Data → Filter)
9. Apply conditional formatting on **Status** column: Pass=Green, Fail=Red, Blocked=Orange

---

*Reference: Full step-by-step test procedures in QA_TEST_CASES.md*
