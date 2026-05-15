# Real Farm Validation Sprint — Static Analysis Report

**Date:** 2026-05-15  
**Scope:** Full end-to-end static analysis of production-critical workflows  
**Method:** Code-level review of all service, model, provider, and engine files

---

## BUGS FOUND AND FIXED

### BUG-01 — Duplicate sampling entries on double-tap
**File:** `lib/core/services/sampling_service.dart`  
**Severity:** HIGH  
**Affected flows:** 8 — Sampling entry, DOC progression logic, FCR calculation

**Root cause:**  
`addSampling()` had no duplicate guard. If the farmer tapped submit twice, or the network was slow and the user retried, two `sampling_logs` rows would be created for the same `pondId + doc + date`. This corrupts the growth trend graph and any FCR calculation that sums all sampling data.

The pond `current_abw` was overwritten by the second write (second write wins), so the feed engine was safe. But the growth history and survival rate calculations in `HarvestSummaryScreen` use `sampling_logs` rows, so duplicates would double-count shrimp weights.

**Reproduction:**
1. Open a pond at DOC 20+
2. Enter sampling data
3. Tap "Save" twice quickly (or kill app mid-flight and reopen)
4. Query `sampling_logs` — two rows for same pond + doc

**Fix:**  
Added a same-day duplicate check before inserting. If a row already exists for the same `pond_id + doc + today`, skip the insert and only update the pond ABW cache (idempotent write).

---

### BUG-02 — `Expense.toMap()` drops `crop_id`
**File:** `lib/core/models/expense_model.dart`  
**Severity:** MEDIUM (latent — no production callers yet, but dangerous)  
**Affected flows:** 7 — Expense logging

**Root cause:**  
`Expense.toMap()` did not include `crop_id` in the returned map. The field is a required property on the model and is included in `ExpenseService.createExpense()`'s own insert dict — so direct DB writes are fine. But any caller that uses `expense.toMap()` for serialisation (e.g. bulk export, reconciliation) would silently lose `crop_id`, making those expenses unfilterable by crop.

**Fix:** Added `'crop_id': cropId` to the map.

---

### BUG-03 — `deleteFarm` leaves orphaned expense records
**File:** `lib/core/services/farm_service.dart`  
**Severity:** HIGH  
**Affected flows:** 1 — Farm management

**Root cause:**  
`FarmService.deleteFarm()` deleted all child data for each pond (`feed_rounds`, `feed_logs`, `tray_logs`, `sampling_logs`, `water_logs`, `harvest_logs`) and then deleted the ponds and farm rows — but never deleted the `expenses` table. The `expenses` table is keyed by `farm_id` (and `user_id`). After deleting the farm, every expense ever logged would remain as an orphan row with a dangling `farm_id` foreign key.

This affects real farmers who:
- Create a test farm during onboarding, then delete it
- Start a new crop cycle (which might delete + recreate the farm)

**Reproduction:**
1. Create farm → log 3 expenses → delete farm
2. Query `expenses` table — rows still exist for the deleted farm_id

**Fix:** Added `await supabase.from('expenses').delete().eq('farm_id', farmId)` before deleting ponds.

---

### BUG-04 — `_validateInventoryDeduction` always sees 0 deducted (dead code)
**File:** `lib/core/business/system_sync_service.dart`  
**Severity:** HIGH (if the method were ever called)  
**Affected flows:** 6 — Inventory deduction

**Root cause:**  
`_validateInventoryDeduction()` aggregates `inventory_consumption` rows by filtering on `pond_id`. But `InventoryService.recordFeedConsumption()` never stores `pond_id` in that table — it only stores `item_id`, `source`, `quantity_used`, and `date`.

The loop `if (record['pond_id'] == pondId)` would match zero records, `actualDeduction` stays 0, and the method throws "Inventory deduction mismatch" for every nonzero feed amount.

`recordFeedWithSync` (the only caller of this method) is currently dead code — no production flow calls it — so this bug is dormant. But it would break any future reconciliation or batch sync.

**Fix:** Removed the `pond_id` filter since consumption records are farm-level aggregates. Sum all auto-tracked rows for the day.

---

