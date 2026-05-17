# Aqua Rythu — Enterprise QA Execution Suite

> **Product:** Aqua Rythu v1.0.0+1 | **Date:** 2026-05-17
> **Platform:** Flutter (Android + iOS) | **Backend:** Supabase
> **Total Suite Cases:** 130 across 6 suites
> **Reference:** Full test procedures in `QA_TEST_CASES.md`

---

## Suite Index

| Suite | ID Prefix | Case Count | Run Frequency | Target Duration |
|---|---|---|---|---|
| Smoke | SM | 15 | Every build | ~25 min |
| Regression | RG | 35 | Every merge to main | ~2.5 hrs |
| Critical Path | CP | 25 | Pre-release only | ~2 hrs |
| Offline | OFF | 15 | Every merge + pre-release | ~1.5 hrs |
| Production Risk | PR | 20 | Pre-release only | ~2 hrs |
| UAT | UAT | 20 | Before 20-farmer rollout | ~3 hrs |

---

## Environment Tags

| Tag | Description |
|---|---|
| `staging` | Supabase staging project; test Razorpay mode |
| `prod-mirror` | Production schema; prod-like data volume |
| `device-android` | Mid-range Android (4GB RAM, Android 11) |
| `device-ios` | iOS 15+ (iPhone 12 equivalent) |
| `device-budget` | Budget Android (2GB RAM, Android 10) |
| `offline-sim` | Airplane mode or network throttled to 0 |

---

## Column Definitions

| Column | Values |
|---|---|
| Status | `—` (not run) · `Pass` · `Fail` · `Blocked` · `Skip` · `In Progress` |
| Retest Status | `—` · `Pass` · `Fail` · `Pending` · `N/A` |
| Priority | `P0` Critical · `P1` High · `P2` Medium |
| Severity | `S1` Blocker · `S2` Critical · `S3` Major · `S4` Minor |
| Environment | staging · prod-mirror · device-android · device-ios · device-budget |

---

---

# SUITE 1 — SMOKE SUITE

> **Purpose:** Verify the app launches, the core daily farming workflow completes end-to-end, and no P0 regression is present.
> **Run:** Every new build deployed to staging.
> **Pass Criteria:** 15/15 pass. Any failure = block build promotion.
> **Target Duration:** 25 minutes.

| Suite | Test Case ID | Module | Scenario | Preconditions | Steps | Expected Result | Priority | Severity | Status | Assigned QA | Build Version | Environment | Notes | Bug ID | Retest Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Smoke | SM-001 | Authentication | Valid login reaches HomeScreen | Valid account: farmer@test.com / Test@1234 exists; onboarding seen | Launch app → enter credentials → tap Login | HomeScreen loads; bottom nav visible; farm data shown; no error | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-002 | Authentication | Session persists after force-close | User already logged in; farm + pond exist | Force-close app → relaunch | Navigates directly to HomeScreen; no login prompt; data intact | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-003 | Farm Management | Create first farm | Logged in; no farms; on HomeScreen empty state | Tap Add Farm → Enter name + location → Create | Farm created; HomeScreen shows new farm; farms table row inserted | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-004 | Pond Management | Create pond generates feed schedule atomically | Farm exists; no ponds | Tap Add Pond → fill all fields (seed=150K, DOC=today, Hatchery Small, 4 trays) → Create | Pond + 30 feed_rounds created; pond card on HomeScreen; Feed tab shows DOC 1–30 schedule | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-005 | DOC Calculation | DOC = 1 on stocking day | Pond created with stocking_date = today | Navigate to Pond Dashboard → Overview tab | DOC = 1; not 0 or 2 | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-006 | Feed Engine | Base feed recommendation is non-zero | Pond: 150K seed, DOC=1 | Navigate to Pond → Feed tab | Feed recommendation ≥ 0.1 kg; not NaN; not null; 2 meals shown | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-007 | Feed Engine | Complete a feed round successfully | Pond at DOC=1; Round 1 planned | Tap Complete on Round 1 → confirm amount → submit | feed_logs row inserted; round status = Completed; history shows entry | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-008 | Feed Engine | Feed history updates without app restart | Feed round just completed (from SM-007) | Navigate to Feed History tab immediately | Completed round visible in history; no restart needed; provider auto-invalidated | P0 | S1 | | | | staging, device-android | Regression: BUG-5 area | | |
| Smoke | SM-009 | Dashboard | Pond card KPIs render correctly | Pond at DOC=1 exists | View HomeScreen pond card | Card shows correct DOC; ABW; no null values; no rendering crash | P1 | S2 | | | | staging, device-android | | | |
| Smoke | SM-010 | Crash Risk | No crash on fresh user with empty providers | New user; no farms; no ponds | Log in → navigate Home → Ponds → Profile → tap quick actions | No crash; correct empty states on all screens; no null errors | P0 | S1 | | | | staging, device-android | | | |
| Smoke | SM-011 | Sync/Offline | Feed round queues when offline | Pond with pending rounds; network: airplane mode | Enable airplane mode → complete Round 1 | Round shows Completed (optimistic); FeedSyncQueue has 1 pending op; no crash | P0 | S1 | | | | staging, device-android, offline-sim | | | |
| Smoke | SM-012 | Sync/Offline | Queued round syncs on reconnect | SM-011 precondition: 1 op queued offline | Disable airplane mode → wait 30 seconds | feed_logs row inserted; queue cleared; no manual action needed | P0 | S1 | | | | staging, device-android, offline-sim | | | |
| Smoke | SM-013 | Tray Logic | Log tray status and submit all trays | Pond with 4 trays; open Tray Log wizard | Open wizard → log each tray (mix of statuses) → submit | All 4 tray entries saved; tray_statuses rows inserted; wizard closes cleanly | P1 | S2 | | | | staging, device-android | | | |
| Smoke | SM-014 | Sampling | ABW sample calculates correctly | Pond at DOC=10; Growth tab open | Navigate to Sampling → enter weight=50g + pieces=10 → submit | ABW = 5.0g saved; displayed on Growth tab; samplings row in DB | P1 | S2 | | | | staging, device-android | | | |
| Smoke | SM-015 | Navigation | Logout clears session and state | Logged in as User A with farm data | Navigate to Profile → tap Logout | Login screen shown; User A data not visible; session cleared | P1 | S1 | | | | staging, device-android | | | |

---

# SUITE 2 — REGRESSION SUITE

> **Purpose:** Ensure no previously passing functionality is broken by a new code change.
> **Run:** After every merge to `main` branch.
> **Pass Criteria:** 35/35 pass. Any failure = revert or hotfix before re-merge.
> **Target Duration:** 2.5 hours.

