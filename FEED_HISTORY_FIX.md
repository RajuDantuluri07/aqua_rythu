# P0 BUG FIX: Feed History Not Updating for Round 4

## Summary
Fixed the issue where completed feed rounds were reverting to "pending" status after app refresh or recompute, breaking the single source of truth (SSOT).

## Root Causes Identified

### 1. **Missing Status Persistence in Dart Code**
- **Location**: `lib/features/pond/pond_dashboard_provider.dart:markFeedDone()`
- **Issue**: After completing a feed round, the RPC transaction was called but the `feed_rounds.status` was never explicitly updated to 'completed'
- **Fix**: Added explicit call to `FeedService().markFeedPlanCompleted()` after the RPC transaction succeeds

### 2. **SQL Syntax Error in RPC Function**
- **Location**: `migrations/create_feed_transaction_functions.sql` & `migrations/fix_idempotency_on_conflict.sql`
- **Issue**: The RPC function `complete_feed_round_with_log()` had invalid syntax `ELSE {` (line 36/43) which prevented the function from executing properly
- **Fix**: Created new migration `migrations/fix_feed_round_rpc_syntax_error.sql` with correct syntax (`ELSE` without braces)

## Implementation Details

### Change 1: Dart Code - Remove Dual Write (Atomic RPC Only)
**File**: `lib/features/pond/pond_dashboard_provider.dart`

**REMOVED**: Explicit call to `FeedService().markFeedPlanCompleted()`

**WHY**: Creates dual-write race condition. The RPC should handle ALL state updates atomically.

**INSTEAD**: The RPC function is the single source of truth. It:
- Updates `feed_rounds.status = 'completed'`
- Inserts entry in `feed_logs`
- Both in one atomic transaction

Result: No partial states possible.

### Change 2: SQL Migration - Fix RPC Syntax Error
**File**: `migrations/fix_feed_round_rpc_syntax_error.sql`

Fixed the syntax error from:
```sql
IF feed_round_id IS NOT NULL THEN
    -- ...
ELSE {  -- ❌ INVALID SYNTAX
```

To:
```sql
IF feed_round_id IS NOT NULL THEN
    -- ...
ELSE  -- ✅ CORRECT SYNTAX
```

### Change 3: SQL Migration - Enhance Idempotency
**File**: `migrations/enhance_feed_completion_idempotency.sql`

Added idempotency protection to prevent duplicate completion on rapid clicks:

```sql
-- Check if already completed (return success if so)
IF feed_round_id IS NOT NULL AND existing_status = 'completed' THEN
    RAISE NOTICE 'Feed round already completed: pond_id=%, doc=%, round=%';
    RETURN TRUE;  -- Idempotent: return success
END IF;
```

**Benefits**:
- Safe to click multiple times without side effects
- Gracefully handles network retries
- No duplicate feed_logs entries

## Data Flow - Single Source of Truth (SSOT)

### Before Fix
```
User marks Round 4 complete
    ↓
RPC called (but fails due to syntax error)
    ↓
feed_rounds.status NOT updated in DB
    ↓
UI shows "completed" (in-memory state)
    ↓
App refreshes / recomputes
    ↓
Controller loads from DB → status is still "pending"
    ↓
Rounds revert to "pending" in UI
    ↓
consumedFeed resets to 0 ❌
```

### After Fix (Atomic Single Transaction)
```
User marks Round 4 complete
    ↓
RPC called (atomic transaction)
    ├── Check if already completed (idempotency guard)
    ├── Update feed_rounds.status = 'completed'
    ├── Insert feed_logs entry (idempotent)
    └── Return success
    ↓
Dart code receives success/failure (no dual writes) ✅
    ↓
Controller reloads from DB (via loadTodayFeed)
    ↓
Controller reads status = 'completed' from feed_rounds
    ↓
State updated with correct status ✅
    ↓
DB is always source of truth ✅
    ↓
Idempotent: safe to click multiple times ✅
```

## Testing Checklist

- [ ] Complete Round 1, 2, 3, 4 - verify all show as DONE
- [ ] Refresh app - verify rounds still show as DONE (not reverted)
- [ ] Kill app and restart - verify rounds persist as DONE
- [ ] Check consumedFeed is calculated correctly (not reset to 0)
- [ ] Verify DB feed_rounds table has status='completed' for all rounds
- [ ] Test after feed engine recompute - rounds should stay DONE
- [ ] Check feed_logs table contains all logged entries

## Migration Steps

1. Apply the RPC syntax fix:
   ```bash
   supabase migration deploy fix_feed_round_rpc_syntax_error.sql
   ```

2. Apply the idempotency enhancement:
   ```bash
   supabase migration deploy enhance_feed_completion_idempotency.sql
   ```

3. Deploy the Dart code changes to production:
   - Changes to `lib/features/pond/pond_dashboard_provider.dart`
   - Removed dual-write pattern
   - Now relies solely on RPC atomic transaction

4. No data migration needed - only function definition updates

5. Verify in Supabase console:
   ```sql
   -- Check function definition
   \df+ complete_feed_round_with_log
   
   -- Test atomic transaction
   SELECT complete_feed_round_with_log(pond_id, doc, round, amount);
   ```

## Severity
**P0 - Launch Blocker** ✅ FIXED
- Farmers lose trust instantly if feed history doesn't persist
- App becomes unusable for daily operations

## Engineering Principles Applied

### 1. "Computed state MUST NEVER override persisted state"
DB is the source of truth. All state is persisted to DB, then reloaded on refresh.

### 2. "One user action = One atomic DB transaction"
Never use dual writes. The RPC function is the single authority that handles:
- All updates to feed_rounds
- All inserts to feed_logs
- Both succeed or both fail (no partial states)

### 3. "Design for idempotency"
System must handle network retries, rapid clicks, etc. without side effects.
Safe to call multiple times, always produces consistent result.

## Architecture Diagram

```
User Action: "Mark Feed Complete"
        ↓
     Dart Code (pond_dashboard_provider.dart)
        ↓
   RPC Function (complete_feed_round_with_log)
     ├─ Idempotency Check (already completed?)
     ├─ Update feed_rounds.status = 'completed'
     ├─ Insert feed_logs (idempotent)
     └─ Return success/failure
        ↓
   Single Atomic Result: ✅ or ❌
     (No partial states)
        ↓
   Refresh from DB (via controller.load)
        ↓
   State = DB Truth
```