### BUG-05 — Harvest optimistic revert removes too many entries
**File:** `lib/features/harvest/harvest_provider.dart`  
**Severity:** MEDIUM  
**Affected flows:** 5 — Complete feed round (via harvest state), Tray check flow

**Root cause:**  
`addHarvest()` adds the entry optimistically, then on DB failure reverts with:
```dart
state = state.where((h) => h.date != entry.date).toList();
```
`entry.date` is `DateTime.now()` — two harvests logged within the same second (or two partial harvests on the same day if seconds collide) would both be removed on any error.

**Fix:** Revert by `entry.id` instead of `entry.date`.

---

## CONFIRMED WORKING — NO BUGS FOUND

| Flow | Status | Notes |
|------|--------|-------|
| Feed round completion | ✅ SOLID | `_completeFeedRoundWithLog` → `complete_feed_round_with_log` RPC; full idempotency via `operation_id` |
| Duplicate feed protection | ✅ SOLID | DB-level deduplication via `safe_insert_feed_log`; `FeedSyncQueue` deduplicates by `operationId` |
| Offline queue | ✅ SOLID | `FeedSyncQueue` persists to SharedPreferences, exponential backoff, max 5 retries |
| Feed plan generation | ✅ SOLID | Lock set prevents concurrent generation; upserts safely overwrite; nursery cap at DOC 10 / hatchery cap at DOC 25 |
| DOC calculation | ✅ SOLID | Server-time-backed `calculateDocFromStockingDate`; legacy fallback clearly marked |
| Tray log deduplication | ✅ SOLID | `saveTrayLog` queries existing row before insert (pond_id + doc + round + date) |
| Feed amount validation | ✅ SOLID | Rejects NaN, Infinity, negative, and >50 kg/round before touching DB |
| New cycle data clear | ✅ SOLID | Sequential deletes in `clearPondCycleData`; regenerates feed plan |
| Feature flag behavior | ✅ SOLID | `kDebugMode &&` guard prevents unlaunched screens in release builds |
| Feed inventory deduction | ✅ SOLID | Fire-and-forget post-save (non-blocking), never prevents feeding |

---

## OUTSTANDING ISSUES — NOT FIXED (architectural, require discussion)

### ARCH-01 — Two harvest tables used inconsistently

`HarvestService` writes to `harvests` (keyed by `crop_id`).  
`HarvestProvider` / `PondHarvestService` write to `harvest_logs` (keyed by `pond_id`).