| Suite | Test Case ID | Module | Scenario | Preconditions | Steps | Expected Result | Priority | Severity | Status | Assigned QA | Build Version | Environment | Notes | Bug ID | Retest Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Regression | RG-001 | Regression | Feed brand UUID stored correctly on pond creation | Feed brands exist in DB; Add Pond form open | Create pond with Feed Brand selected → save → view dashboard | feed_brand_id stored as UUID; correct brand shown; not null not TEXT | P0 | S1 | | | | staging | Fix: commit fb31b3e | | |
| Regression | RG-002 | Regression | Feed schedule visible immediately post-pond creation | Pond just created; no app restart | Navigate immediately to Feed tab | 30 feed_rounds visible; no empty state; no restart needed | P0 | S1 | | | | staging | Fix: commit 8c4fe6c | | |
| Regression | RG-003 | Regression | Seed count max validation enforced at 500K | Add Pond form open | Enter seed count = 600000 → submit | Validation error: max 500K; form blocked | P0 | S2 | | | | staging | Fix: BUG-12 | | |
| Regression | RG-004 | Regression | Feed history updates immediately on round completion | Pond with no feed logs today | Complete feed round → navigate to history immediately | Entry visible; no refresh needed; feedHistoryProvider invalidated | P1 | S2 | | | | staging | Fix: BUG-5 | | |
| Regression | RG-005 | Regression | Tray logging flows through to feed pipeline | PRO user; DOC > 30; tray wizard | Submit tray wizard → navigate to Feed tab | Feed reflects tray signal; pipeline trigger confirmed | P1 | S2 | | | | staging | Fix: TASK-2 | | |
| Regression | RG-006 | DOC Calculation | DOC = 1 on stocking day | Pond with stocking_date = today | Navigate to Overview | DOC = 1 exactly | P0 | S1 | | | | staging | | | |
| Regression | RG-007 | DOC Calculation | DOC = 31 after 30 elapsed days | Pond stocked 30 days ago | Navigate to Overview | DOC = 31 exactly | P0 | S1 | | | | staging | | | |
| Regression | RG-008 | DOC Calculation | DOC gates feed mode at boundary | Pond A DOC=29; Pond B DOC=31; PRO | Check each Feed tab mode | Pond A = blind; Pond B = smart with ramp | P0 | S1 | | | | staging | | | |
| Regression | RG-009 | Feed Engine | Base feed = 1.5 kg for 100K seed DOC 1 | Pond: 100K seed, DOC=1 | Navigate to Feed tab | Feed = 1.5 kg; 2 meals; no corrections | P0 | S1 | | | | staging | | | |
| Regression | RG-010 | Feed Engine | Density scaling: 300K seed = 4.5 kg | Pond: 300K seed, DOC=1 | Navigate to Feed tab | Feed = 4.5 kg (1.5 × 3); scaling confirmed | P0 | S1 | | | | staging | | | |
| Regression | RG-011 | Feed Engine | Daily increment +0.2 kg for DOC 1–7 | Pond: 100K seed | Observe feed at DOC 1 through 7 | DOC1=1.5, DOC2=1.7 … DOC7=2.7 kg exact | P0 | S1 | | | | staging | | | |
| Regression | RG-012 | Feed Engine | Feed round idempotent on double-tap | Pond with pending round; slow network | Double-tap complete round | Exactly 1 feed_log row; operationDuplicate on second call | P0 | S1 | | | | staging | | | |
| Regression | RG-013 | Feed Engine | Ramp mode applies 0.75 factor at DOC 31 | PRO; DOC=31; no tray or water data | Navigate to Feed tab | Feed = blind_base × 0.75; no cliff | P1 | S1 | | | | staging | | | |
| Regression | RG-014 | Tray Logic | All-Empty trays → INCREASE +5% | PRO; DOC=40; 4 trays; 3 sessions all-Empty | Check Feed recommendation | INCREASE; feed = base × 1.05 | P0 | S1 | | | | staging | | | |
| Regression | RG-015 | Tray Logic | All-Heavy trays → REDUCE -10% | PRO; DOC=40; 4 trays; 3 sessions all-Heavy | Check Feed recommendation | REDUCE; feed = base × 0.90 | P0 | S1 | | | | staging | | | |
| Regression | RG-016 | Tray Logic | Mixed trays → MAINTAIN | PRO; DOC=40; 3 sessions: 2 Empty + 2 Heavy each | Check Feed recommendation | MAINTAIN; feed unchanged | P0 | S1 | | | | staging | | | |
| Regression | RG-017 | Smart Feed | FREE user blocked from corrections | FREE plan; DOC=40; all-Empty trays | Navigate to Feed tab | Base feed only; no tray/FCR/env corrections | P0 | S1 | | | | staging | | | |
| Regression | RG-018 | Smart Feed | DO < 3.5 triggers STOP FEEDING | PRO; water DO=3.2 mg/L | Navigate to Feed tab | All rounds = 0.0 kg; STOP alert visible | P0 | S1 | | | | staging | | | |
| Regression | RG-019 | FCR Engine | FCR formula computes correct value | PRO; seed=100K; ABW=18g; total_feed=1800 kg | View Overview | FCR ≈ 1.11; adjustment = +10% | P0 | S1 | | | | staging | | | |
| Regression | RG-020 | FCR Engine | Corrupted FCR below 0.5 is discarded | Conditions producing FCR < 0.5 | View Feed tab | No correction applied; base feed used | P0 | S1 | | | | staging | | | |
| Regression | RG-021 | FCR Engine | Biomass < 1 kg guard prevents div-by-zero | Pond: 1K seed, DOC=5, ABW=0.1g | View Feed tab | FCR not computed; no error; feed continues | P0 | S1 | | | | staging | | | |
| Regression | RG-022 | Sampling | Duplicate sample for same DOC blocked | Sample already at DOC=30 | Try logging another at DOC=30 | Error or update shown; no silent duplicate | P1 | S2 | | | | staging | | | |
| Regression | RG-023 | Sampling | Sample older than 7 days treated as stale | Sample 8 days old; no newer sample | View Feed tab | ABW signal null; expected table used; warning shown | P1 | S2 | | | | staging | | | |
| Regression | RG-024 | ABW Engine | Sampled ABW overrides expected reference | DOC=45; expected=13.5g; log sample=11g | View dashboard | ABW shows 11g (Sampled); engine uses 11g | P1 | S1 | | | | staging | | | |
| Regression | RG-025 | Sync/Offline | No duplicate feed_log on sync replay | Feed round queued; simulate partial then full sync | Verify DB after full sync | Exactly 1 feed_log row; no duplicate | P0 | S1 | | | | staging, offline-sim | | | |
| Regression | RG-026 | Data Persistence | Feed logs persist after force-close | 3 rounds completed | Force-close → relaunch → view history | All 3 rounds in history; no data loss | P0 | S1 | | | | staging | | | |
| Regression | RG-027 | Data Persistence | Offline queue survives force-kill | Round queued offline | Force-close → relaunch offline | Queue retained; syncs on reconnect | P0 | S1 | | | | staging, offline-sim | | | |
| Regression | RG-028 | Pond Management | Pond creation idempotent on double-tap | Pond form filled; slow network | Double-tap create | Exactly 1 pond in DB; no duplicate | P0 | S1 | | | | staging | | | |
| Regression | RG-029 | Pond Management | FREE pond limit blocks 4th pond | FREE user; 3 ponds | Attempt 4th pond | Limit sheet shown; form blocked | P0 | S1 | | | | staging | | | |
| Regression | RG-030 | Farm Management | FREE farm limit blocks 2nd farm | FREE user; 1 farm | Attempt 2nd farm | Limit sheet shown; form blocked | P0 | S1 | | | | staging | | | |
| Regression | RG-031 | Subscription | Server entitlement overrides local state | Tamper with local PRO state | Navigate to smart feed; server returns FREE | FREE features only; server wins | P0 | S1 | | | | staging | | | |
| Regression | RG-032 | Multi-Pond | Feed recommendations independent per pond | Ponds A and B with different DOC and seed | Compare Feed tabs for each | Each uses own data; no cross-contamination | P1 | S1 | | | | staging | | | |
| Regression | RG-033 | Multi-Pond | Tray logs scoped to correct pond | Log tray for Pond A | Navigate to Pond B Trays | Pond B shows own data; Pond A not visible | P1 | S1 | | | | staging | | | |
| Regression | RG-034 | Navigation | Dashboard reflects pond edit immediately | Edit pond seed count | Return to dashboard | Updated value visible; feed recalculates | P1 | S2 | | | | staging | | | |
| Regression | RG-035 | Crash Risk | NaN input to feed engine handled safely | Debug: inject NaN as DO | View feed recommendation | Valid number returned; no crash; safe default used | P1 | S1 | | | | staging | | | |

