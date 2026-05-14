# 🚀 Pre-Launch Testing Checklist (20-Farmer Rollout)

**Status**: 4/13 CRITICAL BLOCKERS FIXED + CODE VERIFIED ✅  
**Remaining**: 9 manual testing items to verify  
**Target**: All green before farmer deployment  

---

## ✅ FIXED BLOCKERS (4/8)

### ✅ #1: Product Master Data (814 products)
- **Status**: COMPLETE
- **Verification**: 837 products across 26 categories imported to `product_master` table
- **Categories**: Ammonia, EDTA, Growth Promoters, GEL, YEAST, NITRATES, VITAMIN C, GEOLITE, IMMUNITY, FEED SUPPLEMENTS, OXYGEN, MINERALS, SANITIZERS, PROBIOTICS + more
- **Last verified**: May 14, 2026

### ✅ #7: Feed Brand Selection Persistence  
- **Status**: FIXED
- **Changes**:
  - Added `feedBrandId` parameter to `createPond()` and `createPondAndReturnId()`
  - Updated `add_pond_screen.dart` to capture and pass feed brand selection
  - Feed brand now saves to `ponds.feed_brand_id` during creation
  - Dashboard retrieves and displays brand via `getPondById()`
- **Commit**: `be2cf1d` (just now)
- **Test**: Create new pond → select feed brand → verify dashboard shows brand

### ✅ #3: Circular Dependency Fix (Riverpod)
- **Status**: VERIFIED
- **Issue**: `feedScheduleProvider` invalidating itself during saves → crash
- **Fix**: Removed self-invalidation, kept dependent invalidations
- **Evidence**: 
  ```dart
  // Note: Do NOT invalidate feedScheduleProvider itself — this notifier
  // IS that provider, and invalidating it creates a circular dependency.
  _ref.invalidate(feedHistoryProvider);
  ```
- **Commit**: `0ace555` (May 13, 2026)

### ✅ #4: FeedDayPlan Map Access Crash
- **Status**: VERIFIED + TESTED
- **Issue**: Treating `FeedDayPlan` object as Map (plan['rounds']) → NoSuchMethodError
- **Fix**: Changed to typed parameter `List<FeedDayPlan>` + dot notation (plan.rounds)
- **Tests**: 6 test cases added, all passing
- **Commit**: `274c9aa` (May 13, 2026)

---

## 🧪 REMAINING BLOCKERS (9 — Manual Testing Required)

### BLOCKER #2: Feature Gating Enforcement (FREE vs PRO)

**Test 1: FREE User — DOC 1–30 Blind Only**
- [ ] Login as FREE user
- [ ] Create new pond
- [ ] Verify DOC 1–30: Feed recommendations are BLIND (no smart corrections)
- [ ] Verify message: "Following blind schedule until DOC 29"
- [ ] Verify: Tray logging is ALLOWED but NOT used in feed calculations
- [ ] Verify: Manual feed edit works
- **Expected**: No smart factors applied, tray data logged but ignored

**Test 2: FREE User — DOC 31 Paywall**
- [ ] Progress to DOC 31
- [ ] Verify paywall appears: "Upgrade to PRO for Smart Feed"
- [ ] Verify feed recommendations stay BLIND (no smart corrections applied)
- [ ] Verify: Cannot use tray factors, environment, or growth intelligence
- **Expected**: Paywall shown once per session, feed stays simple

**Test 3: PRO User — Full Smart Feed**
- [ ] Login as PRO user (or use debug override: Settings → Toggle PRO)
- [ ] Create/access pond at DOC 1–30: Should see blind phase (expected)
- [ ] Progress to DOC 31: Smart feed activates
- [ ] Verify: Tray corrections applied ("Adjust to X kg based on trays")
- [ ] Verify: Environment factors visible ("Temp: 28°C, Salinity: 18")
- [ ] Verify: Growth intelligence shown ("Expected ABW vs Actual")
- **Expected**: Full recommendation pipeline active, all factors applied