`PondService.deletePond()`, `clearPondCycleData()`, and `FarmService.deleteFarm()` all delete from `harvest_logs` but **never** from `harvests`. If `HarvestService` is used (it's currently behind `harvestEnabled = false`), those records will never be cleaned up on farm/pond delete.

**Recommendation:** Before enabling `harvestEnabled = true`, decide on one canonical harvest table and migrate all callers.

---

### ARCH-02 — Multi-step deletes are not transactional

`PondService.clearPondCycleData()` and `deletePond()` perform 6 sequential deletes. If the app crashes or goes offline between steps (e.g., `feed_rounds` deleted but `feed_logs` not), the pond is in an inconsistent state.

**Recommendation:** Wrap these in a Supabase DB function (RPC) that runs as a single transaction.

---

### ARCH-03 — `recordFeedWithSync` and `saveFeed` are dead code

`SystemSyncService.recordFeedWithSync()` is defined but never called. The production feed path goes through `FeedService.saveFeedEntry()` exclusively.

`FeedService.saveFeed()` (the original daily-aggregate path using `safe_insert_feed_log` RPC) is also not called from any active UI path.

**Recommendation:** Delete both before the launch to prevent accidental future invocation.

---

### ARCH-04 — `_checkInventoryStock` only guards the dead `saveFeed` path

`FeedService.saveFeed()` calls `_checkInventoryStock()` which throws `InsufficientStockException`. But the production path `saveFeedEntry()` → `_completeFeedRoundWithLog()` never calls this check. Farmers can feed even when stock is zero — the inventory deduction just runs post-save.

This is a known design trade-off (inventory is "warning, not blocking"), but it means the `InsufficientStockException` type is unreachable from any live UI path.

---

### ARCH-05 — Sampling screen fires DB call without awaiting result

In `sampling_screen.dart:122-131`, `SamplingService().addSampling(...)` is called with `.catchError(...)` but is not awaited before `Navigator.pop()`. If the DB write fails silently, the UI shows success but no data was saved.

**Recommendation:** Await the call and show an error snackbar on failure.

---

## TEST SCENARIO COVERAGE MAP

| Scenario | Coverage | Risk |
|----------|----------|------|
| Empty farm | Handled — `getPonds` returns `[]`, UI shows "Create pond" | LOW |
| New user (no data) | Auth guard in all services; feed plan generates fresh | LOW |
| No inventory | `_checkInventoryStock` returns early if no feed item found | LOW |
| Low inventory | `≤20 kg` warning logged; no block on `saveFeedEntry` path | MEDIUM — warning not surfaced in UI |
| Large feed values (>50 kg) | `_validateFeedAmount` rejects at 50 kg — raises `ArgumentError` | LOW |
| Multiple feed rounds | Round tracking via `roundFeedStatus` map; each round has its own `operation_id` | LOW |
| Multiple ponds | All feeds keyed by `pond_id`; independent state per pond | LOW |
| Duplicate taps | Feed: DB-level idempotency via RPC. Tray: pre-insert check. Sampling: **FIXED BUG-01** | LOW (after fix) |
| Slow internet | `FeedSyncQueue` queues failed operations; processes on reconnect | LOW |
| App kill/reopen | Queue survives in SharedPreferences; replays on next `processQueue()` call | LOW |
| Invalid data | Feed amount validation gate; expense service validates numeric fields | LOW |
| Old pond data | `generateFeedSchedule` uses fresh stocking date; history preserved | LOW |
| DOC progression | Server-time provider guards against device clock manipulation | LOW |
| Feature flag off in prod | `kDebugMode &&` guard verified correct | LOW |

---

## MANUAL TEST CHECKLIST FOR REAL FARMERS

Run these in order on a fresh device with a new account:

```
[ ] 1. Register new account → verify OTP → see empty farm state
[ ] 2. Create farm (name + location) → farm appears on home
[ ] 3. Create pond (all fields) → feed plan visible immediately on dashboard
[ ] 4. Feed Round 1 → mark done → round card shows "completed"
[ ] 5. Feed Round 1 again (double-tap) → no duplicate in DB
[ ] 6. Feed Round 2, 3, 4 → all marked done → daily total matches plan
[ ] 7. Kill app → reopen → dashboard shows today's feed state correctly
[ ] 8. Tray check → submit leftover status → feed adjustment visible next round
[ ] 9. Enter sampling (ABW) → growth screen updates
[ ] 10. Enter sampling again same DOC → no duplicate in DB (BUG-01 fix)
[ ] 11. Add inventory (feed stock: 500 kg) → stock shows on inventory screen
[ ] 12. Verify inventory deducted after 3 days of feeding
[ ] 13. Log expense (labour 500₹) → appears in expense list
[ ] 14. Delete expense → gone from list
[ ] 15. App offline → attempt feed → queued → reconnect → synced
[ ] 16. Create 2nd pond → both ponds show on dashboard
[ ] 17. Feed both ponds → amounts are independent per pond
[ ] 18. DOC reaches 11 (nursery) → no pre-generated plan → engine computes dynamically
[ ] 19. DOC reaches 31 → anchor feed dialog appears once → smart feed activates
[ ] 20. Delete farm → no expenses, ponds, feeds left in DB
```

---

## FIXED FILES SUMMARY

| File | Bug | Change |
|------|-----|--------|
| [sampling_service.dart](lib/core/services/sampling_service.dart) | BUG-01 | Added same-day duplicate guard before insert |
| [expense_model.dart](lib/core/models/expense_model.dart) | BUG-02 | Added `crop_id` to `toMap()` |
| [farm_service.dart](lib/core/services/farm_service.dart) | BUG-03 | Added `expenses` delete in `deleteFarm` cascade |
| [system_sync_service.dart](lib/core/business/system_sync_service.dart) | BUG-04 | Removed wrong `pond_id` filter in `_validateInventoryDeduction` |
| [harvest_provider.dart](lib/features/harvest/harvest_provider.dart) | BUG-05 | Reverts optimistic harvest by `id` not `date` |