---

# SUITE 3 — CRITICAL PATH SUITE

> **Purpose:** Validate every scenario with direct financial, animal welfare, or data integrity impact. All 25 must pass before any production deployment.
> **Run:** Pre-release only (not on every build).
> **Pass Criteria:** 25/25 pass. A single S1 failure = No-Go. S2 failure = Conditional Go pending fix.
> **Target Duration:** 2 hours.

| Suite | Test Case ID | Module | Scenario | Preconditions | Steps | Expected Result | Priority | Severity | Status | Assigned QA | Build Version | Environment | Notes | Bug ID | Retest Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Critical Path | CP-001 | Authentication | Login works on production credentials | Valid prod-schema account | Login with valid credentials | HomeScreen loads; data visible; no error | P0 | S1 | | | | prod-mirror, device-android | | | |
| Critical Path | CP-002 | Authentication | Session persists 12 hours after last use | Logged in; app left idle 12 hours | Launch app without force-close after idle | Navigates to HomeScreen; no re-login; token silently refreshed | P0 | S1 | | | | prod-mirror | | | |
| Critical Path | CP-003 | Pond Management | Pond creation atomic — partial failure rolls back | Simulate RPC partial failure | Submit pond → force RPC failure mid-way | No partial pond or partial feed_rounds in DB; clean rollback | P0 | S1 | | | | staging | Requires DB inspection | | |
| Critical Path | CP-004 | Pond Management | Pond creation idempotent on duplicate operationId | Slow network; pond form filled | Double-tap Create Pond | Exactly 1 pond; 1 set of 30 feed_rounds; no duplicate | P0 | S1 | | | | staging | | | |
| Critical Path | CP-005 | DOC Calculation | Null stocking_date handled gracefully | Manually set stocking_date = NULL in DB | Open affected pond | No crash; error state with edit CTA; other ponds unaffected | P0 | S1 | | | | staging | Most dangerous edge case | | |
| Critical Path | CP-006 | Feed Engine | Feed clamped to 50 kg maximum | Pond: 1M seed; DOC=25 | Navigate to Feed tab | Feed ≤ 50.0 kg; not raw unclamped value | P0 | S1 | | | | staging | Financial impact: overfeeding | | |
| Critical Path | CP-007 | Feed Engine | Feed round completion idempotent | Pending round; slow network | Double-tap complete feed round | Exactly 1 feed_log; no double-count in FCR or history | P0 | S1 | | | | staging | FCR corruption risk | | |
| Critical Path | CP-008 | Smart Feed | DO < 3.5 stops all feeding | PRO; water DO=3.2 mg/L logged | Navigate to Feed tab | All rounds = 0.0 kg; STOP alert visible; no round completable | P0 | S1 | | | | staging | Animal welfare critical | | |
| Critical Path | CP-009 | Smart Feed | Temperature > 36°C stops feeding | PRO; water temp=37°C logged | Navigate to Feed tab | All rounds = 0.0 kg; temperature alert visible | P0 | S1 | | | | staging | Animal welfare critical | | |
| Critical Path | CP-010 | Smart Feed | Stale water data uses safe defaults not STOP | PRO; last water log 50 hours ago | Navigate to Feed tab | Safe defaults applied; NOT stopped; stale warning visible | P0 | S1 | | | | staging | False STOP = starvation risk | | |
| Critical Path | CP-011 | FCR Engine | FCR formula correct at standard values | PRO; seed=100K; ABW=18g; total_feed=1800 kg | View Overview and Feed | FCR = 1.11; adjustment = +10%; biomass = 1620 kg | P0 | S1 | | | | staging | Financial: direct feed cost | | |
| Critical Path | CP-012 | FCR Engine | Corrupted FCR below 0.5 discarded | Conditions producing FCR < 0.5 | View Feed tab | Correction = 0%; no crash; base feed used | P0 | S1 | | | | staging | | | |
| Critical Path | CP-013 | FCR Engine | Biomass < 1 kg guard prevents division error | Pond: 1K seed; DOC=5; ABW=0.1g | View Feed tab | FCR not computed; no error; feed continues normally | P0 | S1 | | | | staging | | | |
| Critical Path | CP-014 | Tray Logic | All-Empty tray decision increases feed 5% | PRO; DOC=40; 4 trays; 3 all-Empty sessions | View Feed recommendation | INCREASE; feed = base × 1.05; breakdown visible | P0 | S1 | | | | staging | | | |
| Critical Path | CP-015 | Tray Logic | All-Heavy tray decision reduces feed 10% | PRO; DOC=40; 4 trays; 3 all-Heavy sessions | View Feed recommendation | REDUCE; feed = base × 0.90; breakdown visible | P0 | S1 | | | | staging | | | |
| Critical Path | CP-016 | Sync/Offline | Feed round queues offline without data loss | Airplane mode on; pending round | Complete feed round offline | Op in queue; UI optimistic; no crash | P0 | S1 | | | | staging, offline-sim | | | |
| Critical Path | CP-017 | Sync/Offline | Queued round syncs cleanly on reconnect | Op queued from CP-016 | Reconnect; wait 30s | feed_logs inserted; queue cleared; history updated | P0 | S1 | | | | staging, offline-sim | | | |
| Critical Path | CP-018 | Sync/Offline | Zero duplicates on sync replay | Queued op; partial then full sync | Verify DB feed_logs count | Exactly 1 row per (pond_id, doc, round); no doubles | P0 | S1 | | | | staging, offline-sim | FCR corruption guard | | |
| Critical Path | CP-019 | Sync/Offline | Queue survives app force-kill and restores | Queued op; app killed | Relaunch; reconnect | Op present; syncs; feed_logs row created | P0 | S1 | | | | staging, offline-sim | | | |
| Critical Path | CP-020 | Subscription | PRO activation completes full payment flow | FREE user; Razorpay test mode configured | Upgrade → complete test payment | Subscription activated; PRO features available; DB row inserted | P0 | S1 | | | | staging | Requires Razorpay test keys | | |
| Critical Path | CP-021 | Subscription | Server entitlement is authoritative | Tamper local subscription state to PRO | App reads FREE from server | FREE features enforced; no bypass | P0 | S1 | | | | staging | Security critical | | |
| Critical Path | CP-022 | Subscription | Payment failure leaves user on FREE | Test failure payment card | Attempt payment → fail | Friendly error; user stays FREE; no partial sub | P0 | S1 | | | | staging | Revenue critical | | |
| Critical Path | CP-023 | Crash Risk | No crash with all Riverpod providers empty | Brand-new user account | Navigate through all screens | No crash; no null errors; empty states correct | P0 | S1 | | | | staging, device-android, device-budget | Test on budget device too | | |
| Critical Path | CP-024 | Crash Risk | NaN propagation blocked at feed engine input | Inject NaN via debug mode | View recommendation | Valid number; no crash; validator intercepts | P0 | S1 | | | | staging | | | |
| Critical Path | CP-025 | Integration | Full daily workflow completes end-to-end | PRO; DOC=45; fresh water log; ABW sample | Check KPIs → read feed rec → complete 4 rounds → log tray → view history | All steps succeed; 4 rounds in history; KPIs consistent | P0 | S1 | | | | staging, device-android | Golden path test | | |