**Test 4: Tray Correction Gate**
- [ ] PRO: Log tray data → verify correction factors applied
- [ ] FREE: Log tray data → verify data saved but NOT used in calc
- **Code Reference**: [tray_decision_engine.dart:119](lib/systems/tray/tray_decision_engine.dart#L119)

**Status to File**: Once all 4 tests pass, mark Feature Gating as ✅

---

### BLOCKER #5: Feed Completion Atomicity (Double-Tap Safety)

**Setup for All Tests**
```
1. Open browser DevTools → Network tab
2. Enable 2G throttling (5000ms latency):
   Network → Conditions → 2G
3. OR: Go offline mid-request to test network failure
```

**Test P0: Double-Tap with Slow Network (CRITICAL)**
- [ ] Load pond dashboard, view pending round
- [ ] **Tap "Mark Complete" button 3 times rapidly** (no waiting)
- [ ] Wait 30 seconds for network to respond
- [ ] Verify UI: Round shows "completed"
- [ ] Verify Logs: Only 1 feed_logs entry created (not 3)
- [ ] Verify DB: `SELECT COUNT(*) FROM feed_logs WHERE pond_id='X' AND doc=N AND round=4;` → Result = 1
- **Expected**: Idempotent save — duplicates prevented
- **Failure Signal**: Multiple entries in feed_logs or UI inconsistency

**Test P1: Network Failure Mid-RPC**
- [ ] Tap "Mark Complete" for pending round
- [ ] After 2 seconds, go offline (DevTools → Offline)
- [ ] Wait 10 seconds
- [ ] Turn network back online
- [ ] Wait for response
- [ ] Verify: Either (1) fully completed + logged OR (2) rolled back + NOT logged
- [ ] Verify: NO partial states (e.g., status=completed but NO feed_logs entry)
- **Expected**: Automatic rollback on network failure, no data corruption

**Test P1: Refresh After Completion**
- [ ] Mark round complete
- [ ] Immediately refresh page (F5)
- [ ] Verify: Round still shows "completed"
- [ ] Verify: Feed not duplicated
- **Expected**: State persists, no data loss

**Test P1: Kill App + Restart**
- [ ] Mark round complete
- [ ] Force-close app (or kill from Activity Manager)
- [ ] Restart app
- [ ] Navigate back to pond dashboard
- [ ] Verify: Round shows "completed"
- [ ] Verify: Consumed feed is correct (not doubled)
- **Expected**: Persists correctly to database

**Test P1: Engine Recompute**
- [ ] Mark multiple rounds complete
- [ ] Trigger engine refresh (swipe down, re-load pond)
- [ ] Verify: Totals are consistent, no double-counting
- **Expected**: Consumed feed matches sum of individual rounds

**Status to File**: Mark ✅ only when P0 + all P1 tests pass

---

### BLOCKER #6: Feed Schedule Generation (Seed Types)

**Test: Nursery Stocking (DOC 1–10 Phase)**
- [ ] Create pond with PL size = 5 or 8 (maps to nursery)
- [ ] Verify: Feed schedule generated for DOC 1–10
- [ ] Navigate to DOC 11: Verify rolling recovery activates
- [ ] Verify: Feed amounts smooth transition (no jumps)
- **Expected**: Nursery phase ends at DOC 10, feeding continues via rolling recovery

**Test: Hatchery Stocking (DOC 1–25 Phase)**
- [ ] Create pond with PL size = 10 or 12 (maps to hatchery)
- [ ] Verify: Feed schedule generated for DOC 1–25
- [ ] Navigate to DOC 26: Verify rolling recovery generates DOC 26–29
- [ ] Verify: Feed amounts consistent
- **Expected**: Hatchery blind phase extends to DOC 25, then rolling recovery

**Test: Smart Feed Activation (DOC 30+)**
- [ ] DOC 30 should show blind feed
- [ ] DOC 31 (PRO user): Smart feed activates
- [ ] DOC 31 (FREE user): Paywall shown, blind feed continues
- **Expected**: Transition smooth, no missing DOC or feed amounts

**Status to File**: Mark ✅ when all schedule phases verify correctly

---

### BLOCKER #8: Roles Feature (Farm Member Management)

**Test 1: FREE User Cannot Add Members**
- [ ] Login as FREE user
- [ ] Open Farm Details
- [ ] Tap "Add Member" button
- [ ] Verify: `RoleLimitBottomSheet` appears (not member form)
- [ ] Verify: "Upgrade to PRO" CTA visible
- [ ] Verify: Cannot proceed without upgrade
- **Expected**: Paywall shown, no member added

**Test 2: PRO User Can Add Members**
- [ ] Login as PRO user
- [ ] Open Farm Details
- [ ] Tap "Add Member" button
- [ ] Enter email: `testmember@example.com`
- [ ] Select role: Supervisor
- [ ] Tap "Send Invite"
- [ ] Verify: Success snackbar shown
- [ ] Verify: Member appears in list with "Supervisor" badge
- **Expected**: Member added, role visible

**Test 3: Member Deletion**
- [ ] In Farm Details, locate added member
- [ ] Tap delete (X) button
- [ ] Confirm deletion
- [ ] Verify: Member removed from list
- [ ] Verify: No errors in console
- **Expected**: Deletion successful, list updates

**Test 4: RLS Policies (Data Isolation)**
- [ ] Create 2 test accounts: User A + User B
- [ ] User A: Create farm with members
- [ ] User B: Try to access User A's farm members (via API)
- [ ] Verify: Access denied (403 Forbidden)
- **Expected**: RLS policies enforce farm-level isolation

**Test 5: Role Types Display**
- [ ] Add members with all 4 roles: Farmer, Partner, Supervisor, Worker
- [ ] Verify: Each shows correct badge color/text
- [ ] Verify: All roles visible in Farm Details
- **Expected**: UI renders all role types correctly

**Status to File**: Mark ✅ when all 5 role tests pass

---

### BLOCKER #5b: Harvest Flow (Cycle Reset)

**Test: Complete Harvest & Start New Cycle**
- [ ] Pond at DOC 85+, harvest ready
- [ ] Enter harvest details: Weight, survival %, revenue
- [ ] Tap "Harvest Complete"
- [ ] Verify: Harvest record saved to database
- [ ] Verify: Profit calculated correctly
- [ ] Tap "Start New Crop Cycle"
- [ ] Verify: New stocking_date resets DOC to 1
- [ ] Verify: Previous feed logs preserved (history view)
- [ ] Verify: New feed schedule generated
- **Expected**: Full cycle completes, data persists, new cycle independent

**Test: Profit Calculation**
- [ ] Complete harvest with known values
- [ ] Verify formula: Profit = (Harvest Weight × Sale Price) - Total Expenses
- [ ] Spot-check: Inventory deductions, feed costs, other expenses included
- **Expected**: Profit matches manual calculation

**Status to File**: Mark ✅ when harvest + new cycle completes

---

### BLOCKER #9: Supplement Integration (Timeline & Quick-Apply)

**Test: Supplements Visible in Timeline**
- [ ] Log supplement use: e.g., "Pro Yeast 500g applied"
- [ ] Check daily timeline/calendar view
- [ ] Verify: Supplement appears on correct date
- [ ] Verify: Category/brand shown
- **Expected**: Supplements displayed alongside feed, harvest events

**Test: Quick-Apply Functionality**
- [ ] Open recommended supplement in timeline
- [ ] Tap "Quick Apply" button
- [ ] Verify: Quantity pre-filled from recommendation
- [ ] Tap "Confirm"
- [ ] Verify: Logged to database
- [ ] Verify: Timeline updates immediately
- **Expected**: Quick-apply reduces friction for recommended supplements

**Test: Active/Expired Filtering**
- [ ] Filter timeline: "Active Supplements Only"
- [ ] Verify: Expired supplements hidden
- [ ] Filter: "All Supplements"
- [ ] Verify: Expired items shown with strikethrough
- **Expected**: Clear visual hierarchy for supplement status

**Status to File**: Mark ✅ when timeline integration verified

---

### BLOCKER #10: Offline Mode

**Test: Offline Feed Marking**
- [ ] Go offline (airplane mode or DevTools)
- [ ] Open pond dashboard
- [ ] Mark round complete
- [ ] Verify: Feed saved to local SharedPreferences
- [ ] Turn network back on
- [ ] Wait 5 seconds
- [ ] Verify: Data synced to Supabase
- **Expected**: Seamless offline-first experience

**Test: Offline Data Visibility**
- [ ] Offline: Open existing pond
- [ ] Verify: Previous data visible (cached)
- [ ] Verify: Can edit locally
- **Expected**: App functional without network

**Test: Offline Conflict Resolution**
- [ ] Go offline, edit round A to 10kg
- [ ] Go online, same round edited server-side to 12kg
- [ ] Verify: Last-write-wins or conflicts handled gracefully
- **Expected**: No data loss, consistent state

**Status to File**: Mark ✅ when offline flow works end-to-end

---

### BLOCKER #11: Language Switching (Tamil/Telugu)

**Test: UI Rendering**
- [ ] Settings → Language → Tamil
- [ ] Verify: All screens render in Tamil (no broken text, no missing characters)
- [ ] Check: Numbers, decimals render correctly in Tamil locale
- [ ] Switch to Telugu: Same checks
- [ ] Switch back to English
- **Expected**: All languages render cleanly, no layout breaks

**Test: Feed Calculations in Different Languages**
- [ ] Feed recommendation shown in Tamil: "12.5 kg" should display correctly
- [ ] Verify: Decimal separators appropriate for locale
- **Expected**: Numbers localized, calculations consistent across languages

**Status to File**: Mark ✅ when all languages render correctly

---

### BLOCKER #12: Subscription Gate Debug Override

**Test: QA Can Toggle FREE/PRO**
- [ ] Open Settings
- [ ] Tap "Debug Menu" (or Settings → Developer)
- [ ] Tap "DEBUG: Set to PRO"
- [ ] Verify: Features unlock (smart feed, tray corrections)
- [ ] Tap "DEBUG: Set to FREE"
- [ ] Verify: Features lock (paywall shown at DOC 31)
- [ ] Tap "DEBUG: Reset to Real Subscription"
- [ ] Verify: Real subscription state restored
- **Expected**: QA can override for testing without actual purchase

**Status to File**: Mark ✅ when debug menu works

---

### BLOCKER #13: Security Audit (RLS Policies)

**Test: Farm Data Isolation**
- [ ] User A: Create farm + 5 ponds
- [ ] User B: Try to query User A's ponds via API
- [ ] Verify: Access denied (403 Forbidden)
- **Expected**: RLS policies enforce user-level isolation

**Test: Farm Members RLS**
- [ ] User A: Create farm, add members
- [ ] User B: Try to query User A's members via API
- [ ] Verify: Access denied
- **Expected**: Members list hidden from other users

**Test: Inventory & Expenses (Multi-User)**
- [ ] User A: Log inventory purchase
- [ ] User B: Cannot see User A's inventory or expenses
- **Expected**: Financial data isolated per user/farm

**Status to File**: Mark ✅ when RLS isolation verified

---

### BLOCKER #14: Load Testing (Performance)

**Test: 5–10 Ponds, 100+ Days History**
- [ ] Create 5–10 ponds in test farm
- [ ] Each pond: 80+ days of feed logs
- [ ] Open pond dashboard
- [ ] Verify: Loads in < 2 seconds
- [ ] Scroll timeline: Smooth (no lag)
- [ ] Switch between ponds: Responsive
- **Expected**: Performance acceptable for production

**Test: Large Feed History**
- [ ] Pond with 500+ feed_logs entries
- [ ] Load history view
- [ ] Verify: Paginated or lazy-loaded (not all at once)
- [ ] Scroll through: Smooth
- **Expected**: No UI freezes

**Status to File**: Mark ✅ when performance targets met

---

## 📋 FINAL SIGN-OFF

| Item | Status | Sign-off |
|------|--------|----------|
| Product Master Data | ✅ | Verified |
| Feed Brand Persistence | ✅ | Fixed (be2cf1d) |
| Circular Dependency | ✅ | Verified (0ace555) |
| FeedDayPlan Crash | ✅ | Verified (274c9aa) |
| Feature Gating | 🔲 | **Pending** |
| Feed Atomicity | 🔲 | **Pending** |
| Feed Schedule Gen | 🔲 | **Pending** |
| Roles Feature | 🔲 | **Pending** |
| Harvest Flow | 🔲 | **Pending** |
| Supplement Integration | 🔲 | **Pending** |
| Offline Mode | 🔲 | **Pending** |
| Language Switching | 🔲 | **Pending** |
| Debug Override | 🔲 | **Pending** |
| Security (RLS) | 🔲 | **Pending** |
| Load Testing | 🔲 | **Pending** |

**Launch Criteria**: All 15 items = ✅

---

## 🚀 Launch Steps

Once all tests pass:
1. Create signed APK build
2. Distribute to 20 farmers with this checklist
3. Collect feedback during first week
4. Critical bugs: Hotfix immediately
5. Minor issues: Queue for next release

**Estimated Timeline**: 2–3 days of focused QA testing
