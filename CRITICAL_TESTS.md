# 🧪 CRITICAL TEST CASES - Feed Completion Atomicity

## P0 Test: Double Tap + Slow Network (MUST PASS)

**Scenario**: User taps "Mark Complete" 3 times rapidly while network is slow

**Setup**:
```dart
// Simulate slow network in DevTools
// Chrome DevTools → Network → Add custom throttling
// Set to: 2G (5000ms latency)
```

**Steps**:
1. Load pond dashboard
2. View Round 4 status (should be "pending")
3. **Tap "Mark Complete" button 3 times rapidly** (no waiting between taps)
4. Wait 30 seconds for network to complete
5. App should NOT crash

**Expected Results** ✅:

| Metric | Value |
|--------|-------|
| **UI State** | Round 4 shows "completed" |
| **feed_logs entries** | **EXACTLY 1** |
| **feed_rounds.status** | `'completed'` |
| **consumedFeed** | Correct (not doubled/tripled) |
| **Dart logs** | See "already completed" messages for taps 2 & 3 |
| **Database consistency** | No duplicates, no partial states |
| **No errors** | App doesn't crash or show errors |

**How to Verify**:

### Step 1: Check Dart Logs
```
✅ Feed completion transaction atomic: pond X round 4
⚠️  Round already completed (idempotent): pond X doc N round 4
⚠️  Round already completed (idempotent): pond X doc N round 4
```

### Step 2: Check feed_logs Table
```sql
SELECT COUNT(*), pond_id, doc, round, DATE(created_at)
FROM feed_logs
WHERE pond_id = 'X' AND doc = N AND round = 4
GROUP BY pond_id, doc, round, DATE(created_at);

-- Result should be: count = 1 (not 3)
```

### Step 3: Check feed_rounds Table
```sql
SELECT id, status, updated_at
FROM feed_rounds
WHERE pond_id = 'X' AND doc = N AND round = 4;

-- Result: status = 'completed'
```

### Step 4: Verify consumedFeed
```sql
SELECT SUM(feed_given) as total_fed
FROM feed_logs
WHERE pond_id = 'X' AND DATE(created_at) = TODAY;

-- Should match consumedFeed shown in UI
```

### Step 5: Check UNIQUE Constraint
```sql
-- Verify constraint exists
\d+ feed_logs

-- Look for: uq_feed_logs_pond_doc_round_date UNIQUE
```

---

## P1 Test: Network Failure During RPC (MUST PASS)

**Scenario**: Network fails while RPC is executing

**Setup**:
1. Start with pending round
2. Enable network throttling (offline after 2 seconds)

**Steps**:
1. Tap "Mark Complete"
2. After 2 seconds, turn off network (DevTools → Network → Offline)
3. Wait 10 seconds
4. Turn network back online
5. Wait for response

**Expected Results** ✅:

| Case | Result |
|------|--------|
| **RPC fully committed** | Status = completed, Feed logged ✅ |
| **RPC halfway failed** | Automatic rollback, status = pending, NO feed log ✅ |
| **RPC never sent** | Status = pending, NO feed log ✅ |

**Never**: Partial state (log without status, or vice versa)

---

## P1 Test: Refresh After Completion (MUST PASS)

**Scenario**: Complete a round, then refresh the app

**Steps**:
1. Mark Round 2 as complete
2. Verify UI shows "completed"
3. Force refresh (CMD+R or flutter hot reload)
4. Wait for data to reload

**Expected Results** ✅:
- Round 2 still shows "completed" (NOT reverted to pending)
- consumedFeed matches before refresh
- feed_logs entry still exists
- feed_rounds.status still = 'completed'

---

## P1 Test: Engine Recompute (MUST PASS)

**Scenario**: Complete all rounds, then trigger feed engine recompute

**Steps**:
1. Complete Rounds 1, 2, 3, 4
2. Verify all show "completed"
3. Trigger feed engine recompute (via UI button or mortality update)
4. Wait for engine calculation

**Expected Results** ✅:
- Rounds STAY "completed" (not reset to "pending")
- consumedFeed does NOT reset
- feed_logs entries NOT deleted
- Engine can calculate without overwriting statuses

---

## P1 Test: Kill App + Restart (MUST PASS)

**Scenario**: Complete rounds, force quit app, restart

**Steps**:
1. Mark Rounds 1, 2 as complete
2. Verify consumedFeed = sum of logged rounds
3. **Force kill app** (don't just close)
4. Reopen app
5. Navigate to same pond

**Expected Results** ✅:
- Rounds 1, 2 still show "completed"
- consumedFeed matches pre-kill value
- feed_logs entries exist in database
- feed_rounds.status still = 'completed'

---

## Test Failure Diagnostics

If any test FAILS, check:

### 1. Check RPC Function Definition
```sql
-- Verify function has correct signature
SELECT routine_name, data_type FROM information_schema.routines
WHERE routine_name = 'complete_feed_round_with_log';
```

### 2. Check Migrations Applied
```sql
-- List all feed-related migrations
SELECT name FROM supabase.migrations
WHERE name LIKE '%feed%'
ORDER BY created_at DESC;
```

### 3. Check UNIQUE Constraint
```sql
-- Verify constraint exists and is active
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'feed_logs'
AND constraint_type = 'UNIQUE';
```

### 4. Check feed_logs Content
```sql
-- Look for duplicates
SELECT pond_id, doc, round, DATE(created_at), COUNT(*)
FROM feed_logs
GROUP BY pond_id, doc, round, DATE(created_at)
HAVING COUNT(*) > 1;

-- Should return NO ROWS
```

### 5. Dart Validation
- Check IDE console for RPC response parsing errors
- Look for "RPC returned invalid response type" messages
- Verify `rpcResponse['success']` is a boolean

---

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Double tap test passes | ✅ |
| No duplicate feed_logs | ✅ |
| consumedFeed never resets | ✅ |
| UNIQUE constraint prevents duplicates | ✅ |
| RPC returns structured JSON | ✅ |
| Dart validates response | ✅ |
| App doesn't crash on network failure | ✅ |
| Rounds persist across restart | ✅ |
| Engine recompute doesn't reset state | ✅ |

---

## Key Safeguards Implemented

### 1. Database Level
- **UNIQUE constraint**: `(pond_id, doc, round, DATE(created_at))`
- Prevents duplicate inserts at DB level
- Survives application crashes

### 2. RPC Level
- **Atomic transaction**: Feed round update + feed log insert = all or nothing
- **Idempotency check**: If already completed, return success (no action)
- **Structured response**: JSON with success/error/details

### 3. Application Level
- **RPC validation**: Parse and check response structure
- **Error handling**: Explicit success check before proceeding
- **State reload**: Always reload from DB (SSOT) after RPC

### 4. Data Integrity
- **consumedFeed**: Calculated from feed_logs only (never from status)
- **feed_rounds.status**: Used for UI state only
- **Single source of truth**: feed_logs = financial reality

---

## Testing Automation

**Future: Add Cypress tests for UI scenarios**
```javascript
// Pseudo-code example
describe('Feed Completion - Double Tap + Slow Network', () => {
  it('should handle rapid clicks idempotently', () => {
    cy.throttle('slow-4g');
    cy.get('[data-testid="mark-complete-btn"]')
      .click()
      .click()
      .click();  // 3 rapid clicks
    cy.wait('@completeRound');
    cy.get('[data-testid="round-status"]').should('contain', 'completed');
    // Check DB for exactly 1 log entry
  });
});
```

---

## Owner & Timeline

- **Owner**: QA Team
- **Timeline**: Before production release
- **Blocker**: P0 - Cannot ship without all tests passing