---

# SUITE 4 — OFFLINE SUITE

> **Purpose:** Validate all offline data capture, queue mechanics, sync recovery, and API failure handling.
> **Run:** Every merge to `main` + pre-release.
> **Pass Criteria:** 15/15 pass. S1 failure = No-Go.
> **Target Duration:** 1.5 hours.
> **Device Note:** Use a real device (not emulator) for network toggle tests.

| Suite | Test Case ID | Module | Scenario | Preconditions | Steps | Expected Result | Priority | Severity | Status | Assigned QA | Build Version | Environment | Notes | Bug ID | Retest Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Offline | OFF-001 | Sync/Offline | Feed round queues when airplane mode active | Pond with pending rounds; airplane mode ON | Complete feed round | Op in FeedSyncQueue; optimistic UI shows Completed; no crash | P0 | S1 | | | | device-android, offline-sim | Use real device | | |
| Offline | OFF-002 | Sync/Offline | Queue syncs automatically within 30s of reconnect | OFF-001 op queued | Disable airplane mode → wait | feed_logs row inserted; queue cleared | P0 | S1 | | | | device-android, offline-sim | | | |
| Offline | OFF-003 | Sync/Offline | No duplicate on partial then full sync | Op queued; first sync attempt fails partway | Simulate re-sync | Exactly 1 feed_log row; operationDuplicate on second RPC | P0 | S1 | | | | staging, offline-sim | operationId dedup critical | | |
| Offline | OFF-004 | Sync/Offline | Exponential backoff timing with jitter | Server returns 500 for RPC | Observe retry timings in app logs | Retries at ~5s ~10s ~20s ~40s ~80s each with ±20% jitter | P1 | S2 | | | | staging | Requires log monitoring | | |
| Offline | OFF-005 | Sync/Offline | Permanent failure shown after 5 retries | 5 consecutive server errors | Wait for all retries to exhaust | Op marked failed; warning bar shown; no further auto-retry | P1 | S2 | | | | staging | | | |
| Offline | OFF-006 | Sync/Offline | Queue survives app force-kill | Op queued offline | Force-close app → relaunch offline | Queue in SharedPrefs; op present; syncs on reconnect | P0 | S1 | | | | device-android, offline-sim | | | |
| Offline | OFF-007 | Sync/Offline | Synced ops pruned after 24 hours | 10 ops synced 25 hours ago | Trigger processQueue on startup | Synced ops removed; failed ops kept; storage freed | P2 | S3 | | | | staging | | | |
| Offline | OFF-008 | Data Persistence | Feed logs survive force-close | 3 rounds completed | Force-close → relaunch | All 3 rounds in history; no data loss | P0 | S1 | | | | device-android | | | |
| Offline | OFF-009 | Data Persistence | ABW sample drives next session recommendation | Sample logged: ABW=12g | Force-close → relaunch | ABW=12g shown; feed engine uses 12g | P1 | S1 | | | | device-android | | | |
| Offline | OFF-010 | Data Persistence | Queue survives force-kill before sync | Round queued; app killed before reconnect | Relaunch; reconnect | Queue retained; sync completes | P0 | S1 | | | | device-android, offline-sim | | | |
| Offline | OFF-011 | API Failure | Feed RPC 503 routes to offline queue | Server returning 503 for complete_feed_round | Complete feed round | Op queued; optimistic UI; no error dialog | P0 | S1 | | | | staging | Non-network errors must queue too | | |
| Offline | OFF-012 | API Failure | Pond RPC 500 shows error without partial data | Server returning 500 for create_pond RPC | Submit pond form | Error shown; form preserved; no partial pond in DB | P1 | S1 | | | | staging | | | |
| Offline | OFF-013 | API Failure | Entitlement failure defaults to FREE safely | get_active_entitlement returns error | Navigate to smart feed | FREE behavior enforced; no crash | P0 | S1 | | | | staging | Security default | | |
| Offline | OFF-014 | API Failure | Farm list failure shows retry UI | farms query returns error post-login | Wait for homescreen load to fail | Error state + Retry button; no crash; auth preserved | P1 | S2 | | | | staging | | | |
| Offline | OFF-015 | Multi-Pond | Multiple pond ops queue independently offline | Airplane mode ON; 2 ponds | Complete Round 1 for Pond A; Round 2 for Pond B offline | Both ops in queue; both sync independently; no cross-pond rows | P1 | S2 | | | | device-android, offline-sim | | | |

---

# SUITE 5 — PRODUCTION RISK SUITE

> **Purpose:** Stress-test the highest-risk scenarios: financial calculations, data corruption paths, security boundaries, and animal welfare rules.
> **Run:** Pre-release gate only.
> **Pass Criteria:** 20/20 pass. Any S1 failure = No-Go. S2 failures reviewed by lead.
> **Target Duration:** 2 hours.

