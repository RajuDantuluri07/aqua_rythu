# Aqua Rythu — Complete QA Test Case Suite

> **Version:** 1.0 | **Date:** 2026-05-17 | **Product:** Aqua Rythu v1.0.0+1
> **Platform:** Flutter (iOS + Android) | **Backend:** Supabase (PostgreSQL + Edge Functions)
> **Total Test Cases:** 125
> **Focus:** Realistic L. vannamei shrimp farming workflows and business-critical logic

---

## Legend

| Priority | Meaning |
|----------|---------|
| P0 — Critical | App unusable / data corrupt / financial impact if fails |
| P1 — High | Core feature broken; farmer cannot complete daily workflow |
| P2 — Medium | Feature degraded but workaround exists |
| P3 — Low | Polish / cosmetic / edge of edge |

| Severity | Meaning |
|----------|---------|
| S1 — Blocker | Stop-ship; must fix before any production user |
| S2 — Critical | Fix before onboarding first farmer |
| S3 — Major | Fix before 20-farmer rollout |
| S4 — Minor | Fix in next release |

---

# SECTION 1 — AUTHENTICATION (TC-AUTH)

---

### TC-AUTH-001
- **Module:** Authentication
- **Priority:** P0
- **Feature:** Email/password login
- **Preconditions:** Valid Supabase account exists with email `farmer@test.com`, password `Test@1234`. App freshly installed. Onboarding already seen (SharedPreferences: `has_seen_onboarding = true`).
- **Steps:**
  1. Launch app → splash screen appears
  2. Wait for session check to complete
  3. Observe navigation to Login screen (not Onboarding)
  4. Enter email: `farmer@test.com`
  5. Enter password: `Test@1234`
  6. Tap "Login"
- **Expected Result:** Login succeeds. User navigates to HomeScreen. Farm list loads showing user's farm(s). Bottom nav shows 3 tabs (Home / Ponds / Profile). No error snackbar appears.
- **Edge Case Notes:** Session check must complete before redirect — if `isCheckingSession=true` shows briefly then resolves, that is acceptable. SplashScreen must not hang.
- **Severity if Failed:** S1

---

### TC-AUTH-002
- **Module:** Authentication
- **Priority:** P0
- **Feature:** Wrong password handling
- **Preconditions:** Valid account exists with email `farmer@test.com`. App on Login screen.
- **Steps:**
  1. Enter email: `farmer@test.com`
  2. Enter password: `WrongPass999`
  3. Tap "Login"
- **Expected Result:** Login fails. Snackbar or inline error shows a user-friendly message ("Invalid credentials" or equivalent). App stays on Login screen. No crash. Password field does not retain value.
- **Edge Case Notes:** Must NOT show raw Supabase error string (e.g., "invalid_grant" or stack trace). Message must be in plain language a farmer understands.
- **Severity if Failed:** S2

---

### TC-AUTH-003
- **Module:** Authentication
- **Priority:** P0
- **Feature:** Session persistence across app restart
- **Preconditions:** User is logged in and on HomeScreen. Farm and at least one pond exist.
- **Steps:**
  1. Force-close the app from the OS task manager
  2. Relaunch the app
  3. Observe the splash screen
  4. Wait for navigation to settle
- **Expected Result:** App navigates directly to HomeScreen without showing Login screen. Existing farm and pond data is visible. User does not need to log in again.
- **Edge Case Notes:** Test with both short interval (5 seconds after close) and long interval (12 hours after close). Supabase token refresh must work silently.
- **Severity if Failed:** S1

---

### TC-AUTH-004
- **Module:** Authentication
- **Priority:** P1
- **Feature:** First-time user onboarding gate
- **Preconditions:** App freshly installed. SharedPreferences cleared. No prior session.
- **Steps:**
  1. Launch app
  2. Wait for splash screen to complete
  3. Observe navigation
- **Expected Result:** Onboarding carousel appears (3 slides: Problem → Solution → Outcome). User can swipe through all 3. After final slide, a CTA navigates to Login/Signup screen. After login, onboarding is never shown again on subsequent launches.
- **Edge Case Notes:** `has_seen_onboarding` flag must be set BEFORE navigating away from onboarding — if app crashes mid-onboarding, next launch should not re-show it.
- **Severity if Failed:** S3

---

### TC-AUTH-005
- **Module:** Authentication
- **Priority:** P1
- **Feature:** New user signup
- **Preconditions:** Email `newfarmer_<timestamp>@test.com` does not exist in Supabase. App on Login screen.
- **Steps:**
  1. Switch to Signup mode (tap "Sign Up" link)
  2. Enter fresh email: `newfarmer_<timestamp>@test.com`
  3. Enter password: `Farm@2024`
  4. Tap "Create Account"
  5. Observe navigation
- **Expected Result:** Account created. User is navigated to HomeScreen. `users` table in Supabase has a new row with correct email and user_id. No farms shown yet — appropriate empty state displayed ("Add your first farm").
- **Edge Case Notes:** Test with already-registered email → must show "already registered" message, not crash.
- **Severity if Failed:** S1

---

### TC-AUTH-006
- **Module:** Authentication
- **Priority:** P2
- **Feature:** Rate limiting on login
- **Preconditions:** Fresh login attempt from same device.
- **Steps:**
  1. Enter any email
  2. Enter wrong password 6 times in rapid succession
  3. Attempt 7th login
- **Expected Result:** App displays a rate-limit message ("Too many attempts, try again later" or equivalent). No crash. App remains usable (can still navigate, close, reopen).
- **Edge Case Notes:** Supabase default rate limit is ~6 attempts per minute. Message must not expose internal Supabase error codes.
- **Severity if Failed:** S3

---

# SECTION 2 — FARM CREATION (TC-FARM)

---

### TC-FARM-001
- **Module:** Farm Management
- **Priority:** P0
- **Feature:** Create first farm (FREE tier)
- **Preconditions:** Logged in as new user with no farms. On HomeScreen showing empty state.
- **Steps:**
  1. Tap "Add Farm" quick action or CTA
  2. Enter farm name: `Coastal Shrimp Farm`
  3. Enter location: `Nellore, AP`
  4. Tap "Create Farm"
- **Expected Result:** Farm created. `farms` table row inserted with correct `user_id`. HomeScreen updates to show new farm. Farm switcher in header reflects new farm name. User is optionally prompted to add first pond.
- **Edge Case Notes:** Farm name with special characters (e.g., `Farm & Sons`) must not break DB insert. Name with only spaces should be rejected with validation error.
- **Severity if Failed:** S1

---

### TC-FARM-002
- **Module:** Farm Management
- **Priority:** P0
- **Feature:** Farm limit enforcement (FREE tier)
- **Preconditions:** FREE tier user with 1 farm already created.
- **Steps:**
  1. Navigate to Profile or use "Add Farm" action
  2. Attempt to create a second farm
- **Expected Result:** `farm_limit_bottom_sheet` appears before the add-farm form is shown. Sheet explains the limit and shows an upgrade CTA. User cannot proceed to create a second farm without upgrading.
- **Edge Case Notes:** If user dismisses the sheet twice, verify 24-hour cooldown before the sheet appears again (third dismiss attempt goes directly to upgrade screen or is blocked).
- **Severity if Failed:** S1

---

### TC-FARM-003
- **Module:** Farm Management
- **Priority:** P1
- **Feature:** Edit farm name
- **Preconditions:** Farm `Coastal Shrimp Farm` exists.
- **Steps:**
  1. Navigate to Profile → Farm Settings or tap farm name in switcher
  2. Tap Edit (pencil icon)
  3. Change name to `Delta Aqua Farm`
  4. Save
- **Expected Result:** Farm name updates in DB (`farms` table). All UI references (home header, farm switcher, profile list) reflect the new name immediately without requiring app restart.
- **Edge Case Notes:** Blank name should be rejected. Name > 100 characters should be rejected or truncated.
- **Severity if Failed:** S3

---

### TC-FARM-004
- **Module:** Farm Management
- **Priority:** P1
- **Feature:** Delete farm cascade
- **Preconditions:** Farm exists with 2 ponds, each having feed_logs, tray_statuses, samplings, water_logs entries.
- **Steps:**
  1. Navigate to farm settings
  2. Tap "Delete Farm"
  3. Confirm deletion in the confirmation dialog
- **Expected Result:** `delete_farm_cascade` RPC executes. All child records (ponds, feed_rounds, feed_logs, tray_statuses, samplings, water_logs, harvests, expenses) are deleted. Farm no longer appears in farm list. If user had no other farms, HomeScreen shows "Add your first farm" empty state.
- **Edge Case Notes:** Verify no orphaned records remain using Supabase dashboard query: `SELECT * FROM ponds WHERE farm_id = '<deleted_farm_id>'` → should return 0 rows.
- **Severity if Failed:** S2

---

### TC-FARM-005
- **Module:** Farm Management
- **Priority:** P2
- **Feature:** Farm switcher
- **Preconditions:** PRO user with 2 farms (Farm A with 2 ponds, Farm B with 1 pond).
- **Steps:**
  1. On HomeScreen, currently viewing Farm A (2 ponds visible)
  2. Tap farm switcher in header
  3. Select Farm B from the bottom sheet
- **Expected Result:** HomeScreen updates to show Farm B's 1 pond. KPIs recalculate for Farm B. All subsequent actions (add pond, view feed, etc.) are scoped to Farm B. Farm A data is not mixed in.
- **Edge Case Notes:** Rapid switching (Farm A → Farm B → Farm A within 2 seconds) should not cause data from wrong farm to flash on screen.
- **Severity if Failed:** S2

---

# SECTION 3 — POND MANAGEMENT (TC-POND)

---

### TC-POND-001
- **Module:** Pond Management
- **Priority:** P0
- **Feature:** Create pond — atomic creation with feed schedule
- **Preconditions:** Farm exists. User on HomeScreen.
- **Steps:**
  1. Tap "Add Pond"
  2. Enter: Name=`Pond 1`, Area=`1.2 acres`, Seed Count=`150,000`, PL Size=`PL10`, Stocking Date=today, Seed Type=`Hatchery Small`, Trays=`4`, Feed Brand=select any
  3. Tap "Create Pond"
- **Expected Result:** `create_pond_with_feed_plan` RPC executes. Pond row inserted in `ponds` table. `feed_rounds` table populated with 30 rows (DOC 1–30, all rounds per day based on meal schedule). Pond card appears on HomeScreen showing DOC=1. Feed tab shows the plan immediately.
- **Edge Case Notes:** If RPC partially fails (pond inserted but feed_rounds not), the RPC must roll back entirely. Verify by checking both tables in Supabase immediately after.
- **Severity if Failed:** S1

---

### TC-POND-002
- **Module:** Pond Management
- **Priority:** P0
- **Feature:** Pond creation idempotency (double-tap)
- **Preconditions:** Pond creation form filled. On poor network (can simulate via airplane mode toggle).
- **Steps:**
  1. Fill form completely
  2. Tap "Create Pond"
  3. Immediately tap "Create Pond" again (double-tap before navigation)
- **Expected Result:** Exactly ONE pond is created. `operationId` (UUID generated at `initState`) ensures second RPC call returns `duplicate=true` and returns the existing pond without creating a second one. Database has exactly 1 pond, not 2.
- **Edge Case Notes:** Verify by querying `SELECT COUNT(*) FROM ponds WHERE name='Pond 1' AND farm_id='<id>'` — must be 1.
- **Severity if Failed:** S1

---

### TC-POND-003
- **Module:** Pond Management
- **Priority:** P0
- **Feature:** Pond limit enforcement (FREE tier)
- **Preconditions:** FREE user with 3 ponds already created.
- **Steps:**
  1. Attempt to create a 4th pond
- **Expected Result:** `pond_limit_bottom_sheet` appears. Cannot proceed to pond creation form without upgrading to PRO.
- **Edge Case Notes:** Limit is 3, not 2. Confirm the app counts correctly (do not show the sheet at 2 ponds).
- **Severity if Failed:** S1

---

### TC-POND-004
- **Module:** Pond Management
- **Priority:** P1
- **Feature:** Edit pond — seed count change mid-cycle
- **Preconditions:** Pond at DOC 25 with existing feed_rounds and feed_logs.
- **Steps:**
  1. Navigate to pond → tap Edit (pencil)
  2. Change seed count from `150,000` to `120,000`
  3. Save
- **Expected Result:** Pond row updated. Next time feed engine runs, density scaling uses `120,000`. Existing feed_logs are NOT retroactively modified. FCR recalculates with new seed count on next load.
- **Edge Case Notes:** Seed count change mid-cycle affects FCR and biomass calculations. Confirm FCR shown on dashboard changes after edit.
- **Severity if Failed:** S2

---

### TC-POND-005
- **Module:** Pond Management
- **Priority:** P1
- **Feature:** Delete pond cascade
- **Preconditions:** Pond with DOC=45 exists, with feed_logs, tray_statuses, samplings, water_logs, supplements.
- **Steps:**
  1. Navigate to pond dashboard → tap "Delete Pond" (in settings or long-press)
  2. Confirm deletion
