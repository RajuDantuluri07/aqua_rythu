# 🚨 Feed System Stability Test Plan

## Overview
This document outlines the manual test cases to verify the critical fixes implemented for feed system stability. Each test case validates specific acceptance criteria from the original issue.

## 🧪 Test Cases

### Test Case 1: Double Tap "Feed Done" 
**Goal**: Verify same feed cannot be logged twice
**Expected**: Only 1 entry created

#### Steps:
1. Open the app and select a pond
2. Navigate to current feed round (should show "Confirm Feed" button)
3. Quickly double-tap the "Confirm Feed" button
4. Wait for the operation to complete
5. Check the database for duplicate entries

#### Verification:
- ✅ Button should show "Saving..." state during operation
- ✅ Only one feed_logs entry should exist for (pond_id, doc, round)
- ✅ UI should not crash or show inconsistent state
- ✅ Check logs: "Feed transaction completed successfully" (not duplicate error)

#### Database Query:
```sql
SELECT COUNT(*) as duplicate_count 
FROM feed_logs 
WHERE pond_id = 'YOUR_POND_ID' 
AND doc = CURRENT_DOC 
AND round = CURRENT_ROUND;
```

---

### Test Case 2: Kill App During Feed Logging
**Goal**: Verify no partial data on app termination
**Expected**: No partial data, system remains consistent

#### Steps:
1. Start a feed operation by tapping "Confirm Feed"
2. Immediately kill the app (force close) while "Saving..." is showing
3. Restart the app
4. Check the pond dashboard and database state

#### Verification:
- ✅ Either: Complete feed entry exists (transaction succeeded)
- ✅ Or: No feed entry exists (transaction failed completely)
- ✅ No partial/inconsistent state
- ✅ UI shows correct round status (either completed or pending)
- ✅ Check feed_rounds and feed_logs tables for consistency

#### Database Queries:
```sql
-- Check for partial data
SELECT * FROM feed_rounds WHERE pond_id = 'YOUR_POND_ID' AND doc = CURRENT_DOC AND round = CURRENT_ROUND;
SELECT * FROM feed_logs WHERE pond_id = 'YOUR_POND_ID' AND doc = CURRENT_DOC AND round = CURRENT_ROUND;
-- Both should either both exist or both not exist
```

---

### Test Case 3: Log Feed → Check Next Round
**Goal**: Verify updated recommendation visible immediately
**Expected**: Updated recommendation visible

#### Steps:
1. Complete a feed round successfully
2. Immediately navigate to or check the next round
3. Verify the feed recommendation reflects the latest calculation

#### Verification:
- ✅ Next round shows updated feed amounts
- ✅ No stale data from previous calculation
- ✅ Smart feed adjustments (if applicable) are visible
- ✅ Cumulative feed totals are accurate
- ✅ Check logs: "Feed transaction completed successfully" followed by cache invalidation

#### Verification Points:
- Feed amounts should change based on tray data (if logged)
- Cumulative feed should be calculated from database SUM
- Engine should have run after DB update (check logs)

---

### Test Case 4: Log 3 Feeds in a Day
**Goal**: Verify cumulative feed is always accurate
**Expected**: Cumulative correct

#### Steps:
1. Log 3 different feed rounds in the same day
2. After each feed, check the cumulative total
3. Verify against manual calculation

#### Verification:
- ✅ After each feed: cumulative = sum of all feeds for the day
- ✅ Cumulative calculated from database (not index-based)
- ✅ No double-counting or missing feeds
- ✅ Feed history shows correct daily totals

#### Database Verification:
```sql
SELECT doc, feed_given, created_at 
FROM feed_logs 
WHERE pond_id = 'YOUR_POND_ID' 
AND DATE(created_at) = CURRENT_DATE 
ORDER BY created_at;

-- Manual cumulative check
SELECT SUM(feed_given) as total_cumulative 
FROM feed_logs 
WHERE pond_id = 'YOUR_POND_ID' 
AND DATE(created_at) <= CURRENT_DATE;
```

---

## 🔍 Additional Verification Points

### Database Constraints
```sql
-- Verify unique constraint exists
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'feed_logs'::regclass 
AND conname = 'feed_logs_unique_pond_doc_round';
```

### Transaction Functions
```sql
-- Verify transaction function exists
SELECT proname 
FROM pg_proc 
WHERE proname = 'complete_feed_round_with_log';
```

### Cache Invalidation
Check app logs for these messages after each operation:
- "Controller: Invalidated cache for pond=..."
- "Feed transaction completed successfully for pond..."

### Error Handling
1. Test network failure during feed logging
2. Verify UI reverts to original state
3. Check error messages are user-friendly

---

## 📊 Test Results Template

| Test Case | Status | Issues Found | Date Tested | Tester |
|-----------|--------|--------------|--------------|--------|
| Double Tap Feed | ⬜ | | | |
| Kill App During Feed | ⬜ | | | |
| Log Feed → Next Round | ⬜ | | | |
| 3 Feeds Cumulative | ⬜ | | | |

---

## 🚨 Critical Success Indicators

1. **No Duplicate Entries**: Database unique constraint prevents duplicates
2. **Atomic Operations**: Either complete success or complete failure
3. **Real-time Updates**: UI reflects changes immediately
4. **Data Consistency**: Cumulative always matches database SUM
5. **Error Recovery**: UI reverts on failures, no broken states

---

## 🔧 Troubleshooting Common Issues

### Issue: Duplicate feed entries
**Check**: Unique constraint applied correctly
**Fix**: Run migration: `add_feed_logs_unique_constraint.sql`

### Issue: Stale feed recommendations
**Check**: Cache invalidation in logs
**Fix**: Verify controller.invalidate() is called

### Issue: Wrong cumulative totals
**Check**: Database vs in-memory calculation
**Fix**: Ensure _getCumulativeFeedFromDB is being used

### Issue: UI not reverting on error
**Check**: Error handling with try-catch blocks
**Fix**: Verify original state is stored and reverted

---

## 📝 Notes for Testers

- Always check both UI state and database state
- Look for error messages in app logs
- Test with both stable and unstable network conditions
- Verify across different DOC ranges (starter, guided, smart modes)
- Test with and without tray data logging