| Suite | Test Case ID | Module | Scenario | Preconditions | Steps | Expected Result | Priority | Severity | Status | Assigned QA | Build Version | Environment | Notes | Bug ID | Retest Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Prod Risk | PR-001 | DOC Calculation | Null stocking_date does not crash app | Pond row with stocking_date = NULL in DB | Open affected pond | Graceful error state; no crash; other ponds unaffected | P0 | S1 | | | | staging | Highest single-function risk | | |
| Prod Risk | PR-002 | Feed Engine | Feed hard limit clamps at 50 kg | Pond: 1M seed; DOC=25 | View Feed recommendation | Max = 50.0 kg; not exceeding physical pond capacity | P0 | S1 | | | | staging | Overfeeding = financial loss + water quality damage | | |
| Prod Risk | PR-003 | Feed Engine | Feed round completion fully idempotent | Double-tap on slow network | Submit twice | Exactly 1 feed_log; FCR not double-counted | P0 | S1 | | | | staging | FCR corruption = wrong feeding decisions | | |
| Prod Risk | PR-004 | Smart Feed | DO critical stop condition (<3.5 mg/L) | PRO; DO=3.2 in water log | View Feed | 0.0 kg recommendation; STOP alert all rounds | P0 | S1 | | | | staging | Animal welfare: missed stop = mass mortality | | |
| Prod Risk | PR-005 | Smart Feed | Temperature critical stop (>36°C or <22°C) | PRO; temp=37°C in water log | View Feed | 0.0 kg recommendation; STOP alert | P0 | S1 | | | | staging | Animal welfare: same impact as DO stop | | |
| Prod Risk | PR-006 | Smart Feed | Stale water never causes false STOP | Water log exactly 50h old (stale) | View Feed | Safe defaults (DO=6.0) used; NOT stopped | P0 | S1 | | | | staging | False stop = unnecessary crop loss | | |
| Prod Risk | PR-007 | FCR Engine | Corrupted FCR below 0.5 discarded | Conditions producing FCR=0.3 | View Feed | 0% correction; no negative feed; no crash | P0 | S1 | | | | staging | Bad FCR drives wrong feed decisions | | |
| Prod Risk | PR-008 | FCR Engine | Biomass guard prevents division by zero | Pond: 1K seed; very low ABW | View Feed | FCR not computed; feed continues; no NaN/Inf | P0 | S1 | | | | staging | Division by zero = engine crash | | |
| Prod Risk | PR-009 | Crash Risk | NaN in feed engine does not propagate | Inject NaN as any input | View recommendation | Valid non-NaN number returned; clamps work | P0 | S1 | | | | staging | NaN propagation = 0 recommendation = starvation | | |
| Prod Risk | PR-010 | Subscription | Server entitlement cannot be bypassed locally | Tamper local PRO state | Navigate to PRO features | Server returns FREE → FREE enforced | P0 | S1 | | | | staging | Revenue bypass = financial loss | | |
| Prod Risk | PR-011 | Subscription | Payment failure leaves zero DB side-effects | Test failure card | Complete failed payment | User stays FREE; no partial subscription row | P0 | S1 | | | | staging | Subscription fraud risk | | |
| Prod Risk | PR-012 | Pond Management | Pond creation cannot be duplicated | Double-tap on Create | Submit twice | Exactly 1 pond; operationId dedup works | P0 | S1 | | | | staging | Duplicate pond = duplicate FCR data | | |
| Prod Risk | PR-013 | Sync/Offline | Permanent failure properly surfaced to farmer | 5 retries all fail | Check app state | Warning bar shown; farmer notified; feed round marked failed | P1 | S2 | | | | staging | Silent failure = no feed logged | | |
| Prod Risk | PR-014 | Data Persistence | All completed feed rounds survive restart | Complete 5 rounds across 2 DOCs | Force-close → relaunch | All 5 rounds in history; FCR recalculates correctly | P0 | S1 | | | | device-android | | | |
| Prod Risk | PR-015 | Data Persistence | Offline queue not lost on app kill | Queue 3 ops offline → kill app | Relaunch → reconnect | All 3 ops sync; correct feed_logs rows | P0 | S1 | | | | device-android, offline-sim | | | |
| Prod Risk | PR-016 | Farm Management | Delete farm cascade leaves no orphaned records | Farm with 2 ponds full data | Delete farm → confirm | Check DB: ponds, feed_rounds, feed_logs, samplings, tray_statuses all = 0 rows | P1 | S2 | | | | staging | Orphaned data = confusing future reports | | |
| Prod Risk | PR-017 | Pond Management | New cycle preserves previous harvest data | Cycle 1 has harvest record; start Cycle 2 | View harvest history after new cycle | Cycle 1 harvest preserved; not deleted; Cycle 2 starts clean | P1 | S2 | | | | staging | Revenue data loss | | |
| Prod Risk | PR-018 | Multi-Pond | Tray data never crosses between ponds | Log trays for Pond A | View Pond B tray tab | Pond B shows only its own data; zero Pond A contamination | P1 | S1 | | | | staging | Wrong tray data → wrong feed decision on Pond B | | |
| Prod Risk | PR-019 | Navigation | Logout fully isolates user data | Log in as User A → logout → log in as User B | Browse HomeScreen as User B | Zero User A farms/ponds/feed data visible | P1 | S1 | | | | staging | Privacy / data security | | |
| Prod Risk | PR-020 | Performance | DB timeout handled without infinite spinner | Simulate >30s response delay | Open HomeScreen | Error state + Retry shown; no infinite spinner; app usable | P1 | S2 | | | | staging | Stuck UI = farmer thinks app is broken | | |

---

# SUITE 6 — UAT SUITE

> **Purpose:** Validate product from a real farmer's perspective. These are end-to-end workflows that mirror actual daily shrimp farming operations.
> **Run:** Before the 20-farmer rollout. Ideally with at least 2 real farmers involved.
> **Pass Criteria:** 18/20 pass (90%). All S1 scenarios must pass.
> **Target Duration:** 3 hours (can be split over 2 sessions).
> **Tester:** QA Engineer + 1 Farmer (Telugu-speaking preferred)