- **Expected Result:** `delete_pond_cascade` RPC runs. All associated records deleted. Pond disappears from HomeScreen. HomeScreen KPIs recalculate excluding deleted pond.
- **Edge Case Notes:** If deletion is attempted while offline, the cascade RPC cannot queue (it's too destructive). App should require online connection and show error if offline.
- **Severity if Failed:** S2

---

### TC-POND-006
- **Module:** Pond Management
- **Priority:** P1
- **Feature:** New cycle setup — data reset
- **Preconditions:** Pond has completed a cycle. User initiates new cycle from Harvest tab.
- **Steps:**
  1. Log final harvest
  2. Tap "Start New Cycle" on the prompt
  3. Enter new stocking date, seed count, PL size
  4. Confirm
- **Expected Result:** `clear_pond_cycle_tables` RPC clears tray_statuses, water_logs, samplings, growth_data for this pond. New stocking_date saved. DOC resets to 1. New blind-phase feed_rounds (DOC 1–30) generated. Previous harvest data is preserved in `harvests` table (not deleted).
- **Edge Case Notes:** Verify DOC=1 immediately after cycle reset. Old feed_logs should NOT appear in feed history for new cycle.
- **Severity if Failed:** S2

---

### TC-POND-007
- **Module:** Pond Management
- **Priority:** P2
- **Feature:** Pond creation — validation: seed count out of range
- **Preconditions:** Add Pond form open.
- **Steps:**
  1. Enter seed count: `600,000` (above 500,000 limit)
  2. Attempt to submit
- **Expected Result:** Validation error shown: seed count must be between 1,000 and 500,000. Form cannot be submitted. Error message visible near the field.
- **Edge Case Notes:** Test `0`, `-1`, `999` (below min), `500001` (above max), `abc` (non-numeric). Each should show appropriate inline validation.
- **Severity if Failed:** S3

---

### TC-POND-008
- **Module:** Pond Management
- **Priority:** P2
- **Feature:** Pond creation — future stocking date
- **Preconditions:** Add Pond form open.
- **Steps:**
  1. Set stocking date to 3 days in the future
  2. Submit form
- **Expected Result:** Either (a) validation error shown: "Stocking date cannot be in the future," OR (b) pond created but DOC displayed as 1 (clamped). Either behavior is acceptable if consistent and clearly communicated. DOC must NOT display as negative.
- **Edge Case Notes:** This is a real scenario — farmers sometimes add ponds before stocking. Confirm behavior matches product decision.
- **Severity if Failed:** S3

---

# SECTION 4 — DOC FLOWS (TC-DOC)

---

### TC-DOC-001
- **Module:** DOC Calculation
- **Priority:** P0
- **Feature:** DOC = 1 on stocking day
- **Preconditions:** Pond created with stocking_date = today (UTC).
- **Steps:**
  1. Navigate to pond dashboard
  2. Observe DOC displayed on Overview tab
- **Expected Result:** DOC = 1. Not 0. Not 2.
- **Edge Case Notes:** Formula is `(today - stocking_date).inDays + 1`. If today == stocking_date, inDays = 0, so DOC = 1. Critical boundary.
- **Severity if Failed:** S1

---

### TC-DOC-002
- **Module:** DOC Calculation
- **Priority:** P0
- **Feature:** DOC increments correctly over days
- **Preconditions:** Pond stocked 30 days ago (stocking_date = today - 30 days).
- **Steps:**
  1. Open pond dashboard
  2. Read DOC value
- **Expected Result:** DOC = 31. Verify: `(today - stocking_date).inDays + 1 = 30 + 1 = 31`.
- **Edge Case Notes:** If stocking was at 11:59 PM and "today" is computed at midnight, timezone handling could make this DOC 30 or 32. Must use UTC consistently for both dates.
- **Severity if Failed:** S1

---

### TC-DOC-003
- **Module:** DOC Calculation
- **Priority:** P0
- **Feature:** DOC gates blind vs smart feed mode
- **Preconditions:** Two ponds: Pond A (DOC=29), Pond B (DOC=31). Both on PRO plan.
- **Steps:**
  1. Navigate to Pond A feed tab → observe feed recommendation source
  2. Navigate to Pond B feed tab → observe feed recommendation source
- **Expected Result:** Pond A (DOC 29) → uses BlindFeedingEngine only (no tray/FCR corrections shown or applied). Pond B (DOC 31) → uses SmartFeedEngine with tray + env corrections (if data available). Mode label or explanation visible in UI.
- **Edge Case Notes:** DOC 30 is the last blind day. DOC 31 is the first smart day with ramp factor (0.75).
- **Severity if Failed:** S1

---

### TC-DOC-004
- **Module:** DOC Calculation
- **Priority:** P0
- **Feature:** Null stocking_date graceful handling
- **Preconditions:** Manually insert a pond row in DB with `stocking_date = NULL` (simulate migration bug).
- **Steps:**
  1. Open the app and navigate to the affected pond
  2. Observe behavior
- **Expected Result:** App does NOT crash. A graceful error message shown ("Setup incomplete — please edit pond to set stocking date"). Feed tab shows empty/error state, not a crash. Other ponds unaffected.
- **Edge Case Notes:** `doc_utils.dart` currently throws a CRITICAL exception for null stocking_date. This test validates that the exception is caught at the UI layer before crashing the app.
- **Severity if Failed:** S1

---

### TC-DOC-005
- **Module:** DOC Calculation
- **Priority:** P1
- **Feature:** DOC display across timezone boundary
- **Preconditions:** Device timezone set to IST (UTC+5:30). Stocking date stored in UTC in Supabase.
- **Steps:**
  1. Set stocking_date to yesterday in IST (which is still "today" in UTC for part of the day)
  2. Check DOC at 11:30 PM IST
  3. Check DOC at 12:01 AM IST next day
- **Expected Result:** DOC increments correctly at midnight IST, not midnight UTC. Both readings should be consistent with the farmer's local day. If UTC-based, DOC increments at 5:30 AM IST — farmers should be aware.
- **Edge Case Notes:** Confirm product decision on timezone handling. If UTC-based, 5:30 AM IST DOC flip is acceptable. If IST-based, verify device timezone is used.
- **Severity if Failed:** S2

---

### TC-DOC-006
- **Module:** DOC Calculation
- **Priority:** P1
- **Feature:** Feed schedule aligns with DOC
- **Preconditions:** Pond at DOC=15.
- **Steps:**
  1. Navigate to Feed → Schedule tab
  2. Observe which row/day is highlighted as "Today"
- **Expected Result:** DOC 15 row is highlighted. Feed amount shown matches the BlindFeedingEngine calculation for DOC 15: `base(DOC=15) × (seedCount/100K)`. Meal count = 4 (DOC ≥ 7, Hatchery seed).
- **Edge Case Notes:** If the schedule was pre-generated at pond creation and DOC has advanced, the "today" row must auto-scroll into view, not remain at DOC 1.
- **Severity if Failed:** S2

---

### TC-DOC-007
- **Module:** DOC Calculation
- **Priority:** P2
- **Feature:** DOC 180+ (very late culture)
- **Preconditions:** Pond stocked 185 days ago (simulate via DB date override).
- **Steps:**
  1. Open pond dashboard
  2. Observe DOC display and feed recommendation
- **Expected Result:** DOC = 186 displayed without crash or overflow. Feed engine uses maximum table value for ABW. Feed recommendation is non-zero and within bounds (0.1–50 kg). No UI overflow or rendering bug.
- **Edge Case Notes:** Very long cycles are uncommon but possible in multi-crop scenarios. Engine must not ArrayIndexOutOfBounds on the ABW table.
- **Severity if Failed:** S2

---

### TC-DOC-008
- **Module:** DOC Calculation
- **Priority:** P2
- **Feature:** DOC display on pond card (home screen)
- **Preconditions:** Multiple ponds with different DOCs (DOC 5, DOC 30, DOC 60).
- **Steps:**
  1. View HomeScreen pond cards
  2. Check each card's DOC value
- **Expected Result:** Each pond card shows its own correct DOC independently. No cross-pond DOC contamination.
- **Edge Case Notes:** State management must scope DOC to each individual pond. `farmProvider` list must not reuse the same computed DOC across multiple ponds.
- **Severity if Failed:** S2

---

# SECTION 5 — FEED CALCULATIONS (TC-FEED)

---

### TC-FEED-001
- **Module:** Feed Engine
- **Priority:** P0
- **Feature:** Base feed on DOC 1
- **Preconditions:** Pond: Seed Count=100,000, Seed Type=Hatchery Small, DOC=1.
- **Steps:**
  1. Navigate to Feed tab on Pond Dashboard
  2. Read recommended feed for today
- **Expected Result:** Recommended feed = 1.5 kg (1.5 kg per 100K × 1.0 density factor). Meal count = 2 (DOC 1 rule). Each meal = 0.75 kg. No tray or FCR corrections (DOC ≤ 30).
- **Edge Case Notes:** If actual_feed_yesterday is null (first day), continuity guard must not clamp — there is no previous day. Verify engine handles null yesterday gracefully.
- **Severity if Failed:** S1

---

### TC-FEED-002
- **Module:** Feed Engine
- **Priority:** P0
- **Feature:** Density scaling for large stocking
- **Preconditions:** Pond: Seed Count=300,000, Seed Type=Hatchery Small, DOC=1.
- **Steps:**
  1. Navigate to Feed tab
  2. Read recommended feed
- **Expected Result:** Recommended feed = 4.5 kg (1.5 × 300K/100K = 1.5 × 3 = 4.5 kg). Not 1.5 kg. Density scaling must be applied.
- **Edge Case Notes:** Formula is `base × (seedCount / 100,000)`. Verify no rounding error at 300K vs 299,999 boundary.
- **Severity if Failed:** S1

---

### TC-FEED-003
- **Module:** Feed Engine
- **Priority:** P0
- **Feature:** Daily increment DOC 1→7
- **Preconditions:** Pond: Seed Count=100,000, Hatchery Small.
- **Steps:**
  1. Observe recommended feed at DOC 1, 2, 3, 4, 5, 6, 7
- **Expected Result:**
  - DOC 1: 1.5 kg
  - DOC 2: 1.7 kg
  - DOC 3: 1.9 kg
  - DOC 4: 2.1 kg
  - DOC 5: 2.3 kg
  - DOC 6: 2.5 kg
  - DOC 7: 2.7 kg
  Each day increases by exactly +0.2 kg (for 100K seed count).
- **Edge Case Notes:** If continuity guard (±30%) interferes with early days, verify it does NOT clamp the ramp-up — it should only apply if previous day actual feed is available.
- **Severity if Failed:** S1

---

### TC-FEED-004
- **Module:** Feed Engine
- **Priority:** P0
- **Feature:** Hard limits — feed amount clamp
- **Preconditions:** Pond with Seed Count=1,000,000 (max), DOC=25.
- **Steps:**
  1. Navigate to Feed tab
  2. Read recommended feed
- **Expected Result:** Feed recommendation is clamped to 50.0 kg maximum. Not 150 kg (what unclamped 1M × base would calculate). Hard limit enforced.
- **Edge Case Notes:** Also test lower bound: if engine somehow outputs 0.05 kg, clamp must bring it to 0.1 kg (kAbsoluteMinFeed).
- **Severity if Failed:** S1

---

### TC-FEED-005
- **Module:** Feed Engine
- **Priority:** P0
- **Feature:** Feed round completion — correct logging
- **Preconditions:** Pond at DOC=10. Feed schedule shows Round 1 (06:00) = 2.1 kg.
- **Steps:**
  1. Navigate to Feed tab
  2. Tap "Complete Round 1"
  3. Confirm or enter actual amount (2.1 kg as given)
  4. Observe feed history
- **Expected Result:** `feed_logs` row inserted: `{pond_id, doc=10, round=1, feed_given=2.1, base_feed=2.1}`. Feed round status changes from "Planned" to "Completed." Feed history screen shows the entry. DOC cumulative total updates.
- **Edge Case Notes:** Verify the RPC returns `success=true`. Verify `alreadyCompleted=false` on first submit.
- **Severity if Failed:** S1

---

### TC-FEED-006
- **Module:** Feed Engine
- **Priority:** P0
- **Feature:** Feed round completion idempotency
- **Preconditions:** Round 1 at DOC=10 not yet completed. Network is slow (simulate via throttled connection).
- **Steps:**
  1. Tap "Complete Round 1"
  2. Before the success response arrives, tap again
  3. Wait for both requests to complete
- **Expected Result:** `feed_logs` has exactly ONE row for (pond_id, doc=10, round=1). Second RPC call returns `operationDuplicate=true` or `alreadyCompleted=true`. Feed history shows one entry, not two.
- **Edge Case Notes:** `operationId` is generated once per screen instance. Verify the same `operationId` is used for both taps (not a new one generated per tap).
- **Severity if Failed:** S1

---

### TC-FEED-007
- **Module:** Feed Engine
- **Priority:** P1
- **Feature:** DOC 30→31 mode transition (ramp mode)
- **Preconditions:** PRO user. Pond at DOC=31. No tray logs, no water logs (engine uses safe defaults).
- **Steps:**
  1. Navigate to Feed tab at DOC=31
  2. Read recommended feed
- **Expected Result:** Ramp factor of 0.75 applied: `feed = blind_base(DOC=31) × 0.75`. Result must be 75% of what pure smart mode would give. NO cliff from DOC 30 to 31 (not a sudden jump to full smart mode).
- **Edge Case Notes:** At DOC=35, ramp factor = 0.95 (not 1.0). At DOC=36, full smart mode. Verify the 5-day ramp table.
- **Severity if Failed:** S1

---

### TC-FEED-008
- **Module:** Feed Engine
- **Priority:** P1
- **Feature:** Feed history — daily cumulative total
- **Preconditions:** Pond at DOC=10. All 4 rounds logged: 2.1, 2.1, 2.1, 2.1 kg.
- **Steps:**
  1. Navigate to Feed History screen
  2. Observe DOC 10 row
- **Expected Result:** DOC 10 total shown as 8.4 kg (sum of 4 rounds). Last-row-wins logic does not affect this (all 4 rounds are different round numbers, not duplicates).
- **Edge Case Notes:** `get_cumulative_feed_safe` RPC sums `feed_logs.feed_given` for a DOC range. Verify the sum includes only today's rounds, not previous days' rounds in the DOC total.
- **Severity if Failed:** S2

---

### TC-FEED-009
- **Module:** Feed Engine
- **Priority:** P1
- **Feature:** Manual feed override
- **Preconditions:** Pond at DOC=15. Recommended feed = 3.0 kg per round. Farmer wants to override to 2.5 kg.
- **Steps:**
  1. Tap to complete round
  2. Manually change amount to 2.5 kg
  3. Submit
- **Expected Result:** `feed_logs` records `feed_given=2.5, base_feed=3.0`. UI shows actual=2.5. Next day's continuity guard uses 2.5 kg (actual, not planned) as "yesterday's feed." FCR cumulative total uses 2.5 kg.
- **Edge Case Notes:** `is_manual=true` flag should be set in feed_rounds. Verify continuity guard uses actual, not planned, for tomorrow's base.
- **Severity if Failed:** S2

---

### TC-FEED-010
- **Module:** Feed Engine
- **Priority:** P2
- **Feature:** Continuity guard — prevents extreme jumps
- **Preconditions:** Yesterday's actual feed = 5.0 kg (DOC 29). Engine calculates tomorrow (DOC 30) as 8.0 kg without guard.
- **Steps:**
  1. Observe feed recommendation at DOC 30
- **Expected Result:** Recommendation is clamped to max 5.0 × 1.30 = 6.5 kg (not 8.0 kg). ±30% continuity guard applied.
- **Edge Case Notes:** Also test the downward clamp: if engine calculates 2.0 kg from 5.0 kg yesterday, clamp brings it to 5.0 × 0.70 = 3.5 kg minimum.
- **Severity if Failed:** S2

---

# SECTION 6 — SMART FEEDING LOGIC (TC-SMART)

---

### TC-SMART-001
- **Module:** Smart Feed Engine
- **Priority:** P0
- **Feature:** FREE user — smart feed corrections NOT applied
- **Preconditions:** FREE plan user. Pond at DOC=40. Tray logs showing all Empty (should trigger increase). Water DO = 6.5 mg/L.
- **Steps:**
  1. Navigate to Feed tab at DOC=40
  2. Observe recommendation and explanation
- **Expected Result:** Feed recommendation = blind phase continuation with NO tray correction, NO FCR correction, NO env correction. Tray correction = MAINTAIN (forced). Explanation clearly states PRO upgrade required for smart feeding. Feed amount is NOT increased despite all-Empty trays.
- **Edge Case Notes:** Tray logs are still collected and stored for FREE users — the signal is silently ignored at the engine level, not at the logging level.
- **Severity if Failed:** S1

---

### TC-SMART-002
- **Module:** Smart Feed Engine
- **Priority:** P0
- **Feature:** PRO user — all 3 corrections applied together
- **Preconditions:** PRO user. DOC=45. Tray logs: 3 empty, 1 light (average score = 0.75 → INCREASE). DO = 6.5 (normal). FCR = 1.3 (good → +5%).
- **Steps:**
  1. Navigate to Feed tab
  2. Read recommendation and breakdown
- **Expected Result:** Final feed = base × tray(+5%) × FCR(+5%) × env(1.0). Both corrections compound. Breakdown card shows each factor separately: base, tray adjustment, FCR adjustment, env factor. Result is higher than base.
- **Edge Case Notes:** Verify corrections compound (multiply) rather than add: `base × 1.05 × 1.05 ≠ base × 1.10`. The product should be 1.1025×, not 1.10×.
- **Severity if Failed:** S1

---

### TC-SMART-003
- **Module:** Smart Feed Engine
- **Priority:** P0
- **Feature:** DO stop condition
- **Preconditions:** PRO user. Pond at DOC=50. Latest water log: DO = 3.2 mg/L (below critical 3.5).
- **Steps:**
  1. Navigate to Feed tab
  2. Read recommendation
- **Expected Result:** Recommended feed = 0.0 kg. Alert strip visible saying "STOP FEEDING — DO critically low (3.2 mg/L)." All 4 rounds should show 0 kg. This is the most critical safety rule in the app.
- **Edge Case Notes:** Test exact boundary: DO = 3.5 → still triggers STOP. DO = 3.51 → does NOT trigger STOP (moves to REDUCE tier: DO < 4.5). Verify boundary behavior precisely.
- **Severity if Failed:** S1

---

### TC-SMART-004
- **Module:** Smart Feed Engine
- **Priority:** P0
- **Feature:** Temperature stop condition
- **Preconditions:** PRO user. Pond at DOC=40. Water temp = 37°C (above critical 36°C).
- **Steps:**
  1. Navigate to Feed tab
  2. Read recommendation
- **Expected Result:** Recommended feed = 0.0 kg. Warning visible about temperature. Same STOP behavior as critical DO.
- **Edge Case Notes:** Also test temp = 21°C (below critical 22°C) → STOP. Temp = 23°C (below warning 24°C) → REDUCE 50%.
- **Severity if Failed:** S1

---

### TC-SMART-005
- **Module:** Smart Feed Engine
- **Priority:** P1
- **Feature:** Stale water data → safe defaults
- **Preconditions:** PRO user. Pond at DOC=40. Last water log was 50 hours ago (> 48h threshold).
- **Steps:**
  1. Navigate to Feed tab
  2. Read recommendation and data age warning
- **Expected Result:** Engine uses safe defaults: DO=6.0, temp=28°C, NH3=0.05. Feed is NOT reduced or stopped due to stale data. A warning banner says "Water data is more than 48 hours old — please log a new test." Recommendation continues as normal (safe defaults mean env factor = 1.0).
- **Edge Case Notes:** This is important — stale water data must NOT trigger a false STOP. Farmers who forget to log water data should not have their fish starved.
- **Severity if Failed:** S1

---

### TC-SMART-006
- **Module:** Smart Feed Engine
- **Priority:** P1
- **Feature:** FCR correction applied to smart feed
- **Preconditions:** PRO user. DOC=50. ABW=14g (sampled 2 days ago). Seed count=200,000. Total feed given so far = 280 kg.
- **Steps:**
  1. Compute expected FCR: biomass = 200,000 × 0.90 × 14/1000 = 2,520 kg. FCR = 280/2520 = 0.111 ... wait that doesn't work. Let me recalculate.
     Actually: biomass = 200,000 × 0.90 × (14g/1000) = 200,000 × 0.90 × 0.014 = 200,000 × 0.0126 = 2,520 kg. FCR = 280/2520 = 0.111. That's below 0.5 — would be discarded as corrupted.
     
     Use realistic values: seed=100,000, ABW=14g, total_feed=230 kg. biomass = 100,000 × 0.90 × 0.014 = 1,260 kg. FCR = 230/1260 = 0.182. Still discarded.
     
     Realistic at DOC 50: seed=100,000, ABW=14g = about right for DOC 50. Survival rate 90%. Biomass = 100K × 0.9 × 0.014 kg = 1,260 kg. Total feed for 50 days at ~2-3 kg/day = 100-150 kg. FCR = 120/1260 = 0.095. Still <0.5.
     
     Hmm, the FCR formula might be grams-based differently. Let me re-read: `FCR = totalFeedGiven_kg / biomass_kg`. At DOC 50, ABW is about 5-8g typically. 
     
     seed=100,000, ABW=5g (DOC 50 expected), survival=0.90. biomass = 100,000 × 0.9 × 5/1000 = 450 kg. Total feed = 90 days × 2kg/day = 180 kg. FCR = 180/450 = 0.4. Still < 0.5.
     
     The issue is that shrimp FCR in aquaculture is typically 1.2-1.8. The formula must be wrong in my analysis, or this is a cumulative FCR that doesn't behave the same way as traditional FCR. Let me just use values that produce a realistic FCR for the test case: set ABW=5g, seed=100K, total_feed=800 kg → FCR = 800/450 = 1.78. That gives FCR > 1.5 → -15% correction. Use that.
  
  1. Navigate to Feed tab
  2. Observe FCR value shown on dashboard and feed breakdown
- **Expected Result:** FCR > 1.5 → feed correction = -15%. Recommended feed = base × 0.85. FCR badge shown in red/warning color. Breakdown explains FCR correction applied.
- **Edge Case Notes:** FCR < 0.5 or FCR > 5.0 must be discarded as corrupted, not applied. Verify these boundary conditions separately.
- **Severity if Failed:** S2

---

### TC-SMART-007
- **Module:** Smart Feed Engine
- **Priority:** P1
- **Feature:** Kill switch disables engine
- **Preconditions:** Access to Supabase `app_config` table. Set `feed_kill_switch = true`.
- **Steps:**
  1. Set `app_config` key `feed_kill_switch` to `true`
  2. Open app (or force-refresh config)
  3. Navigate to any pond's Feed tab
- **Expected Result:** Feed recommendation is disabled / engine returns safe fallback. UI shows a message: "Feed recommendations temporarily unavailable." Farmer can still manually log feed amounts but no smart recommendation is generated.
- **Edge Case Notes:** Kill switch must propagate within 1 app restart (config is loaded at startup via `AppConfigService`). Existing logged feed rounds are NOT deleted.
- **Severity if Failed:** S2

---

### TC-SMART-008
- **Module:** Smart Feed Engine
- **Priority:** P2
- **Feature:** Global feed multiplier
- **Preconditions:** Set `app_config.global_feed_multiplier = 1.1` (10% multiplier for A/B test).
- **Steps:**
  1. Navigate to Feed tab (DOC=20, 100K seed)
  2. Note normal recommendation = 5.3 kg
  3. After multiplier set, note new recommendation
- **Expected Result:** Recommendation = 5.3 × 1.1 = 5.83 kg. Multiplier applied to all ponds across all users. No UI disclosure of multiplier (it's a backend control).
- **Edge Case Notes:** Multiplier of 0.0 would effectively kill all feed → dangerous. Verify any multiplier below 0.5 or above 2.0 is rejected/clamped at the config layer.
- **Severity if Failed:** S3

---

# SECTION 7 — TRAY ADJUSTMENT LOGIC (TC-TRAY)

---

### TC-TRAY-001
- **Module:** Tray Decision Engine
- **Priority:** P0
- **Feature:** All-Empty tray → INCREASE decision
- **Preconditions:** PRO user. DOC=40. 4 trays. Log 3 consecutive tray sessions: all 4 trays Empty each time.
- **Steps:**
  1. Log tray status (all 4 trays: Empty) 3 times on different rounds
  2. Navigate to Feed tab
  3. Read next feed recommendation vs baseline
- **Expected Result:** avg_score = 1.0 (≥ 0.6 threshold). Tray decision = INCREASE. Recommended feed is 5% higher than base calculation. Breakdown card shows "+5% tray adjustment."
- **Edge Case Notes:** Decision requires exactly 3 logs minimum (rolling window). With only 1-2 logs, decision should be MAINTAIN.
- **Severity if Failed:** S1

---

### TC-TRAY-002
- **Module:** Tray Decision Engine
- **Priority:** P0
- **Feature:** All-Heavy tray → REDUCE decision
- **Preconditions:** PRO user. DOC=40. 4 trays. Log 3 consecutive sessions: all 4 trays Heavy.
- **Steps:**
  1. Log 3 consecutive sessions with all trays: Heavy
  2. Navigate to Feed tab
- **Expected Result:** avg_score = -1.0 (≤ -0.6 threshold). Tray decision = REDUCE. Recommended feed is 10% lower than base. Breakdown card shows "-10% tray adjustment."
- **Edge Case Notes:** Consecutive reduce dampening: if this is the SECOND consecutive REDUCE decision, the adjustment should be dampened (not doubled). Verify -10% is capped and not applied twice.
- **Severity if Failed:** S1

---

### TC-TRAY-003
- **Module:** Tray Decision Engine
- **Priority:** P0
- **Feature:** Mixed trays → MAINTAIN (noise absorption)
- **Preconditions:** PRO user. DOC=40. 4 trays. Log 3 sessions: 2 Empty, 2 Heavy each time.
- **Steps:**
  1. Log 3 sessions: Tray 1=Empty, Tray 2=Empty, Tray 3=Heavy, Tray 4=Heavy
  2. Navigate to Feed tab
- **Expected Result:** avg_score = (1.0+1.0-1.0-1.0)/4 = 0.0 → within ±0.6 threshold → MAINTAIN. No adjustment. Feed = base. Confirms noise absorption works.
- **Edge Case Notes:** Test also 3 Empty + 1 Heavy: score = (1+1+1-1)/4 = 0.5 → MAINTAIN (below 0.6 threshold). Only 4 Empty triggers INCREASE.
- **Severity if Failed:** S1

---

### TC-TRAY-004
- **Module:** Tray Decision Engine
- **Priority:** P1
- **Feature:** Less than 4 trays → MAINTAIN forced
- **Preconditions:** PRO user. Pond configured with 3 trays. DOC=40. Log 3 sessions: all 3 trays Empty.
- **Steps:**
  1. Log 3 sessions with all 3 trays Empty
  2. Navigate to Feed tab
- **Expected Result:** Despite all-Empty signal, decision = MAINTAIN. Reason: < 4 trays required for confidence signal. Recommendation unchanged. Feed breakdown shows "Tray: MAINTAIN (insufficient tray count for signal)."
- **Edge Case Notes:** This is a real scenario — smaller ponds may have fewer trays. Engine must not increase feed based on an under-confident signal.
- **Severity if Failed:** S2

---

### TC-TRAY-005
- **Module:** Tray Decision Engine
- **Priority:** P1
- **Feature:** Tray log wizard — back navigation preserves state
- **Preconditions:** Pond has 4 trays. User opens Tray Log wizard.
- **Steps:**
  1. Open Tray Log wizard
  2. On Tray 1: select "Empty"
  3. Navigate to Tray 2: select "Light"
  4. Tap Back button
  5. Verify Tray 2 status is cleared or preserved
  6. Navigate forward again to Tray 3: select "Heavy"
  7. Submit all trays
- **Expected Result:** Either (a) Tray 2 status is preserved on Back/Forward navigation, OR (b) Tray 2 is cleared and must be re-entered — but the wizard does not skip Tray 2 and go straight to Tray 3. No partial submission possible.
- **Edge Case Notes:** The wizard must not submit unless ALL trays have been logged. Partial tray submission corrupts the tray signal.
- **Severity if Failed:** S2

---

### TC-TRAY-006
- **Module:** Tray Decision Engine
- **Priority:** P1
- **Feature:** Consecutive increase dampen
- **Preconditions:** PRO user. DOC=45. Previous day's tray decision was INCREASE (+5%). Today's tray logs again show all Empty (avg_score ≥ 0.6).
- **Steps:**
  1. Observe today's tray decision
- **Expected Result:** Today's increase is dampened to +3% (not +5%). Consecutive increase dampen rule applied: `+5% → +3%` on the second consecutive INCREASE.
- **Edge Case Notes:** If a MAINTAIN or REDUCE intervenes between two INCREASEs, the dampen resets and next INCREASE is +5% again.
- **Severity if Failed:** S2

---

### TC-TRAY-007
- **Module:** Tray Decision Engine
- **Priority:** P2
- **Feature:** DOC ≤ 30 → tray signal ignored
- **Preconditions:** PRO user. Pond at DOC=28. Log 3 tray sessions: all Empty.
- **Steps:**
  1. Navigate to Feed tab
  2. Read tray adjustment
- **Expected Result:** Tray decision = MAINTAIN, even for PRO user. Reason: DOC ≤ 30 = blind phase. Tray logs are stored but not applied to recommendations.
- **Edge Case Notes:** This is a correctness rule — tray-based corrections do not apply during blind feeding phase regardless of subscription tier.
- **Severity if Failed:** S2

---

### TC-TRAY-008
- **Module:** Tray Decision Engine
- **Priority:** P2
- **Feature:** Tray log rolling window — only last 3 sessions used
- **Preconditions:** PRO user. DOC=45. 5 tray sessions logged: first 2 are all Heavy (old), last 3 are all Empty (recent).
- **Steps:**
  1. Navigate to Feed tab
- **Expected Result:** Only the 3 most recent sessions are used. avg_score = 1.0 (all Empty, 3 sessions). Decision = INCREASE. The 2 Heavy sessions from earlier do not drag the average down.
- **Edge Case Notes:** Rolling window of 3 is critical for responsiveness. If all 5 sessions were averaged, score = (1+1+1-1-1)/5 = 0.2 → MAINTAIN — wrong behavior.
- **Severity if Failed:** S3

---

# SECTION 8 — SAMPLING SYSTEM (TC-SAMP)

---

### TC-SAMP-001
- **Module:** Growth Sampling
- **Priority:** P1
- **Feature:** ABW calculation from sample
- **Preconditions:** Pond at DOC=30. Navigate to Growth tab → Sampling Screen.
- **Steps:**
  1. Enter: Total weight = 0.050 kg (50g), Piece count = 10
  2. Submit sample
- **Expected Result:** ABW calculated as `50g / 10 = 5.0g`. Dashboard shows ABW = 5.0g. Sampling saved with correct DOC=30. `samplings` table row inserted.
- **Edge Case Notes:** Test with different units. If farmer enters 50 (as grams directly), verify the app handles unit clarity. Piece count = 0 must be rejected (div-by-zero guard).
- **Severity if Failed:** S2

---

### TC-SAMP-002
- **Module:** Growth Sampling
- **Priority:** P1
- **Feature:** Duplicate sampling — same DOC constraint
- **Preconditions:** Sample already logged for DOC=30.
- **Steps:**
  1. Try to log another sample for DOC=30 (same pond, same DOC)
- **Expected Result:** App either (a) shows "Sample already logged for today (DOC 30)" and prevents duplicate, OR (b) updates/overwrites the existing sample for this DOC. UNIQUE constraint on (pond_id, doc) in `samplings` table prevents silent duplication.
- **Edge Case Notes:** The DB constraint will cause an insert error if the app does not check first. App must handle this gracefully (not crash/show raw error).
- **Severity if Failed:** S2

---

### TC-SAMP-003
- **Module:** Growth Sampling
- **Priority:** P1
- **Feature:** Stale sample — 7-day cutoff
- **Preconditions:** Sample logged 8 days ago (DOC=22 of a now-DOC=30 pond). No new sample since.
- **Steps:**
  1. Navigate to Growth tab
  2. Observe ABW display and its age indicator
  3. Navigate to Feed tab
- **Expected Result:** ABW displayed with age warning: "Sample is 8 days old." Feed engine disables ABW signal (treats as null). Expected ABW from reference table used instead. FCR NOT calculated (requires valid ABW). Recommendation continues safely without crashing.
- **Edge Case Notes:** Test exact boundary: sample exactly 7 days old → should this be stale or fresh? Confirm off-by-one behavior.
- **Severity if Failed:** S2

---

### TC-SAMP-004
- **Module:** Growth Sampling
- **Priority:** P2
- **Feature:** Sampling enables intelligent feed mode
- **Preconditions:** PRO user. DOC=45. Fresh ABW sample (taken today) = 10g.
- **Steps:**
  1. Log ABW sample
  2. Navigate to Feed tab
  3. Observe feed mode indicator
- **Expected Result:** Feed mode shows "Intelligent" (DOC ≥ 40 AND fresh sample). Feed recommendation uses actual ABW for FCR calculation, not expected table value. Breakdown shows "Using sampled ABW: 10.0g."
- **Edge Case Notes:** DOC must be ≥ 40 AND sample must be < 7 days old. If either condition fails, mode = "Smart" (not Intelligent).
- **Severity if Failed:** S3

---

### TC-SAMP-005
- **Module:** Growth Sampling
- **Priority:** P2
- **Feature:** Piece count validation
- **Preconditions:** Sampling form open.
- **Steps:**
  1. Enter piece count = 0
  2. Attempt submit
- **Expected Result:** Validation error: "Piece count must be at least 1." Form not submitted. No division-by-zero reaches the engine.
- **Edge Case Notes:** Also test: piece count = -1 (negative), `abc` (non-numeric), `99999` (very large but valid). Only 0 and negatives should be rejected.
- **Severity if Failed:** S2

---

# SECTION 9 — ABW CALCULATIONS (TC-ABW)

---

### TC-ABW-001
- **Module:** ABW / Growth Engine
- **Priority:** P1
- **Feature:** Expected ABW table interpolation
- **Preconditions:** No sampling data. Pond at DOC=45.
- **Steps:**
  1. Navigate to Growth tab or Overview
  2. Observe ABW value shown
- **Expected Result:** ABW shown is the interpolated expected value for DOC=45 from the reference table. Between DOC 30 (5.0g) and DOC 60 (22.0g): `5.0 + (45-30)/(60-30) × (22.0-5.0) = 5.0 + 0.5 × 17.0 = 5.0 + 8.5 = 13.5g`. Display should indicate this is "expected" not "sampled."
- **Edge Case Notes:** Verify the interpolation is linear between table keypoints, not stepped.
- **Severity if Failed:** S2

---

### TC-ABW-002
- **Module:** ABW / Growth Engine
- **Priority:** P1
- **Feature:** Sampled ABW overrides expected table
- **Preconditions:** Pond at DOC=45. Expected ABW=13.5g. Farmer logs sample: ABW=11g (below expected — slow growth).
- **Steps:**
  1. Log sample with result: 11g ABW
  2. Navigate to Overview / Growth tab
- **Expected Result:** Dashboard shows ABW=11g (sampled), not 13.5g (expected). Indicator shows "Sampled." Feed engine and FCR engine use 11g, not 13.5g. Growth trend chart (if shown) reflects the gap vs expected.
- **Edge Case Notes:** This is critical for FCR accuracy. If expected value is accidentally used instead of sampled, FCR and biomass calculations are wrong.
- **Severity if Failed:** S1

---

### TC-ABW-003
- **Module:** ABW / Growth Engine
- **Priority:** P2
- **Feature:** ABW = 0 guard
- **Preconditions:** Sampling form.
- **Steps:**
  1. Enter total weight = 0g, piece count = 10
  2. Submit
- **Expected Result:** ABW = 0g — validation error shown: "Total weight must be greater than 0." OR app prevents submission. ABW=0 must NOT reach the FCR engine (div by zero risk).
- **Edge Case Notes:** Even if 0g somehow gets stored, FCR engine must reject biomass < 1.0 kg as a second safety net.
- **Severity if Failed:** S2

---

### TC-ABW-004
- **Module:** ABW / Growth Engine
- **Priority:** P2
- **Feature:** ABW dashboard trend
- **Preconditions:** 5 samples taken at DOC 10, 20, 30, 40, 50 with ABW values 0.5, 2.0, 5.0, 8.0, 12.0g.
- **Steps:**
  1. Navigate to Growth tab
  2. Observe ABW trend visualization
- **Expected Result:** Chart shows 5 data points in ascending order. "Expected" line shows reference table values. Actual sampled dots match the input values. Trend direction (positive) clearly visible.
- **Edge Case Notes:** Chart must handle the case where sampled ABW is ABOVE expected (fast-growing batch) without distorting the y-axis.
- **Severity if Failed:** S3

---

# SECTION 10 — FCR CALCULATIONS (TC-FCR)

---

### TC-FCR-001
- **Module:** FCR Engine
- **Priority:** P0
- **Feature:** FCR computation — correct formula
- **Preconditions:** PRO user. DOC=60. Seed count=100,000. ABW=18g (sampled). Total feed given = 270 kg.
- **Steps:**
  1. Navigate to Overview or Feed tab
  2. Read FCR value displayed
- **Expected Result:** 
  `biomass = 100,000 × 0.90 × 0.018 = 1,620 kg`
  `FCR = 270 / 1,620 = 0.1667` — wait, this is below 0.5, would be discarded.
  
  Let me use realistic values: DOC=60, seed=100,000, ABW=18g. Survival=90%. Total feed for 60 days: approximately 3 meals × 4kg/meal × 60 = 720 kg (rough). biomass = 100K × 0.9 × 0.018 = 1,620 kg. FCR = 720/1620 = 0.44. Still < 0.5.
  
  **Note for QA team:** The FCR formula in this app computes FCR as total_feed / estimated_biomass. For L. vannamei at DOC 60, ABW 18g, 100K seed with 90% survival: biomass = 1620 kg. If total feed = 1800 kg over 60 days → FCR = 1800/1620 = 1.11 (realistic). Test with: seed=100,000, ABW=18g, total_feed=1,800 kg.
  
  `biomass = 100,000 × 0.90 × 18/1000 = 1,620 kg`
  `FCR = 1800 / 1620 = 1.111`
  
  Expected FCR ≈ 1.11 (very good range).
  
  FCR adjustment: FCR ≤ 1.2 → +10% feed increase.
- **Edge Case Notes:** Verify that `feed_logs` sum uses last-row-wins logic per (pond_id, doc, round). If a round was corrected, only the latest entry counts.
- **Severity if Failed:** S1

---

### TC-FCR-002
- **Module:** FCR Engine
- **Priority:** P0
- **Feature:** FCR guard — corrupted values discarded
- **Preconditions:** Manually set conditions where FCR would compute as 0.3 (below 0.5 minimum valid).
- **Steps:**
  1. Set pond: seed=100,000, ABW=20g, total_feed=100 kg (very low feed for high biomass)
  2. Navigate to Feed tab
- **Expected Result:** FCR is flagged as invalid (< 0.5). FCR correction = 0% (not applied). No crash. Feed recommendation continues with base + tray + env corrections only. Debug log or internal warning generated.
- **Edge Case Notes:** FCR > 5.0 case: set very high total_feed, very low ABW → FCR > 5 → also discarded. Verify upper bound too.
- **Severity if Failed:** S1

---

### TC-FCR-003
- **Module:** FCR Engine
- **Priority:** P0
- **Feature:** Biomass < 1.0 kg guard
- **Preconditions:** Pond at DOC=5. Seed count=1,000 (tiny pond). ABW=0.1g.
- **Steps:**
  1. Navigate to Feed tab
- **Expected Result:** `biomass = 1,000 × 0.90 × 0.0001 = 0.09 kg`. This is < 1.0 kg guard. FCR NOT computed. FCR correction = 0% (not applied). No division error. Feed continues normally using base engine.
- **Edge Case Notes:** Critical guard to prevent division issues in tiny ponds or early DOC when ABW is near zero.
- **Severity if Failed:** S1

---

### TC-FCR-004
- **Module:** FCR Engine
- **Priority:** P1
- **Feature:** FCR drives feed increase (FCR ≤ 1.0)
- **Preconditions:** PRO user. DOC=55. FCR = 0.8 (exceptional — shrimp eating efficiently, growing fast).
- **Steps:**
  1. Navigate to Feed tab
  2. Read FCR adjustment
- **Expected Result:** FCR ≤ 1.0 → +15% feed increase. Shrimp are converting very efficiently; more feed will accelerate growth. Breakdown shows "+15% FCR correction."
- **Edge Case Notes:** FCR = 0.8 is extremely good; verify it's accepted as valid (> 0.5) and the +15% correction is applied correctly.
- **Severity if Failed:** S2

---

### TC-FCR-005
- **Module:** FCR Engine
- **Priority:** P1
- **Feature:** FCR poor range drives feed decrease
- **Preconditions:** PRO user. DOC=60. FCR = 1.6 (poor — overfeeding or poor conversion).
- **Steps:**
  1. Navigate to Feed tab
- **Expected Result:** FCR > 1.5 → -15% feed reduction. Breakdown shows "-15% FCR correction." Total recommendation is 15% lower than base × env × tray result.
- **Edge Case Notes:** FCR = 1.5 exactly → boundary test. FCR ≤ 1.5 means ≤, so 1.5 applies -10%. FCR > 1.5 means > 1.5, so 1.501 applies -15%.
- **Severity if Failed:** S2

---

### TC-FCR-006
- **Module:** FCR Engine
- **Priority:** P1
- **Feature:** FCR updates when new sampling data added
- **Preconditions:** FCR previously computed with old ABW=12g. Farmer adds new sample: ABW=15g.
- **Steps:**
  1. Log new sample: ABW=15g
  2. Navigate to Feed tab
  3. Read FCR value
- **Expected Result:** FCR recalculates using new ABW=15g. Biomass increases. FCR changes accordingly. Old FCR value no longer shown.
- **Edge Case Notes:** Riverpod provider for FCR must invalidate and recompute when `growthProvider` updates.
- **Severity if Failed:** S2

---

### TC-FCR-007
- **Module:** FCR Engine
- **Priority:** P2
- **Feature:** FCR accuracy — last-row-wins for daily feed total
- **Preconditions:** DOC=20 had two entries in feed_logs for round=1 (first: 3.0 kg, second/correction: 2.8 kg).
- **Steps:**
  1. Observe total feed shown for DOC 20
  2. Observe FCR calculation
- **Expected Result:** Total for DOC 20, round 1 uses the LAST row: 2.8 kg (not 3.0 kg, not 5.8 kg). FCR uses this corrected value. This confirms "last row authoritative" behavior for duplicate round entries.
- **Edge Case Notes:** This is a data integrity test. Double-submit could create two rows; only the last should count. Verify RPC upserts, not inserts.
- **Severity if Failed:** S2

---

### TC-FCR-008
- **Module:** FCR Engine
- **Priority:** P2
- **Feature:** FCR display on Overview tab
- **Preconditions:** Valid FCR computed (1.25).
- **Steps:**
  1. Navigate to Pond Dashboard → Overview tab
  2. Observe KPI row
- **Expected Result:** FCR=1.25 shown in KPI row. Color coding: green if ≤ 1.3 (good), yellow if 1.3–1.5 (warning), red if > 1.5 (poor). Tapping FCR card should show explanation of what FCR means and current status.
- **Edge Case Notes:** When FCR cannot be computed (stale ABW, biomass < 1kg), show "—" or "N/A" rather than 0.00 or null.
- **Severity if Failed:** S3

---

# SECTION 11 — DASHBOARD METRICS (TC-DASH)

---

### TC-DASH-001
- **Module:** Dashboard / Home
- **Priority:** P1
- **Feature:** Pond card shows correct KPIs
- **Preconditions:** Pond at DOC=30. ABW=5g (expected). FCR=1.3. Total harvest=0 (mid-cycle).
- **Steps:**
  1. View HomeScreen pond card
- **Expected Result:** Pond card shows: DOC=30, ABW=5.0g (with "expected" indicator), FCR=1.30, biomass estimate visible. Data matches Overview tab in Pond Dashboard.
- **Edge Case Notes:** KPIs on card must match KPIs on pond dashboard exactly (no staleness between screens).
- **Severity if Failed:** S2

---

### TC-DASH-002
- **Module:** Dashboard / Home
- **Priority:** P1
- **Feature:** Farm-level KPIs aggregate across ponds
- **Preconditions:** Farm with 2 active ponds: Pond A (total feed 500 kg, revenue ₹50,000), Pond B (total feed 300 kg, revenue ₹30,000).
- **Steps:**
  1. Navigate to HomeScreen
  2. Observe farm-level KPI row
- **Expected Result:** Farm total feed = 800 kg. Farm total revenue = ₹80,000. These are sum aggregations. If farm has no harvests yet, revenue shows ₹0 or "—", not crash.
- **Edge Case Notes:** Ponds in different DOC phases contribute correctly. A pond with no feed logs should not break the aggregation (treat as 0).
- **Severity if Failed:** S2

---

### TC-DASH-003
- **Module:** Dashboard / Home
- **Priority:** P2
- **Feature:** Empty state — no ponds
- **Preconditions:** Farm exists but has 0 ponds.
- **Steps:**
  1. Navigate to HomeScreen
- **Expected Result:** Empty state shown: illustration + text "Add your first pond to start tracking" + "Add Pond" CTA button. No crash, no blank white screen, no "null" text visible.
- **Edge Case Notes:** Different empty states for: no farms (add farm), farm but no ponds (add pond), pond but no feed logs (different state).
- **Severity if Failed:** S2

---

### TC-DASH-004
- **Module:** Dashboard / Home
- **Priority:** P2
- **Feature:** Feed trend card accuracy
- **Preconditions:** 7 days of feed history logged.
- **Steps:**
  1. View Feed Trend card on HomeScreen
- **Expected Result:** 7-bar chart shows correct feed totals per day for past 7 days. Most recent day on the right. Y-axis scale adjusts to data. Today's bar highlighted differently.
- **Edge Case Notes:** If a day has no feed logs, bar should show 0 height, not missing/broken bar.
- **Severity if Failed:** S3

---

### TC-DASH-005
- **Module:** Dashboard / Overview
- **Priority:** P2
- **Feature:** Biomass estimation on Overview tab
- **Preconditions:** Pond: seed=200,000, ABW=8g, survival assumption=90%.
- **Steps:**
  1. Navigate to Pond Dashboard → Overview
  2. Observe biomass estimate
- **Expected Result:** `biomass = 200,000 × 0.90 × 8/1000 = 1,440 kg`. Displayed as approximately 1,440 kg or 1.44 tonnes. Tooltip or info icon explains the 90% survival assumption.
- **Edge Case Notes:** Biomass display should use appropriate units (kg vs tonnes) based on magnitude. 50 kg should not display as "0.05 tonnes."
- **Severity if Failed:** S3

---

# SECTION 12 — COST TRACKING (TC-COST)

---

### TC-COST-001
- **Module:** Expense Tracking
- **Priority:** P1
- **Feature:** Log expense — feed category
- **Preconditions:** User navigated to Expense Summary screen. Crop cycle active.
- **Steps:**
  1. Tap "Add Expense"
  2. Category: Feed, Amount: ₹12,500, Notes: "5 bags Higashimaru 35", Date: today
  3. Submit
- **Expected Result:** Expense saved to `expenses` table with correct user_id, farm_id, crop_id, category=feed, amount=12500. Expense Summary shows the new entry. Monthly total updates. Feed category total increases by ₹12,500.
- **Edge Case Notes:** Amount = 0 must be rejected. Amount = negative must be rejected. Amount with currency symbol in input (₹12,500) must be stripped and parsed as 12500.
- **Severity if Failed:** S2

---

### TC-COST-002
- **Module:** Expense Tracking
- **Priority:** P1
- **Feature:** Monthly expense aggregation
- **Preconditions:** 3 expenses logged in current month: ₹10,000 (feed), ₹5,000 (labor), ₹2,000 (supplements).
- **Steps:**
  1. Navigate to Expense Summary → Monthly tab
- **Expected Result:** This month total = ₹17,000. Category breakdown shows: feed ₹10,000, labor ₹5,000, supplements ₹2,000. Weekly subtotals correct. No cross-month leakage.
- **Edge Case Notes:** Test at month boundary: expense logged at 11:59 PM on last day of month must appear in that month, not the next.
- **Severity if Failed:** S2

---

### TC-COST-003
- **Module:** Inventory Tracking
- **Priority:** P1
- **Feature:** Inventory auto-deduction after feed completion
- **Preconditions:** Inventory: 100 kg of "Higashimaru 35" feed. Pond completes feed round: 4.5 kg logged.
- **Steps:**
  1. Complete feed round (4.5 kg)
  2. Navigate to Inventory Dashboard
  3. Check "Higashimaru 35" stock level
- **Expected Result:** Stock reduced from 100 kg to 95.5 kg. `inventory_consumption` row inserted with `quantity_used=4.5, source=feed_round`. Auto-deduction is non-blocking (feed was allowed even before deduction confirmed).
- **Edge Case Notes:** If deduction fails silently (DB error), inventory shows wrong count. Verify the consumption record is created even when the main feed RPC succeeds.
- **Severity if Failed:** S3

---

### TC-COST-004
- **Module:** Inventory Tracking
- **Priority:** P2
- **Feature:** Low stock warning
- **Preconditions:** Inventory: 15 kg of feed (below 20 kg threshold).
- **Steps:**
  1. Navigate to Inventory Dashboard
- **Expected Result:** Low-stock warning indicator visible on the feed item row (red badge or warning icon). No push notification (app does not send notifications for this). Warning only visible in-app.
- **Edge Case Notes:** Threshold is 20 kg. 20 kg exactly should NOT trigger warning (threshold is "below 20", not "at or below 20"). Verify boundary.
- **Severity if Failed:** S3

---

### TC-COST-005
- **Module:** Expense / Profit
- **Priority:** P2
- **Feature:** Profit calculation
- **Preconditions:** PRO user. Crop cycle with: total harvest revenue ₹2,50,000, total expenses ₹1,80,000.
- **Steps:**
  1. Navigate to Profit Summary screen
- **Expected Result:** Profit = ₹2,50,000 - ₹1,80,000 = ₹70,000. Return on investment % shown correctly. Cost breakdown by category visible.
- **Edge Case Notes:** If expenses are scoped to a different farm_id or crop_id than the harvest, profit will be incorrect. Verify both are filtered by the same crop_id.
- **Severity if Failed:** S3

---

# SECTION 13 — SYNC & OFFLINE BEHAVIOR (TC-SYNC)

---

### TC-SYNC-001
- **Module:** Offline Feed Sync
- **Priority:** P0
- **Feature:** Feed log queued when offline
- **Preconditions:** Enable airplane mode on device. Navigate to pond Feed tab.
- **Steps:**
  1. Enable airplane mode
  2. Complete a feed round (Round 1, 4.5 kg)
  3. Observe immediate UI feedback
  4. Check SharedPreferences queue
- **Expected Result:** Feed round shows as "Completed" in UI immediately (optimistic update). `FeedSyncQueue` has 1 pending operation. Feed Sync warning bar MAY appear or be deferred. App does not crash or show error.
- **Edge Case Notes:** The offline queue must store: pond_id, doc, round, feed_amount, base_feed, operationId, created_at. All fields required for RPC replay.
- **Severity if Failed:** S1

---

### TC-SYNC-002
- **Module:** Offline Feed Sync
- **Priority:** P0
- **Feature:** Queued feed syncs on reconnect
- **Preconditions:** Offline feed round queued (from TC-SYNC-001).
- **Steps:**
  1. Disable airplane mode (reconnect to network)
  2. Wait for auto-sync trigger
  3. Check Supabase `feed_logs` table
- **Expected Result:** Within 30 seconds of reconnection, `processQueue()` triggers. RPC `complete_feed_round_with_log` called. `feed_logs` row inserted with correct data. Queue cleared. Warning bar (if shown) disappears.
- **Edge Case Notes:** App must NOT require manual restart to sync. Auto-sync on network reconnect is mandatory.
- **Severity if Failed:** S1

---

### TC-SYNC-003
- **Module:** Offline Feed Sync
- **Priority:** P0
- **Feature:** No duplicate on sync replay
- **Preconditions:** Feed round completed while offline and queued.
- **Steps:**
  1. Reconnect to network
  2. Let first sync attempt partially fail (simulate by briefly toggling network)
  3. Let second sync attempt succeed
- **Expected Result:** `feed_logs` has exactly ONE row for (pond_id, doc, round). operationId deduplication in RPC prevents double-insert. Second sync returns `operationDuplicate=true`.
- **Edge Case Notes:** This is the critical idempotency test for offline sync. Without it, a farmer who reconnects could have doubled feed counts, corrupting FCR.
- **Severity if Failed:** S1

---

### TC-SYNC-004
- **Module:** Offline Feed Sync
- **Priority:** P1
- **Feature:** Exponential backoff on repeated failure
- **Preconditions:** Network is intermittent (connected but server returning 500 errors). Feed round in queue.
- **Steps:**
  1. Observe sync attempt timing in logs
  2. Verify attempt 1, 2, 3, 4, 5 timings
- **Expected Result:** Retry attempts follow backoff schedule: ~5s, ~10s, ~20s, ~40s, ~80s (±20% jitter). Max 5 attempts. After 5 failures, op marked as `failed`. Warning bar shows permanent failure state.
- **Edge Case Notes:** Jitter (±20%) is important — prevents thundering herd if many devices reconnect simultaneously. Verify times are not exactly 5, 10, 20, 40, 80 (jitter should be visible).
- **Severity if Failed:** S2

---

### TC-SYNC-005
- **Module:** Offline Feed Sync
- **Priority:** P1
- **Feature:** Max retries — permanent failure handling
- **Preconditions:** Simulate 5 consecutive sync failures (server errors).
- **Steps:**
  1. Force 5 sync attempts to fail
  2. Observe app behavior after 5th failure
- **Expected Result:** Operation marked as `failed` (not deleted). Warning bar shows permanent failure. Farmer told to contact support or retry manually. Failed op retained in queue for audit. No further auto-retry.
- **Edge Case Notes:** The permanent failure case is where a farmer's feed log is genuinely lost from the backend. This is the worst-case scenario and must be clearly communicated.
- **Severity if Failed:** S2

---

### TC-SYNC-006
- **Module:** Offline Feed Sync
- **Priority:** P2
- **Feature:** App restart resumes queue processing
- **Preconditions:** Feed round queued while offline. App force-closed.
- **Steps:**
  1. Force-close app while offline with pending queue
  2. Reconnect to network
  3. Relaunch app
- **Expected Result:** On app start, `FeedSyncQueue.startupReplay()` is called. Pending operations replayed. `feed_logs` row inserted within 30 seconds of startup.
- **Edge Case Notes:** SharedPreferences queue must survive app force-close. Verify queue is not cleared on app restart.
- **Severity if Failed:** S1

---

### TC-SYNC-007
- **Module:** Offline Feed Sync
- **Priority:** P2
- **Feature:** 24-hour pruning of synced operations
- **Preconditions:** 10 feed operations synced successfully. Their `synced_at` timestamp is 25 hours ago.
- **Steps:**
  1. Trigger `processQueue()` (or wait for startup)
  2. Observe queue size
- **Expected Result:** 25-hour-old synced operations are pruned from SharedPreferences. Queue size reduced by 10. Storage freed.
- **Edge Case Notes:** Only synced ops are pruned. Failed ops are NEVER auto-pruned (retained for inspection). Verify this distinction.
- **Severity if Failed:** S3

---

# SECTION 14 — MULTI-POND LOGIC (TC-MULTI)

---

### TC-MULTI-001
- **Module:** Multi-Pond
- **Priority:** P1
- **Feature:** Feed recommendations independent per pond
- **Preconditions:** Two ponds: Pond A (seed=100K, DOC=20), Pond B (seed=200K, DOC=45, PRO).
- **Steps:**
  1. Navigate to Pond A → Feed tab → note recommendation
  2. Navigate to Pond B → Feed tab → note recommendation
- **Expected Result:** Pond A recommendation uses its own seed count and DOC (blind mode). Pond B recommendation uses its own seed count, DOC, and smart corrections. Neither affects the other. Recommendations are different in amount.
- **Edge Case Notes:** Most likely failure: provider family not keyed on pondId correctly, causing Pond B to show Pond A's data.
- **Severity if Failed:** S1

---

### TC-MULTI-002
- **Module:** Multi-Pond
- **Priority:** P1
- **Feature:** Completing feed on one pond does not affect another
- **Preconditions:** Two ponds on same farm. Pond A DOC=15 with pending rounds. Pond B DOC=30 with pending rounds.
- **Steps:**
  1. Complete Round 1 on Pond A
  2. Navigate to Pond B → Feed tab
- **Expected Result:** Pond B rounds still show as "Planned" (not completed). Pond A completion has no effect on Pond B's state.
- **Edge Case Notes:** `feedHistoryProvider` is a family provider keyed by pondId. Completing feed must only invalidate the correct family instance.
- **Severity if Failed:** S1

---

### TC-MULTI-003
- **Module:** Multi-Pond
- **Priority:** P2
- **Feature:** HomeScreen shows all ponds correctly
- **Preconditions:** Farm with 3 ponds: different DOC, different ABW, different statuses (one with completed harvest, one active, one with water warning).
- **Steps:**
  1. Navigate to HomeScreen
  2. Observe all 3 pond cards
- **Expected Result:** All 3 pond cards visible. Each shows correct pond-specific data. Scrolling works if cards exceed screen height. Status indicators correct (water warning on one, harvest complete on another).
- **Edge Case Notes:** Race condition: if all 3 providers load async, cards must not flash incorrect data while loading. Show loading state per card, not one spinner for all.
- **Severity if Failed:** S2

---

### TC-MULTI-004
- **Module:** Multi-Pond
- **Priority:** P2
- **Feature:** Tray log scoped to correct pond
- **Preconditions:** Two ponds. Log tray data for Pond A (all Empty). Navigate to Pond B.
- **Steps:**
  1. Log tray for Pond A (all Empty, 4 trays)
  2. Navigate to Pond B → Trays tab
- **Expected Result:** Pond B shows no tray data today (or its own separate tray history). Pond A's tray data does not appear in Pond B. `tray_statuses` query must filter by correct pond_id.
- **Edge Case Notes:** Data cross-contamination between ponds is a critical bug — it could lead to wrong feed decisions for Pond B.
- **Severity if Failed:** S1

---

### TC-MULTI-005
- **Module:** Multi-Pond
- **Priority:** P2
- **Feature:** Offline queue handles multiple ponds independently
- **Preconditions:** Airplane mode ON. Log one feed round for Pond A and one for Pond B (both offline).
- **Steps:**
  1. Complete Round 1 for Pond A (offline)
  2. Complete Round 1 for Pond B (offline)
  3. Reconnect
  4. Observe sync
- **Expected Result:** Both operations queued separately. Both sync independently. `feed_logs` has one row for Pond A/DOC/Round1 and one for Pond B/DOC/Round1. Queue clears for both after success.
- **Edge Case Notes:** Queue must handle multiple pond operations without one blocking the other (independent retry per operation).
- **Severity if Failed:** S2

---

# SECTION 15 — ROLE-BASED ACCESS (TC-ROLE)

---

### TC-ROLE-001
- **Module:** Team Management / Role Access
- **Priority:** P1
- **Feature:** Add farm member (PRO feature)
- **Preconditions:** PRO user. Farm exists. Navigate to Farm Settings.
- **Steps:**
  1. Tap "Add Member"
  2. Enter email: `worker@farmtest.com`
  3. Select role: "Worker"
  4. Submit
- **Expected Result:** `farm_members` row inserted with farm_id, user_id (of worker), role=worker. Invitation email sent (if email-invite flow). Worker appears in members list.
- **Edge Case Notes:** Adding the same email twice should show "Already a member" error, not duplicate DB entry.
- **Severity if Failed:** S3

---

### TC-ROLE-002
- **Module:** Team Management / Role Access
- **Priority:** P1
- **Feature:** Add member blocked for FREE user
- **Preconditions:** FREE user. Navigate to Farm Settings → Team Members.
- **Steps:**
  1. Tap "Add Member"
- **Expected Result:** `role_limit_bottom_sheet` appears before form is shown. Cannot add team members without upgrading. Upgrade CTA visible.
- **Edge Case Notes:** FREE limit is enforced by `FarmMemberService` (PRO gate). Client-side check is a convenience; server-side RLS is the true enforcement.
- **Severity if Failed:** S2

---

### TC-ROLE-003
- **Module:** Role Access
- **Priority:** P2
- **Feature:** Worker role — limited view
- **Preconditions:** Worker account added to farm. Log in as worker.
- **Steps:**
  1. Log in as worker role
  2. Navigate through app
- **Expected Result:** Worker can view pond data, log feed rounds, log tray status. Worker CANNOT: delete pond, delete farm, manage billing, view profit screen, add other members. (Exact permissions per product spec.)
- **Edge Case Notes:** Role-based restrictions must be enforced server-side (RLS policies), not just client-side (hiding buttons). Test by attempting direct API calls as worker.
- **Severity if Failed:** S2

---

### TC-ROLE-004
- **Module:** Role Access
- **Priority:** P2
- **Feature:** Farm owner retains all permissions
- **Preconditions:** PRO farm owner. Farm has 2 members.
- **Steps:**
  1. Log in as farm owner
  2. Attempt all admin actions: delete pond, view profit, manage members, change subscription
- **Expected Result:** All actions succeed. Owner has full access to all features gated by their subscription tier.
- **Edge Case Notes:** Owner's `user_id` in `farms.user_id` is the authority. `farm_members` entry for owner (if any) must not accidentally downgrade owner to a restricted role.
- **Severity if Failed:** S2

---

# SECTION 16 — SUBSCRIPTION / PAYWALL (TC-SUB)

---

### TC-SUB-001
- **Module:** Subscription / Paywall
- **Priority:** P0
- **Feature:** PRO subscription activation via payment
- **Preconditions:** FREE user. Navigate to Upgrade screen.
- **Steps:**
  1. Select "PRO" plan
  2. Tap "Upgrade Now"
  3. Complete Razorpay payment with test card
  4. Wait for verification
- **Expected Result:** 
  - Razorpay order created via edge function
  - Payment UI shows
  - After successful payment, `verify-razorpay-payment` edge function confirms HMAC
  - `subscriptions` table row inserted with status=active, plan=pro, expires_at set
  - `get_active_entitlement` RPC returns PRO
  - App navigates to HomeScreen showing PRO features unlocked
  - Smart feed corrections now available
- **Edge Case Notes:** Full payment flow requires Razorpay test credentials. Test with test card numbers from Razorpay documentation.
- **Severity if Failed:** S1

---

### TC-SUB-002
- **Module:** Subscription / Paywall
- **Priority:** P0
- **Feature:** Server-authoritative entitlement check
- **Preconditions:** Attempt to manually set subscription flag in SharedPreferences or local state.
- **Steps:**
  1. Manually modify local subscription state (if accessible via debug tools)
  2. Navigate to smart feed features
- **Expected Result:** Even if local state claims PRO, the app must verify via `get_active_entitlement` RPC on startup. If server returns FREE, app shows FREE features only. Local state cannot override server entitlement.
- **Edge Case Notes:** `SubscriptionGate` uses `hydrationFuture` to await server confirmation before any PRO gate is evaluated. Before hydration, all PRO gates default to FREE (safe side).
- **Severity if Failed:** S1

---

### TC-SUB-003
- **Module:** Subscription / Paywall
- **Priority:** P0
- **Feature:** Payment failure handling
- **Preconditions:** User on Upgrade screen. Use Razorpay test failure card.
- **Steps:**
  1. Initiate payment
  2. Use test card configured to fail
- **Expected Result:** Razorpay shows payment failure. App shows user-friendly error ("Payment failed. Please try again."). User remains on FREE plan. No partial subscription created. `pending_payments` table may have a row with status=failed.
- **Edge Case Notes:** Payment cancel (user closes Razorpay sheet) must also be handled gracefully — not treated as success, not treated as error crash.
- **Severity if Failed:** S1

---

### TC-SUB-004
- **Module:** Subscription / Paywall
- **Priority:** P1
- **Feature:** Subscription expiry
- **Preconditions:** PRO subscription expires today (simulate by setting `expires_at` = yesterday in DB).
- **Steps:**
  1. Launch app with expired subscription
  2. Navigate to smart feed features
- **Expected Result:** `get_active_entitlement` returns null (expired). App downgrades to FREE. Smart feed corrections no longer applied. Tray corrections show MAINTAIN. User sees upgrade prompt with "Your PRO subscription has expired."
- **Edge Case Notes:** Downgrade must happen gracefully. Existing feed_logs are preserved. Only future recommendations are affected.
- **Severity if Failed:** S1

---

### TC-SUB-005
- **Module:** Subscription / Paywall
- **Priority:** P1
- **Feature:** Boot race — hydration protection
- **Preconditions:** PRO user. App launching with slow network (simulate 5-second latency on entitlement API).
- **Steps:**
  1. Launch app with network delay
  2. Quickly navigate to Feed tab before hydration completes
  3. Observe feed corrections
- **Expected Result:** Before `hydrationFuture` resolves, all PRO features show FREE behavior (no corrections). After hydration completes (PRO confirmed), corrections apply. No flash of incorrect PRO state during loading.
- **Edge Case Notes:** This prevents a window where a FREE user sees PRO features briefly. Fail-safe to FREE is correct behavior.
- **Severity if Failed:** S2

---

### TC-SUB-006
- **Module:** Subscription / Paywall
- **Priority:** P2
- **Feature:** Upgrade screen — plan comparison
- **Preconditions:** FREE user. Navigate to Upgrade screen.
- **Steps:**
  1. Open Upgrade screen
  2. Review features listed for FREE vs PRO
  3. Toggle billing cycle (per crop vs yearly)
- **Expected Result:** Feature comparison table shows accurate feature list. Price updates correctly when billing cycle toggled. "Most Popular" or recommended plan highlighted. CTA button clearly labeled. Legal fine print visible (subscription terms).
- **Edge Case Notes:** Pricing must match actual Razorpay plan prices (not hardcoded test values in production).
- **Severity if Failed:** S3

---

# SECTION 17 — DATA PERSISTENCE (TC-DATA)

---

### TC-DATA-001
- **Module:** Data Persistence
- **Priority:** P0
- **Feature:** Feed logs persist across sessions
- **Preconditions:** Complete 3 feed rounds. Force-close app.
- **Steps:**
  1. Complete 3 feed rounds (Round 1, 2, 3)
  2. Force-close app
  3. Relaunch app
  4. Navigate to Feed History
- **Expected Result:** All 3 completed rounds shown in history. `feed_logs` rows remain in Supabase. DOC cumulative total reflects logged amounts. No data loss.
- **Edge Case Notes:** This verifies Supabase is the source of truth, not local cache only.
- **Severity if Failed:** S1

---

### TC-DATA-002
- **Module:** Data Persistence
- **Priority:** P1
- **Feature:** Sampling data persists and drives next session's ABW
- **Preconditions:** Log a sample: ABW=12g. Force-close app.
- **Steps:**
  1. Relaunch app
  2. Navigate to Growth tab
- **Expected Result:** ABW=12g shown. Sample timestamp preserved. Engine uses 12g for next feed recommendation without re-entering data.
- **Edge Case Notes:** Riverpod providers must reload from Supabase on app restart, not serve stale in-memory cache from previous session.
- **Severity if Failed:** S1

---

### TC-DATA-003
- **Module:** Data Persistence
- **Priority:** P1
- **Feature:** Offline queue survives app kill
- **Preconditions:** Feed round queued offline. Force-close app without reconnecting.
- **Steps:**
  1. Queue feed round while offline
  2. Force-close app
  3. Keep device offline
  4. Relaunch app
  5. Check queue
- **Expected Result:** Queue still contains the pending operation. SharedPreferences is persistent across app kills. When network reconnects, sync proceeds as normal.
- **Edge Case Notes:** SharedPreferences write must be synchronous/awaited before UI shows "queued." Race condition: if app is killed before SharedPreferences.setString completes, the op is lost — verify write is awaited.
- **Severity if Failed:** S1

---

### TC-DATA-004
- **Module:** Data Persistence
- **Priority:** P2
- **Feature:** Expense records scoped to crop cycle
- **Preconditions:** Expense logged in Cycle 1. New cycle started (Cycle 2 created).
- **Steps:**
  1. Navigate to Expense Summary in Cycle 2
- **Expected Result:** Cycle 2 expense summary shows ₹0 (or empty state). Cycle 1 expenses are NOT shown in Cycle 2 view. They are scoped by crop_id.
- **Edge Case Notes:** If expense_summary_screen passes crop_id as a route argument, verify the correct crop_id is passed when navigating from Cycle 2 pond context.
- **Severity if Failed:** S2

---

# SECTION 18 — API FAILURE HANDLING (TC-API)

---

### TC-API-001
- **Module:** API Failure Handling
- **Priority:** P0
- **Feature:** Feed RPC failure → automatic queue
- **Preconditions:** Network connected but Supabase returning 503 for RPC calls.
- **Steps:**
  1. Complete feed round while server is returning errors
  2. Observe behavior
- **Expected Result:** `FeedService` catches the DB failure. Feed operation queued to `FeedSyncQueue`. UI shows optimistic "Completed" state. No error dialog or crash shown to user. Sync will retry when server recovers.
- **Edge Case Notes:** The queue path must trigger even for non-network errors (e.g., 503 Service Unavailable, not just timeout/no-connection).
- **Severity if Failed:** S1

---

### TC-API-002
- **Module:** API Failure Handling
- **Priority:** P1
- **Feature:** Pond creation RPC failure — rollback
- **Preconditions:** Server returns 500 on `create_pond_with_feed_plan` RPC.
- **Steps:**
  1. Fill pond creation form
  2. Submit while server returns 500
- **Expected Result:** Error shown to user: "Failed to create pond. Please try again." Form remains filled. No partial pond created in DB (the RPC is atomic — either both pond + feed_rounds are created, or neither). Retry works after server recovers.
- **Edge Case Notes:** operationId is preserved on the screen — a retry after failure uses the same operationId, preventing duplicate creation if the first call actually succeeded but the response was lost.
- **Severity if Failed:** S1

---

### TC-API-003
- **Module:** API Failure Handling
- **Priority:** P1
- **Feature:** Subscription check failure → default to FREE
- **Preconditions:** `get_active_entitlement` RPC returns an error (network failure, server error).
- **Steps:**
  1. Launch app with broken entitlement endpoint
  2. Navigate to smart feed features
- **Expected Result:** App defaults to FREE behavior. No PRO features unlocked. No crash. User can still use all FREE features normally. Subscription state shows "Unable to verify — working in offline mode."
- **Edge Case Notes:** This is a critical safety default. Failing open (showing PRO features on entitlement failure) would be a security/revenue issue.
- **Severity if Failed:** S1

---

### TC-API-004
- **Module:** API Failure Handling
- **Priority:** P1
- **Feature:** Farm list fetch failure — graceful empty state
- **Preconditions:** Supabase `farms` table query returns error after login.
- **Steps:**
  1. Log in successfully
  2. Observe HomeScreen while farm fetch fails
- **Expected Result:** Loading state shown. After error, error state shown with retry button: "Failed to load farms. Tap to retry." App does not crash. Auth session is preserved. Retry button triggers re-fetch.
- **Edge Case Notes:** `farmProvider` must use `AsyncValue.error()` state with a retry mechanism. Blank white screen is not acceptable.
- **Severity if Failed:** S2

---

### TC-API-005
- **Module:** API Failure Handling
- **Priority:** P2
- **Feature:** Sampling save failure
- **Preconditions:** Sampling form filled. Network drops just as submit is tapped.
- **Steps:**
  1. Fill sampling form: weight=50g, pieces=10
  2. Tap Submit while network drops
- **Expected Result:** Error shown: "Failed to save sample. Please check your connection." Form values preserved (not cleared). User can retry. Unlike feed rounds, sampling does NOT have an offline queue — must be explicit about this to user.
- **Edge Case Notes:** Sampling failure is less critical than feed failure (no financial impact) but still should not silently fail or corrupt data.
- **Severity if Failed:** S3

---

### TC-API-006
- **Module:** API Failure Handling
- **Priority:** P2
- **Feature:** Payment edge function failure
- **Preconditions:** `create-razorpay-order` edge function returns 500.
- **Steps:**
  1. Tap Upgrade
  2. Observe behavior when order creation fails
- **Expected Result:** Error shown: "Payment could not be initiated. Please try again." Razorpay checkout UI does NOT open. User remains on FREE plan. No pending_payments row with invalid order_id created.
- **Edge Case Notes:** If the error shows only after Razorpay checkout opens (order was created, verify failed), the pending payment must be saved to `pending_payments` for recovery.
- **Severity if Failed:** S2

---

# SECTION 19 — NAVIGATION & STATE CONSISTENCY (TC-NAV)

---

### TC-NAV-001
- **Module:** Navigation
- **Priority:** P1
- **Feature:** Bottom nav state preservation
- **Preconditions:** On Pond Dashboard tab, scrolled to bottom of Feed tab.
- **Steps:**
  1. From Feed tab of Pond Dashboard, tap bottom nav "Home"
  2. Tap bottom nav "Ponds" to return
- **Expected Result:** Pond Dashboard is restored to the same state (same tab, same scroll position). Not reset to Overview tab. Bottom nav does not reinitialize the route stack.
- **Edge Case Notes:** Flutter Navigator 2.0 or GoRouter route handling determines if state is preserved. Riverpod state must persist across navigation.
- **Severity if Failed:** S3

---

### TC-NAV-002
- **Module:** Navigation
- **Priority:** P1
- **Feature:** Deep navigation and back stack
- **Preconditions:** On HomeScreen.
- **Steps:**
  1. Tap Pond A card → Pond Dashboard
  2. Tap Feed tab → Feed Schedule screen
  3. Tap Feed History → Feed History screen
  4. Press device Back button 3 times
- **Expected Result:** Back navigates: History → Schedule → Dashboard → Home. No duplicate screens. No crash on back-press. Back press from HomeScreen should show exit confirmation or minimize app (not crash).
- **Edge Case Notes:** Test rapid back-presses (3 quick taps). Should not cause navigation stack exception.
- **Severity if Failed:** S2

---

### TC-NAV-003
- **Module:** State Consistency
- **Priority:** P1
- **Feature:** Pond data refreshes after edit
- **Preconditions:** Pond with seed count = 150,000 visible on Dashboard.
- **Steps:**
  1. Navigate to Edit Pond
  2. Change seed count to 120,000
  3. Save
  4. Return to Pond Dashboard
- **Expected Result:** Pond Dashboard immediately reflects new seed count (120,000). Feed recommendation recalculates. DOC and ABW unchanged. No stale data shown.
- **Edge Case Notes:** `pondProvider` or `farmProvider` must be invalidated after edit. If not, stale data shows until next app restart.
- **Severity if Failed:** S2

---

### TC-NAV-004
- **Module:** Navigation
- **Priority:** P2
- **Feature:** Tray log wizard — exit mid-flow
- **Preconditions:** Tray log wizard open on Tray 2 of 4.
- **Steps:**
  1. Open tray wizard
  2. Log Tray 1: Empty
  3. On Tray 2: press device Back or tap X to close
- **Expected Result:** Confirmation dialog: "Tray log incomplete. Discard progress?" If user confirms: wizard closes, no tray data saved. If user cancels: wizard remains on Tray 2.
- **Edge Case Notes:** Partial tray submission (only 1 of 4 trays) must NOT be saved. All-or-nothing submission.
- **Severity if Failed:** S2

---

### TC-NAV-005
- **Module:** Navigation / Session
- **Priority:** P2
- **Feature:** Logout clears state
- **Preconditions:** Logged in as user A with farms and ponds loaded.
- **Steps:**
  1. Navigate to Profile
  2. Tap "Logout"
  3. Log in as user B
- **Expected Result:** All of user A's data (farms, ponds, feed history) is NOT visible after logging in as user B. Riverpod state fully reset. SharedPreferences auth token cleared. Feed sync queue cleared (or re-attributed).
- **Edge Case Notes:** Data isolation between users is a privacy and security requirement. State leakage between users is a critical bug.
- **Severity if Failed:** S1

---

# SECTION 20 — CRASH-RISK & PERFORMANCE (TC-PERF)

---

### TC-PERF-001
- **Module:** Performance
- **Priority:** P1
- **Feature:** App launch time
- **Preconditions:** User already logged in (no session check delay). Farm with 3 ponds.
- **Steps:**
  1. Force-close app
  2. Launch app
  3. Measure time from tap to HomeScreen visible with data
- **Expected Result:** App launches to usable HomeScreen within 3 seconds on mid-range Android device. Splash screen visible while data loads. No > 1 second white/blank screen.
- **Edge Case Notes:** Cold launch vs warm launch. Cold launch (OS clears memory) should be < 4 seconds. Warm launch < 2 seconds.
- **Severity if Failed:** S3

---

### TC-PERF-002
- **Module:** Performance / Crash Risk
- **Priority:** P1
- **Feature:** Feed engine on very large seed count
- **Preconditions:** Pond: Seed Count = 1,000,000 (maximum). DOC=60. All smart corrections active.
- **Steps:**
  1. Navigate to Feed tab
  2. Observe calculation and rendering time
- **Expected Result:** Feed recommendation calculated within 500ms. No ANR (App Not Responding) on Android. No visible jank. Result is clamped to 50 kg maximum.
- **Edge Case Notes:** The feed engine is a pure Dart calculation (no async). It must not block the UI thread. If computation takes > 16ms, run in isolate.
- **Severity if Failed:** S2

---

### TC-PERF-003
- **Module:** Performance / Crash Risk
- **Priority:** P2
- **Feature:** Feed history with 180 days of data
- **Preconditions:** Pond with DOC=180. All 4 rounds logged every day = 720 feed_logs rows.
- **Steps:**
  1. Navigate to Feed History screen
  2. Scroll through entire history
- **Expected Result:** Screen loads within 2 seconds. Scrolling is smooth (60fps). No memory crash from loading 720+ rows. Pagination or virtual list used if necessary.
- **Edge Case Notes:** Loading all 720 rows into memory at once could cause OOM on low-RAM devices. Verify lazy loading or limit query with pagination.
- **Severity if Failed:** S3

---

### TC-PERF-004
- **Module:** Crash Risk
- **Priority:** P0
- **Feature:** No crash on empty Riverpod providers
- **Preconditions:** New user, no farm, no pond. Navigate to every screen.
- **Steps:**
  1. Navigate to HomeScreen (empty)
  2. Tap all quick action buttons
  3. Navigate to Ponds tab (empty)
  4. Navigate to Profile tab
- **Expected Result:** No crash on any screen. All `AsyncValue.loading()` and `AsyncValue.data([])` states handled. No null pointer exceptions from accessing `farms[0]` when list is empty.
- **Edge Case Notes:** This is the "fresh user" journey. Most crashes in production come from first-time users with empty state.
- **Severity if Failed:** S1

---

### TC-PERF-005
- **Module:** Crash Risk
- **Priority:** P1
- **Feature:** Rapid screen switching doesn't cause provider leak
- **Preconditions:** Pond with active providers.
- **Steps:**
  1. Rapidly switch between Home, Ponds, Profile tabs 20 times in 10 seconds
  2. Navigate into and out of Pond Dashboard 10 times
- **Expected Result:** No memory leak detected (memory usage stable after 5 minutes of rapid navigation). No "setState called on disposed widget" errors in console. Riverpod auto-disposes family providers correctly.
- **Edge Case Notes:** Family providers (by pondId) must be disposed when their consumer widget unmounts. Memory leak here could cause slow degradation over long sessions.
- **Severity if Failed:** S2

---

### TC-PERF-006
- **Module:** Crash Risk
- **Priority:** P1
- **Feature:** NaN/Infinity in feed engine does not crash app
- **Preconditions:** Manually inject NaN into `feedInputValidator` input (via debug/test mode).
- **Steps:**
  1. Pass NaN as DO value to feed engine
  2. Observe behavior
- **Expected Result:** `FeedInputValidator` catches NaN. Logs error. Engine uses safe default (DO=6.0) instead of NaN. Feed recommendation returned as valid number. No `double.nan.toString()` displayed in UI. No crash.
- **Edge Case Notes:** NaN and Infinity must be intercepted at the validator level, not the engine level. If they reach the engine, the ±30% clamp on NaN = NaN (not 0 or max).
- **Severity if Failed:** S1

---

### TC-PERF-007
- **Module:** Crash Risk / Performance
- **Priority:** P2
- **Feature:** Supabase query timeout handling
- **Preconditions:** Simulate very slow Supabase response (> 30 seconds).
- **Steps:**
  1. Open app with artificially delayed DB responses
  2. Navigate to HomeScreen and wait
- **Expected Result:** `NetworkTimeoutService` triggers timeout after configured threshold. Error state shown with retry option. App does not appear frozen indefinitely. User can tap retry or navigate away.
- **Edge Case Notes:** Without a timeout, users on poor networks could see a spinner indefinitely with no way to recover except force-closing the app.
- **Severity if Failed:** S2

---

# SECTION 21 — REGRESSION SCENARIOS (TC-REG)

---

### TC-REG-001
- **Module:** Regression
- **Priority:** P0
- **Feature:** Feed brand selection persists after pond creation
- **Preconditions:** Feed brands available in DB. Regression: previously, feed_brand_id column was TEXT instead of UUID, causing silent failures.
- **Steps:**
  1. Create pond with Feed Brand = "Higashimaru 35" selected
  2. Save pond
  3. Navigate to pond dashboard
- **Expected Result:** Pond dashboard shows "Higashimaru 35" as the active feed brand. `ponds.feed_brand_id` column stores the UUID of the brand. No silent null saved.
- **Edge Case Notes:** This regressed previously (see commit fb31b3e). Verify column is UUID type and join with feed_brands table works.
- **Severity if Failed:** S1

---

### TC-REG-002
- **Module:** Regression
- **Priority:** P0
- **Feature:** Feed round cards show immediately after pond creation
- **Preconditions:** Regression: previously, pond_dashboard_screen showed 0 feed rounds immediately after creation until a full app restart.
- **Steps:**
  1. Create new pond (with all fields filled)
  2. Immediately navigate to Pond Dashboard → Feed tab (without restarting app)
- **Expected Result:** Feed schedule (30 rounds for DOC 1–30) visible immediately. No "no feed rounds" empty state shown. No restart required.
- **Edge Case Notes:** This was a provider invalidation bug (see commit 8c4fe6c). After pond creation, `feedScheduleProvider` must be invalidated.
- **Severity if Failed:** S1

---

### TC-REG-003
- **Module:** Regression
- **Priority:** P0
- **Feature:** Seed count max validation (500K, not 10M)
- **Preconditions:** Regression: previously max was 10M — far too high for AP coastal ponds, allowing phone-keypad typos (e.g., 1,500,000 instead of 150,000).
- **Steps:**
  1. Enter seed count = 600,000
  2. Attempt to submit Add Pond form
- **Expected Result:** Validation error shown for > 500,000. Form not submitted. User corrects to ≤ 500,000.
- **Edge Case Notes:** BUG-12 fix. Max was tightened from 10M to 500K. Ensure the validator in `FeedInputValidator` and the form field both enforce this.
- **Severity if Failed:** S2

---

### TC-REG-004
- **Module:** Regression
- **Priority:** P1
- **Feature:** Feed history shows after feed round completion (no page refresh required)
- **Preconditions:** Pond with no feed logs today.
- **Steps:**
  1. Complete feed round (Round 1)
  2. Immediately navigate to Feed History tab/screen (no restart)
- **Expected Result:** Round 1 entry visible in history immediately. Provider invalidated after completion. No manual refresh required.
- **Edge Case Notes:** BUG #5 fix (see commit context: invalidate controller cache post-completion). `feedHistoryProvider` must be invalidated on round completion.
- **Severity if Failed:** S2

---

### TC-REG-005
- **Module:** Regression
- **Priority:** P1
- **Feature:** Tray logging triggers feed pipeline (TEMPORARY LOG verification)
- **Preconditions:** PRO user. DOC>30. Log tray status.
- **Steps:**
  1. Open tray log wizard
  2. Submit tray statuses (all Empty)
  3. Navigate to Feed tab
- **Expected Result:** Feed recommendation updated to reflect tray signal (+5% INCREASE). AppLogger debug line visible in dev: `"TRAY LOGGED: Pond=... Round=... Status=... Leftover=..."`. Tray signal flowing through to feed engine.
- **Edge Case Notes:** TASK 2 temporary log confirms the trigger chain works. This log should be removed before production (P3 cleanup), but the functionality must remain.
- **Severity if Failed:** S2

---

# SECTION 22 — INTEGRATION TEST SCENARIOS (TC-INT)

---

### TC-INT-001
- **Module:** Integration
- **Priority:** P0
- **Feature:** Full daily workflow — one complete shrimp farming day
- **Preconditions:** PRO user. Pond at DOC=45. Fresh water log (2 hours ago, DO=7.0, temp=29°C). ABW sample (3 days old, ABW=11g). 3 tray logs (all Medium → -0.5 avg score → MAINTAIN).
- **Steps:**
  1. Launch app → HomeScreen
  2. Navigate to Pond Dashboard
  3. Overview: verify DOC=45, ABW=11g, FCR reasonable
  4. Feed tab: read recommendation for today
  5. Complete Round 1 (6:00 AM feed)
  6. Complete Round 2 (11:00 AM feed)
  7. Log tray status (mid-day check)
  8. Complete Round 3 (4:00 PM feed)
  9. Complete Round 4 (9:00 PM feed)
  10. View Feed History: confirm all 4 rounds logged
- **Expected Result:** 
  - DOC=45 shown
  - ABW=11g (sampled, 3 days old → still fresh < 7 days)
  - DO=7.0 → env factor 1.0
  - Tray = MAINTAIN (avg -0.5 → within ±0.6 → no adjustment)
  - Feed recommendation = base × 1.0 (no adjustments) at DOC 45 smart mode
  - All 4 rounds logged; daily total correct
  - Feed history shows 4 rows for today
- **Edge Case Notes:** This is the golden path for a PRO farmer mid-cycle. All 4 engine stages should produce clean output.
- **Severity if Failed:** S1

---

### TC-INT-002
- **Module:** Integration
- **Priority:** P0
- **Feature:** Full cycle — stocking to harvest
- **Preconditions:** New pond created today.
- **Steps:**
  1. Create pond (DOC=1, all details set)
  2. Verify feed schedule created (DOC 1–30)
  3. Fast-forward simulation: advance stocking_date by 90 days (via DB edit)
  4. Verify DOC=91 shown
  5. Log sampling (ABW=20g for DOC 91)
  6. Navigate to Harvest tab → Log Final Harvest (5,000 kg, ₹300/kg)
  7. Tap "Start New Cycle" prompt
  8. Enter new stocking details
  9. Verify DOC resets to 1
  10. Verify new feed schedule generated
- **Expected Result:** Complete lifecycle works end-to-end. Harvest saved (₹15,00,000 revenue). New cycle starts cleanly with DOC=1. Old data preserved in DB but not shown in new cycle context.
- **Edge Case Notes:** This is the full crop cycle integration test. Most real bugs occur at cycle transitions.
- **Severity if Failed:** S1

---

### TC-INT-003
- **Module:** Integration
- **Priority:** P1
- **Feature:** Offline → online sync with multiple ponds
- **Preconditions:** PRO user. 3 ponds. All at DOC=30 (final blind day). Enable airplane mode.
- **Steps:**
  1. Offline: Complete Round 1 for Pond A
  2. Offline: Complete Round 2 for Pond B
  3. Offline: Log tray status for Pond C
  4. Reconnect to network
  5. Wait for sync
  6. Verify Supabase data
- **Expected Result:** All 3 operations sync successfully. `feed_logs` has correct rows for Pond A and Pond B. `tray_statuses` has row for Pond C. No duplicates, no cross-pond contamination. 3 operations cleared from queue.
- **Edge Case Notes:** Queue processes operations independently, not as a batch. Order of sync (A before B before C) should not affect correctness.
- **Severity if Failed:** S1

---

### TC-INT-004
- **Module:** Integration
- **Priority:** P1
- **Feature:** Supplement schedule drives daily operation card
- **Preconditions:** Active supplement schedule: "Probiotics" to be applied at Round 2 every day. Currently DOC=25.
- **Steps:**
  1. Navigate to Pond Dashboard → Supplements tab
  2. Verify "Probiotics" shows as Active
  3. Navigate to Feed tab → Round 2
- **Expected Result:** Round 2 shows a supplement chip/badge indicating "Add Probiotics (feed mix)." Supplement is integrated into the feed round display. Applying Round 2 marks the supplement as applied for this DOC.
- **Edge Case Notes:** Supplement integration into feed rounds is the "operational" part of supplement scheduling. If this is not wired up, supplements become a planning tool with no operational impact.
- **Severity if Failed:** S2

---

### TC-INT-005
- **Module:** Integration
- **Priority:** P1
- **Feature:** Expense + harvest = profit calculation
- **Preconditions:** PRO user. Crop cycle with: Expenses (feed ₹80,000, labor ₹20,000, misc ₹5,000). Harvest: 3,000 kg × ₹200/kg = ₹6,00,000.
- **Steps:**
  1. Navigate to Profit Summary screen
  2. Verify profit calculation
- **Expected Result:** 
  - Total revenue = ₹6,00,000
  - Total expenses = ₹1,05,000
  - Profit = ₹4,95,000
  - Cost per kg = ₹1,05,000 / 3,000 = ₹35/kg
  - Margin % = (4,95,000 / 6,00,000) × 100 = 82.5%
  All figures match expected calculation. No rounding errors.
- **Edge Case Notes:** Verify expenses and harvest are filtered to the same crop_id. Cross-cycle contamination would inflate or deflate profit.
- **Severity if Failed:** S2

---

*End of QA Test Suite v1.0 — 125 test cases across 22 sections.*

---

## Test Execution Notes

**Test Data Setup:**
- Use dedicated Supabase test project (not production)
- Create test user accounts: `qa_free@test.com` (FREE), `qa_pro@test.com` (PRO), `qa_worker@test.com` (Worker role)
- Use Razorpay test mode for all payment flows
- For DB-state-dependent tests, use Supabase SQL editor to preset data

**Devices to Cover:**
- Android mid-range (4GB RAM, Android 11)
- Android budget (2GB RAM, Android 10)
- iOS (iPhone 12 or equivalent)

**Test Execution Order:**
1. Run TC-AUTH smoke path first (login must work before anything else)
2. Run TC-POND-001 next (pond creation unlocks all other test areas)
3. Run P0 tests before P1, P1 before P2
4. Run TC-INT tests last (they depend on everything else working)

**Known Skip Conditions:**
- TC-PERF-002 (feed engine timing): requires profiling tools, not suitable for manual UAT
- TC-SMART-007 (kill switch): requires Supabase admin access
- TC-SUB-001 (payment flow): requires Razorpay test credentials