| Suite | Test Case ID | Module | Scenario | Preconditions | Steps | Expected Result | Priority | Severity | Status | Assigned QA | Build Version | Environment | Notes | Bug ID | Retest Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| UAT | UAT-001 | Integration | New farmer setup: farm + pond on Day 1 | Fresh account; onboarding not seen | Open app → complete onboarding → create farm → create pond (DOC=1) | Onboarding shown; farm created; pond created with feed schedule; DOC=1 visible on home | P0 | S1 | | | | staging, device-android | Most critical onboarding flow | | |
| UAT | UAT-002 | Integration | Full daily workflow: PRO farmer at DOC 45 | PRO; pond DOC=45; fresh water log (DO=7.0); ABW sample 3 days old | Check Overview → read feed rec → complete all 4 rounds → log tray | Recommendation sensible (not 0; not 50 kg); 4 rounds logged; tray accepted | P0 | S1 | | | | staging, device-android | Golden daily path | | |
| UAT | UAT-003 | Feed Logic | Tray log adjusts next-day recommendation | PRO; DOC=40; 4 trays | Log 3 consecutive all-Empty tray sessions → check next feed recommendation | Recommendation increases by 5%; farmer sees visual confirmation | P1 | S1 | | | | staging | Key value prop for PRO | | |
| UAT | UAT-004 | Sampling | Sample ABW updates pond metrics | Pond DOC=35; no sample yet | Navigate to Growth → log sample (shrimp weighed on farm) | ABW shown; expected vs actual comparison visible; DOC age shown | P1 | S2 | | | | staging, device-android | | | |
| UAT | UAT-005 | Smart Feed | DO warning stops feeding | PRO; log water test with DO=3.0 | Navigate to Feed tab | STOP FEEDING shown clearly in farmer language; 0.0 kg; farmer understands why | P0 | S1 | | | | staging | Must be comprehensible to farmers | | |
| UAT | UAT-006 | Subscription | Free-tier farmer hits pond limit naturally | FREE user; creates 3 ponds one at a time | Attempt to create 4th pond | Upgrade sheet appears naturally in workflow; not jarring; CTA clear | P1 | S2 | | | | staging | UX: upgrade should feel helpful not blocking | | |
| UAT | UAT-007 | Sync/Offline | Farmer feeds offline in the field | Pond with pending rounds; device in airplane mode | Complete all 4 rounds offline | All 4 rounds marked Completed; queue shows pending; reconnect → all sync | P0 | S1 | | | | device-android, offline-sim | Real field scenario | | |
| UAT | UAT-008 | Harvest | Log partial harvest and view revenue | Pond DOC=60; partial harvest event | Navigate to Harvest → Log Partial Harvest → enter weight + price/kg | Harvest saved; revenue = weight × price shown; cumulative revenue updates | P1 | S2 | | | | staging | | | |
| UAT | UAT-009 | Harvest | Final harvest triggers new cycle | Pond at end of cycle | Log Final Harvest → tap Start New Cycle → enter new stocking details | DOC resets to 1; new feed schedule generated; old harvest preserved | P0 | S1 | | | | staging | Critical cycle management | | |
| UAT | UAT-010 | Multi-Pond | Farmer manages 3 ponds with different DOCs | PRO; 3 ponds: DOC 15, 45, 75 | Navigate between all 3 ponds; view each Feed tab; complete one round per pond | Each pond shows correct independent data; rounds logged correctly per pond | P1 | S1 | | | | staging, device-android | | | |
| UAT | UAT-011 | Localization | Telugu-speaking farmer completes daily workflow | Device language or app language set to Telugu | Complete: check Overview → read feed → complete round → log tray in Telugu | All labels in Telugu; no broken strings; key farming terms readable | P1 | S2 | | | | device-android | Critical for AP coastal farmers | | |
| UAT | UAT-012 | Supplements | Add supplement schedule and see it on feed round | Pond active; navigate to Supplements | Add Probiotics supplement at Round 2 → navigate to Feed tab Round 2 | Supplement chip visible on Round 2; farmer knows what to add when | P1 | S2 | | | | staging | | | |
| UAT | UAT-013 | Cost Tracking | Log daily expenses and view monthly total | Expense module active for farm | Log 3 expenses over 3 days (feed, labor, supplements) → view Monthly tab | Correct total; correct categories; no extra taps needed | P1 | S2 | | | | staging | | | |
| UAT | UAT-014 | Inventory | Check feed inventory after a week of feeding | Inventory set up; 7 days of feeding logged | Navigate to Inventory Dashboard | Feed stock correctly reduced by cumulative feed given; low-stock warning if applicable | P2 | S3 | | | | staging | | | |
| UAT | UAT-015 | Water Quality | Log water test and see feed adjusted | PRO; navigate to Water tab | Log water test (DO=4.2, temp=26°C) → navigate to Feed tab | Feed reduced by env factor (DO 3.5–4.5 → 50% factor); water quality shown in breakdown | P1 | S2 | | | | staging | | | |
| UAT | UAT-016 | Profit | PRO farmer views end-of-cycle profit | PRO; cycle has harvest + expenses | Navigate to Profit Summary | Profit = revenue − expenses; cost per kg and margin % shown | P1 | S2 | | | | staging | | | |
| UAT | UAT-017 | Farm Management | Farmer adds a worker and confirms access | PRO; navigate to Farm Settings | Add member as Worker → log out → log in as worker → attempt feeding | Worker can log feed; worker cannot delete pond or manage billing | P2 | S2 | | | | staging | Team management flow | | |
| UAT | UAT-018 | Integration | Free farmer upgrades to PRO mid-cycle | FREE; at DOC=35 with tray data accumulated | Tap upgrade → complete payment → return to Feed tab | Smart feed corrections now visible; tray data now applied; breakdown shown | P1 | S1 | | | | staging | Key conversion moment | | |
| UAT | UAT-019 | Performance | App usable on budget Android device | Budget device: 2GB RAM, Android 10 | Complete full daily workflow: login → feed → tray → sample | No crash; <4s cold launch; smooth scrolling; no ANR | P1 | S2 | | | | device-budget | ~60% of farmers use budget devices | | |
| UAT | UAT-020 | Performance | App usable on iOS device | iOS device: iPhone 12 equivalent | Complete full daily workflow: login → feed → tray → sample | No crash; no iOS-specific UI bugs; all interactions work | P1 | S2 | | | | device-ios | | | |

---

---

# DAILY QA DASHBOARD

> **Template:** Copy this section for each build. Fill in actuals after each test run.
> **Update Frequency:** After each test session (minimum: once per day during active testing)

---

## Build Dashboard — [BUILD VERSION] — [DATE]

```
╔══════════════════════════════════════════════════════════════════╗
║              AQUA RYTHU QA DAILY DASHBOARD                       ║
║  Build: ___________  Date: ___________  Tester: ___________      ║
╠══════════════════════════════════════════════════════════════════╣
║  EXECUTION SUMMARY                                               ║
║  ─────────────────────────────────────────────────────────────── ║
║  Total Cases in Suite    │  ___                                  ║
║  Total Executed Today    │  ___                                  ║
║  Passed                  │  ___                                  ║
║  Failed                  │  ___                                  ║
║  Blocked                 │  ___                                  ║
║  Skipped                 │  ___                                  ║
║  Not Run                 │  ___                                  ║
║  Pass Rate               │  ____%  (Passed / Executed × 100)    ║
╠══════════════════════════════════════════════════════════════════╣
║  SUITE BREAKDOWN                                                 ║
║  ─────────────────────────────────────────────────────────────── ║
║  Suite              │ Total │ Pass │ Fail │ Block │ Pass%        ║
║  Smoke              │  15   │  __  │  __  │  __   │  __%         ║
║  Regression         │  35   │  __  │  __  │  __   │  __%         ║
║  Critical Path      │  25   │  __  │  __  │  __   │  __%         ║
║  Offline            │  15   │  __  │  __  │  __   │  __%         ║
║  Production Risk    │  20   │  __  │  __  │  __   │  __%         ║
║  UAT                │  20   │  __  │  __  │  __   │  __%         ║
╠══════════════════════════════════════════════════════════════════╣
║  BUG SUMMARY                                                     ║
║  ─────────────────────────────────────────────────────────────── ║
║  New Bugs Found Today    │  ___                                  ║
║  S1 — Blocker            │  ___  [ ] All fixed before promote    ║
║  S2 — Critical           │  ___  [ ] Fix plan in place           ║
║  S3 — Major              │  ___  [ ] Tracked in backlog          ║
║  S4 — Minor              │  ___  [ ] Tracked in backlog          ║
║  ─────────────────────────────────────────────────────────────── ║
║  Open Bugs (total)       │  ___                                  ║
║  Bugs Fixed & Retested   │  ___                                  ║
║  Retest Pass             │  ___                                  ║
║  Retest Fail             │  ___                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  LAUNCH BLOCKERS                                                 ║
║  ─────────────────────────────────────────────────────────────── ║
║  BUG-___: [Description]                    Assignee: ___        ║
║  BUG-___: [Description]                    Assignee: ___        ║
║  BUG-___: [Description]                    Assignee: ___        ║
╠══════════════════════════════════════════════════════════════════╣
║  REGRESSION BUGS (new failures vs last build)                    ║
║  ─────────────────────────────────────────────────────────────── ║
║  BUG-___: [Description] — regressed in [module]                 ║
╠══════════════════════════════════════════════════════════════════╣
║  RISK AREAS FOR TODAY                                            ║
║  ─────────────────────────────────────────────────────────────── ║
║  [ ] Feed engine calculation output (verify daily)              ║
║  [ ] Offline queue sync status                                  ║
║  [ ] Subscription gate working correctly                        ║
║  [ ] DOC calculation accuracy                                   ║
║  [ ] FCR correctness                                            ║
╠══════════════════════════════════════════════════════════════════╣
║  ENVIRONMENT STATUS                                              ║
║  ─────────────────────────────────────────────────────────────── ║
║  Supabase Staging    │  [ ] Up  [ ] Degraded  [ ] Down          ║
║  Razorpay Test Mode  │  [ ] Up  [ ] Degraded  [ ] Down          ║
║  Android Test Device │  [ ] OK  [ ] Issues: ___                 ║
║  iOS Test Device     │  [ ] OK  [ ] Issues: ___                 ║
╠══════════════════════════════════════════════════════════════════╣
║  OVERALL BUILD STATUS                                            ║
║  ─────────────────────────────────────────────────────────────── ║
║  [ ] GREEN — All suites passing; promote to next stage          ║
║  [ ] YELLOW — Minor failures; conditional promote with sign-off ║
║  [ ] RED — Blocker found; do not promote; fix required          ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Dashboard — Active Bug Tracker

| Bug ID | Title | Module | Severity | Reported | Assignee | Fix ETA | Status | Retest Result |
|---|---|---|---|---|---|---|---|---|
| BUG-001 | | | | | | | Open | |
| BUG-002 | | | | | | | Open | |
| BUG-003 | | | | | | | Open | |

---

## Daily Trend Table

| Date | Build | Executed | Pass | Fail | Blocked | Pass% | New Bugs | Open Bugs | Status |
|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | |
| | | | | | | | | | |
| | | | | | | | | | |

---

---

# RELEASE GO / NO-GO CHECKLIST

> **Version:** Aqua Rythu v1.0.0+1
> **Decision Owner:** QA Lead + Product Manager
> **Meeting:** Day before planned release
> **Outcome:** GO ✅ or NO-GO ❌ or CONDITIONAL GO ⚠️

---

## Section A — Test Completion Gates

| # | Criterion | Target | Actual | Pass? |
|---|---|---|---|---|
| A-01 | Smoke Suite pass rate | 100% (15/15) | | |
| A-02 | Regression Suite pass rate | 100% (35/35) | | |
| A-03 | Critical Path Suite pass rate | 100% (25/25) | | |
| A-04 | Offline Suite pass rate | 100% (15/15) | | |
| A-05 | Production Risk Suite pass rate | 100% (20/20) | | |
| A-06 | UAT Suite pass rate | ≥ 90% (18/20) | | |
| A-07 | All P0 test cases have Pass status | 100% | | |
| A-08 | All S1 severity bugs resolved and retested | 100% | | |
| A-09 | No test cases in Blocked state for >24h | 0 | | |
| A-10 | All regression suite tests pass on latest build | 100% | | |

**Section A Decision:** `[ ] Pass` `[ ] Fail` `[ ] Conditional`

---

## Section B — Critical Business Logic

| # | Criterion | Verified By | Status |
|---|---|---|---|
| B-01 | DOC = 1 on stocking day; increments correctly each day | | |
| B-02 | Feed recommendation never returns NaN, Infinity, or negative | | |
| B-03 | DO < 3.5 mg/L results in 0.0 kg feed recommendation (STOP) | | |
| B-04 | Temperature > 36°C or < 22°C results in 0.0 kg (STOP) | | |
| B-05 | Stale water data (>48h) uses safe defaults, does NOT stop feeding | | |
| B-06 | FCR formula: total_feed / (seedCount × 0.90 × ABW/1000) verified | | |
| B-07 | Tray INCREASE decision confirmed at all-Empty signal | | |
| B-08 | Tray REDUCE decision confirmed at all-Heavy signal | | |
| B-09 | FREE tier cannot access smart feed corrections | | |
| B-10 | PRO tier smart corrections compound correctly (multiply not add) | | |
| B-11 | Feed round completion is idempotent (double-tap = 1 record) | | |
| B-12 | Offline queue syncs correctly on reconnect with no duplicates | | |
| B-13 | Server entitlement overrides any local subscription state | | |
| B-14 | Pond creation idempotent via operationId | | |
| B-15 | Biomass < 1 kg guard prevents FCR division errors | | |

**Section B Decision:** `[ ] Pass` `[ ] Fail` `[ ] Conditional`

---

## Section C — Data Integrity

| # | Criterion | Verified By | Status |
|---|---|---|---|
| C-01 | Feed logs persist across app restarts | | |
| C-02 | Offline queue survives app force-kill | | |
| C-03 | Delete farm cascade leaves zero orphaned DB records | | |
| C-04 | New cycle setup preserves previous harvest records | | |
| C-05 | Expenses scoped to correct crop_id (no cross-cycle leakage) | | |
| C-06 | Multi-pond: Pond A data never appears in Pond B context | | |
| C-07 | Logout fully clears Riverpod state before next user session | | |
| C-08 | Sampling dedup: one record per (pond_id, DOC) enforced | | |
| C-09 | FCR uses last-row-wins correctly for duplicate round entries | | |
| C-10 | feed_brand_id stored as UUID (regression from commit fb31b3e) | | |

**Section C Decision:** `[ ] Pass` `[ ] Fail` `[ ] Conditional`

---

## Section D — Performance & Stability

| # | Criterion | Target | Measured | Status |
|---|---|---|---|---|
| D-01 | Cold launch to HomeScreen | < 3s on mid-range Android | | |
| D-02 | Feed engine computation time | < 500ms | | |
| D-03 | No crash on empty Riverpod providers (new user) | 0 crashes | | |
| D-04 | Memory stable after 20× rapid screen switches | No leak | | |
| D-05 | 720-row feed history loads and scrolls | < 2s load, 60fps scroll | | |
| D-06 | DB timeout handled gracefully | Error state shown | | |
| D-07 | NaN input to feed engine produces valid output | No NaN/Inf output | | |
| D-08 | App tested on budget Android device (2GB RAM) | No OOM crash | | |

**Section D Decision:** `[ ] Pass` `[ ] Fail` `[ ] Conditional`

---

## Section E — Security & Payments

| # | Criterion | Verified By | Status |
|---|---|---|---|
| E-01 | Razorpay HMAC verified server-side (not client-side) | | |
| E-02 | No subscription created on payment failure | | |
| E-03 | Client RLS blocks subscription write attempts | | |
| E-04 | Debug menu not accessible in release build | | |
| E-05 | Feed debug panel not rendered in release build | | |
| E-06 | Payment debug screen not accessible in release build | | |
| E-07 | Admin passcode required for debug features | | |
| E-08 | Raw Supabase error codes never shown to users | | |

**Section E Decision:** `[ ] Pass` `[ ] Fail` `[ ] Conditional`

---

## Section F — Device & Platform Compatibility

| # | Criterion | Tested On | Status |
|---|---|---|---|
| F-01 | Full smoke suite passes on Android (mid-range) | Android 11, 4GB RAM | |
| F-02 | Full smoke suite passes on Android (budget) | Android 10, 2GB RAM | |
| F-03 | Full smoke suite passes on iOS | iOS 15+, iPhone 12 | |
| F-04 | Telugu language rendering correct on all screens | Android device | |
| F-05 | Offline sync tested on real device (not emulator) | Real Android device | |
| F-06 | App installs from APK/TestFlight cleanly | Both platforms | |

**Section F Decision:** `[ ] Pass` `[ ] Fail` `[ ] Conditional`

---

## Go/No-Go Summary

| Section | Decision | Notes |
|---|---|---|
| A — Test Completion | | |
| B — Business Logic | | |
| C — Data Integrity | | |
| D — Performance | | |
| E — Security | | |
| F — Compatibility | | |

### Final Decision

```
╔═══════════════════════════════════════════════════╗
║           RELEASE DECISION                        ║
║                                                   ║
║  [ ] GO      — All sections pass; release         ║
║  [ ] NO-GO   — One or more blockers; hold         ║
║  [ ] COND.   — Conditional; minor items tracked   ║
║                                                   ║
║  Rationale:                                       ║
║  ____________________________________________     ║
║  ____________________________________________     ║
║                                                   ║
║  QA Lead:    __________________  Date: _______    ║
║  PM:         __________________  Date: _______    ║
║  Eng Lead:   __________________  Date: _______    ║
╚═══════════════════════════════════════════════════╝
```

---

---

# PRE-PRODUCTION SIGNOFF CHECKLIST

> **Purpose:** Final human verification before v1.0.0+1 is deployed to production and first farmers are onboarded.
> **Complete:** All items must be checked or documented as accepted risk before release.

---

## 1. Code & Build Verification

| # | Item | Owner | Status | Date |
|---|---|---|---|---|
| 1.1 | Build version `1.0.0+1` confirmed in `pubspec.yaml` | Dev | | |
| 1.2 | All P0 & P1 bugs resolved and retested green | QA | | |
| 1.3 | No `TODO`, `FIXME`, or `HACK` markers in production-path code | Dev | | |
| 1.4 | Temporary log (TASK 2: TEMPORARY LOG) removed from `tray_provider.dart` | Dev | | |
| 1.5 | `flutter analyze` reports zero errors and zero warnings | Dev | | |
| 1.6 | Release build (not debug) tested end-to-end | QA | | |
| 1.7 | Debug menu unreachable in release build (5-tap easter egg disabled or gated) | QA | | |
| 1.8 | Feed debug panel not rendered in release build | QA | | |
| 1.9 | `payment_debug_screen.dart` not accessible in release build | QA | | |
| 1.10 | Splash image compressed (verified ~952 KB, not 5.4 MB) | Dev | | |

---

## 2. Backend / Supabase Verification

| # | Item | Owner | Status | Date |
|---|---|---|---|---|
| 2.1 | All Supabase migrations applied to production project | Dev | | |
| 2.2 | RLS policies verified: subscriptions table SELECT-only for clients | Dev | | |
| 2.3 | `create_pond_with_feed_plan` RPC tested on production schema | Dev | | |
| 2.4 | `complete_feed_round_with_log` RPC idempotency confirmed on prod schema | Dev | | |
| 2.5 | `get_active_entitlement` RPC uses SECURITY DEFINER (not caller) | Dev | | |
| 2.6 | Edge functions (`create-razorpay-order`, `verify-razorpay-payment`) deployed | Dev | | |
| 2.7 | Razorpay switched from test mode to live mode | Dev | | |
| 2.8 | `app_config` table has correct production values (kill_switch=false, multiplier=1.0) | Dev | | |
| 2.9 | Feed brand data populated in production DB | Dev | | |
| 2.10 | Product master and master_categories tables populated | Dev | | |

---

## 3. Security Sign-off

| # | Item | Owner | Status | Date |
|---|---|---|---|---|
| 3.1 | No hardcoded API keys, secrets, or credentials in source code | Dev + QA | | |
| 3.2 | Supabase URL and anon key are environment variables, not committed | Dev | | |
| 3.3 | Razorpay key ID not committed to source; loaded from config | Dev | | |
| 3.4 | All user data access requires authenticated session | Dev | | |
| 3.5 | Payment HMAC verification confirmed server-side only | Dev | | |
| 3.6 | No user can access another user's farm/pond data (RLS confirmed) | Dev | | |
| 3.7 | Subscription tier cannot be elevated client-side | QA | | |

---

## 4. Feature Readiness

| # | Feature | Ship Status | Gate Condition |
|---|---|---|---|
| 4.1 | Authentication (login, signup, session) | Ship | — |
| 4.2 | Farm + Pond management | Ship | — |
| 4.3 | Feed engine (blind phase, DOC 1–30) | Ship | — |
| 4.4 | Feed engine (smart phase, DOC > 30) | Ship (PRO only) | Subscription gate |
| 4.5 | Tray monitoring | Ship | — |
| 4.6 | Growth sampling | Ship | — |
| 4.7 | Expense tracking | Ship | Feature flag = true |
| 4.8 | Inventory management | Ship | Feature flag = true |
| 4.9 | Offline sync queue | Ship | — |
| 4.10 | Harvest management | Hold (feature flag = false) | Confirm intentional |
| 4.11 | Water quality logging | Hold (feature flag = false) | Confirm intentional |
| 4.12 | Supplements module | Hold (feature flag = false) | Confirm intentional |
| 4.13 | Profit analysis | Hold (feature flag = false) | Confirm intentional |
| 4.14 | Team management | Ship (PRO only) | Subscription gate |
| 4.15 | Upgrade / Paywall | Ship | — |

---

## 5. QA Signoff Summary

| Suite | Cases | Pass | Fail | Blocked | Pass% | QA Sign |
|---|---|---|---|---|---|---|
| Smoke | 15 | | | | | |
| Regression | 35 | | | | | |
| Critical Path | 25 | | | | | |
| Offline | 15 | | | | | |
| Production Risk | 20 | | | | | |
| UAT | 20 | | | | | |
| **Total** | **130** | | | | | |

---

## 6. Launch Readiness Signoffs

```
┌───────────────────────────────────────────────────────────────┐
│              PRE-PRODUCTION SIGNOFF SHEET                     │
│              Aqua Rythu v1.0.0+1                              │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  QA Lead                                                      │
│  Name: _______________________  Sign: ______________         │
│  Date: _______________________                                │
│  All QA suites passed: [ ] YES   Known risks accepted: [ ]   │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Engineering Lead                                             │
│  Name: _______________________  Sign: ______________         │
│  Date: _______________________                                │
│  Code frozen: [ ]  All P0 bugs fixed: [ ]  Build confirmed: [ ] │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Product Manager                                              │
│  Name: _______________________  Sign: ______________         │
│  Date: _______________________                                │
│  Feature scope confirmed: [ ]  UAT accepted: [ ]             │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Open Risks Accepted for Launch (document all):              │
│  1. _______________________________________________________   │
│  2. _______________________________________________________   │
│  3. _______________________________________________________   │
│                                                               │
│  FINAL DECISION:                                              │
│  [ ] APPROVED FOR PRODUCTION RELEASE                         │
│  [ ] HOLD — Issues to resolve: ___________________________   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 7. Post-Launch Monitoring Checklist (First 24 Hours)

| # | Monitor | Owner | Check Interval | Alert Threshold |
|---|---|---|---|---|
| 7.1 | Supabase error rate on `complete_feed_round_with_log` RPC | Dev | Every 2 hours | > 1% error rate |
| 7.2 | FeedSyncQueue permanent failures (synced=false after 5 retries) | Dev | Every 4 hours | Any occurrence |
| 7.3 | App crash rate (crash reporting tool) | QA | Every 2 hours | > 0.5% session crash rate |
| 7.4 | Razorpay payment success rate | Dev | Every 4 hours | < 90% success |
| 7.5 | Supabase edge function errors | Dev | Every 4 hours | Any 500 errors |
| 7.6 | Farmer support tickets / feedback | PM | Real-time | Any P0/P1 complaint |
| 7.7 | DOC calculation accuracy (spot-check 2–3 farmer ponds) | QA | Day 1 only | Any wrong value |
| 7.8 | Feed recommendation sanity (not 0, not > 50 kg for normal ponds) | QA | Day 1 only | Any outlier |

---

*Document End — Aqua Rythu Enterprise QA Suite v1.0 — 2026-05-17*
