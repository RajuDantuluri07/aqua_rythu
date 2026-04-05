# Database ↔ Flutter Gap Analysis
**Generated:** 2026-04-05  
**Severity:** 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low

---

## EXECUTIVE SUMMARY

The database has **12 tables** and **2 functions**. After cross-referencing every table, column, RLS policy, and RPC against the Flutter source code, I found:

- **1 root-level architectural bug** that breaks the entire feed flow on pond creation
- **6 columns the app writes to that don't exist** in the database
- **4 columns the app reads that don't exist** in the database  
- **7 tables with zero RLS** — any user can read/write any other user's data
- **3 tables the database has that Flutter never uses**
- **3 features fully built in Flutter but writing to the wrong table / no table**

---

## 🔴 CRITICAL BUG #1 — The Feed Plan Table Mismatch (Root Cause of Feed Issues)

**This is the single biggest bug in the system. Every other feed fix is a symptom of this.**

### What happens on pond creation:
```
Flutter calls: supabase.rpc('create_pond_with_feed_plan', ...)
    └─► RPC creates pond ✅
    └─► RPC inserts 120 rows into → feed_plans ❌
    
Flutter dashboard calls: PondService.getTodayFeed()
    └─► Reads from → feed_rounds ❌ (EMPTY — nothing was inserted here by RPC)
    └─► Returns [] (empty)
    └─► Triggers auto-recovery → generateFeedSchedule()
        └─► Inserts FLAT 2.5 kg rows into feed_rounds (ignores base rates)
```

**The RPC inserts into `feed_plans`. The app reads from `feed_rounds`. These are two completely different tables.**

The scientifically-calculated feed plan (from `feed_base_rates`, scaled by area and seed count) is stored in `feed_plans` but **never read by the app**. The app always ends up on the flat 2.5 kg fallback.

### Fix required:
**Option A (recommended):** Change `getTodayFeed()` and all feed reads in Flutter to query `feed_plans` instead of `feed_rounds`.

**Option B:** Rewrite the RPC to insert into `feed_rounds` instead of `feed_plans`.

---

## 🔴 CRITICAL BUG #2 — Round Distribution Mismatch

**The RPC and Flutter use different round split percentages.**

| Round | RPC (Database) | Flutter `feed_plan_constants.dart` |
|---|---|---|
| Round 1 | 25% | 25% |
| Round 2 | 25% | 25% |
| Round 3 | **30%** | **25%** |
| Round 4 | **20%** | **25%** |

The database gives Round 3 more feed than Round 4. Flutter treats all rounds as equal. Even if you fix Bug #1, the amounts will differ.

**Fix:** Align both to the same distribution. Update `feed_plan_constants.dart` or update the RPC.

---

## 🔴 CRITICAL BUG #3 — `feed_history_logs` Table Does Not Exist

Flutter's `FeedService.saveFeed()` writes to a table called `feed_history_logs`:
```dart
// feed_service.dart line 14
await supabase.from('feed_history_logs').insert({...});
```

**This table does not exist in the database.** The database has `feed_logs` (which stores tray readings per session). Every `markFeedDone()` call tries to write to a non-existent table and silently fails.

**Fix:** Either rename the DB table to `feed_history_logs` or update the Flutter code to write to `feed_logs`.

---

## 🔴 CRITICAL BUG #4 — Missing Columns Flutter Writes To

### `feed_rounds` table — missing columns

Flutter's `FeedService.markFeedPlanCompleted()` does:
```dart
.update({'status': 'completed', 'updated_at': DateTime.now().toIso8601String()})
```

Flutter's `FeedService.overrideFeedAmount()` does:
```dart
.update({'planned_amount': ..., 'is_manual': true, 'updated_at': ...})
```

**`updated_at` and `is_manual` do NOT exist in `feed_rounds`.**

| Column | Exists in `feed_rounds`? |
|---|---|
| `id` | ✅ |
| `pond_id` | ✅ |
| `doc` | ✅ |
| `round` | ✅ |
| `planned_amount` | ✅ |
| `status` | ✅ |
| `created_at` | ✅ |
| `updated_at` | ❌ MISSING |
| `is_manual` | ❌ MISSING |
| `feed_type` | ❌ MISSING |
| `actual_amount` | ❌ MISSING |

### `ponds` table — missing columns

Flutter's `PondService.getPonds()` selects:
```dart
.select('id, name, area, stocking_date, seed_count, pl_size, num_trays, status, current_abw, is_smart_feed_enabled')
```

Flutter's `PondService.updateSmartFeedStatus()` updates `is_smart_feed_enabled`.

| Column | Exists in `ponds`? |
|---|---|
| `status` | ❌ MISSING |
| `current_abw` | ❌ MISSING |
| `is_smart_feed_enabled` | ❌ MISSING |

Also: `ponds` has **both** `trays` and `num_trays` — one is a duplicate. Flutter uses `num_trays`.

---

## 🔴 CRITICAL BUG #5 — `water_logs` Is Severely Under-Schemed

Flutter's `WaterLog` model (and `WaterTestScreen`) captures:

| Field | In Flutter Model | In `water_logs` table |
|---|---|---|
| `ph` | ✅ | ✅ |
| `dissolved_oxygen` | ✅ | ✅ |
| `salinity` | ✅ | ✅ |
| `temperature` | ✅ | ✅ |
| `ammonia` | ✅ | ❌ MISSING |
| `nitrite` | ✅ | ❌ MISSING |
| `alkalinity` | ✅ | ❌ MISSING |
| `doc` | ✅ | ❌ MISSING |
| `pond_id` | ✅ | ✅ |

**3 of the most critical water quality parameters (`ammonia`, `nitrite`, `alkalinity`) cannot be saved.** The health score calculation uses all 6 parameters — it will always calculate as if ammonia/nitrite/alkalinity are fine.

Also: `water_logs` has NO RLS. Any user can read/write any pond's water quality data.

---

## 🟠 HIGH — `harvest_logs` Schema is Incomplete

Flutter's `HarvestEntry` model vs database:

| Field | In Flutter | In `harvest_logs` |
|---|---|---|
| `pond_id` | ✅ | ✅ |
| `harvest_type` (type) | ✅ | ✅ (named `harvest_type`) |
| `quantity` | ✅ | ✅ |
| `price` | pricePerKg | ✅ (named `price`) |
| `doc` | ✅ | ❌ MISSING |
| `date` | ✅ | ❌ MISSING |
| `count_per_kg` | ✅ | ❌ MISSING |
| `expenses` | ✅ | ❌ MISSING |
| `notes` | ✅ | ❌ MISSING |

Harvest data is currently stored **in-memory only** in Flutter. Even if someone wired it to the DB, 5 of the fields would fail.

---

## 🟠 HIGH — `supplement_logs` Schema is Severely Mismatched

The DB `supplement_logs` table has only: `id, pond_id, name, quantity, notes, created_at`

Flutter's supplement log system tracks:
- `supplement_type` (feedMix / waterMix)
- `feed_round` (which round: 1-4)
- `items` (JSON array of applied items with name/quantity/unit)
- `scheduled_time` (HH:mm string)
- `scheduled_at` (timestamp)
- `input_value` / `input_unit` (kg of feed or acres of pond)
- `supplement_name`
- `supplement_id`

The supplement log provider is in-memory only. The DB table schema cannot support the data Flutter tracks even when wired up.

---

## 🟠 HIGH — `sampling_logs` Missing `doc` Column

Flutter's growth sampling captures DOC at the time of sampling — critical for growth curve analysis. The `sampling_logs` table is missing `doc`.

| Field | In Flutter | In `sampling_logs` |
|---|---|---|
| `pond_id` | ✅ | ✅ |
| `avg_weight` | ✅ | ✅ |
| `count` | ✅ | ✅ |
| `notes` | ✅ | ✅ |
| `doc` | ✅ | ❌ MISSING |

Growth logs are in-memory only. When wired to DB, DOC won't be captured.

---

## 🟠 HIGH — RLS Security Gaps

### Tables with NO RLS policies (any user can read/write any other user's data):

| Table | Has RLS? | Risk |
|---|---|---|
| `feed_logs` | ❌ No policies | Any user reads any pond's feed logs |
| `feed_plans` | ❌ No policies | Any user modifies any pond's feed plan |
| `feed_sessions` | ❌ No policies | Any user reads/writes sessions |
| `harvest_logs` | ❌ No policies | Any user reads harvest data |
| `sampling_logs` | ❌ No policies | Any user reads sampling data |
| `supplement_logs` | ❌ No policies | Any user reads supplement data |
| `water_logs` | ❌ No policies | Any user reads water quality data |

### `feed_rounds` — Wide Open RLS:
```sql
-- Current policies:
SELECT: WHERE true   -- Every authenticated user sees ALL ponds' feed rounds
INSERT: WITH CHECK true  -- Every authenticated user can insert into any pond
```
There is no UPDATE or DELETE policy on `feed_rounds` at all, meaning those operations may be blocked by default or rely on no-RLS fallback.

### Tables with correct RLS:
- `farms` ✅ — user_id = auth.uid()
- `ponds` ✅ — via farm ownership join
- `profiles` ✅ — id = auth.uid()

---

## 🟡 MEDIUM — Unused Tables (DB has them, Flutter ignores them)

| Table | Columns | What it appears to be for | Flutter uses it? |
|---|---|---|---|
| `feed_logs` | pond_id, session_id, feed_given, tray_1-4 | Old tray+feed logging per session | ❌ No |
| `feed_sessions` | pond_id, plan_id, session_time, planned_feed, actual_feed, status | Old session-based feeding model | ❌ No |
| `feed_plans` | pond_id, doc, date, round, feed_amount, feed_type, is_completed, is_manual | **The correct feed plan table — RPC writes here but Flutter reads `feed_rounds`** | ❌ Never read |

`feed_logs` and `feed_sessions` appear to be from an older architecture. `feed_plans` is the critical one.

---

## 🟡 MEDIUM — `getFeedPlansByDateRange` Queries Non-Existent Column

In `feed_service.dart`:
```dart
Future<List<Map<String, dynamic>>> getFeedPlansByDateRange({...}) async {
  return await supabase
      .from('feed_rounds')
      .select()
      .gte('date', startDateStr)   // ❌ 'date' column doesn't exist in feed_rounds
      .lte('date', endDateStr);
}
```

`feed_rounds` has no `date` column. This query will always fail with a Supabase error. (`feed_plans` has a `date` column — another sign the code was originally targeting `feed_plans`.)

---

## 🟢 LOW — `feed_rounds` Missing `feed_type` Column

The `FeedPlanGenerator` sets `feed_type` when inserting:
```dart
batchData.add({'pond_id': pondId, ..., 'feed_type': feedType, ...});
```

But `feed_rounds` has no `feed_type` column. This insert will fail (or silently drop the field depending on Supabase strictness). `feed_plans` has `feed_type` — again pointing to the table mismatch.

---

## Complete Table Status Summary

| Table | Flutter Uses It | Schema Matches Flutter | Has RLS | Status |
|---|---|---|---|---|
| `farms` | ✅ | ✅ | ✅ Full | Healthy |
| `profiles` | ✅ | ✅ | ✅ Full | Healthy |
| `ponds` | ✅ | ⚠️ 3 missing cols, 1 duplicate | ✅ Full | Needs migration |
| `feed_base_rates` | ✅ | ✅ | ❌ None (read-only ref, acceptable) | OK |
| `feed_plans` | ❌ Never read | ✅ Best match for Flutter's needs | ❌ None | Should be the primary table |
| `feed_rounds` | ✅ Primary table | ⚠️ Missing 4 cols Flutter writes | ⚠️ Open | Wrong table, needs migration |
| `water_logs` | ❌ In-memory only | ❌ 4 missing columns | ❌ None | Needs migration + wiring |
| `sampling_logs` | ❌ In-memory only | ⚠️ Missing `doc` | ❌ None | Needs `doc` col + wiring |
| `harvest_logs` | ❌ In-memory only | ❌ 5 missing columns | ❌ None | Needs migration + wiring |
| `supplement_logs` | ❌ In-memory only | ❌ Severe mismatch | ❌ None | Full redesign needed |
| `feed_logs` | ❌ Never used | N/A | ❌ None | Legacy — consider dropping |
| `feed_sessions` | ❌ Never used | N/A | ❌ None | Legacy — consider dropping |

---

## Migration SQL to Fix Everything

Run these in Supabase SQL Editor **in order**:

### Step 1 — Fix `ponds` table
```sql
ALTER TABLE ponds 
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS current_abw NUMERIC,
  ADD COLUMN IF NOT EXISTS is_smart_feed_enabled BOOLEAN DEFAULT FALSE;

-- Remove duplicate column (keep num_trays, drop trays)
ALTER TABLE ponds DROP COLUMN IF EXISTS trays;
```

### Step 2 — Fix `feed_rounds` table
```sql
ALTER TABLE feed_rounds
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS is_manual BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS feed_type TEXT,
  ADD COLUMN IF NOT EXISTS actual_amount DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS date DATE;

-- Populate date from doc (requires ponds join — run after adding column)
UPDATE feed_rounds fr
SET date = p.stocking_date + (fr.doc - 1)
FROM ponds p
WHERE fr.pond_id = p.id AND fr.date IS NULL;
```

### Step 3 — Fix `water_logs` table
```sql
ALTER TABLE water_logs
  ADD COLUMN IF NOT EXISTS ammonia NUMERIC,
  ADD COLUMN IF NOT EXISTS nitrite NUMERIC,
  ADD COLUMN IF NOT EXISTS alkalinity NUMERIC,
  ADD COLUMN IF NOT EXISTS doc INTEGER;
```

### Step 4 — Fix `harvest_logs` table
```sql
ALTER TABLE harvest_logs
  ADD COLUMN IF NOT EXISTS doc INTEGER,
  ADD COLUMN IF NOT EXISTS date DATE,
  ADD COLUMN IF NOT EXISTS count_per_kg INTEGER,
  ADD COLUMN IF NOT EXISTS expenses NUMERIC DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT;
```

### Step 5 — Fix `sampling_logs` table
```sql
ALTER TABLE sampling_logs
  ADD COLUMN IF NOT EXISTS doc INTEGER;
```

### Step 6 — Redesign `supplement_logs` table
```sql
ALTER TABLE supplement_logs
  ADD COLUMN IF NOT EXISTS supplement_id TEXT,
  ADD COLUMN IF NOT EXISTS supplement_type TEXT,
  ADD COLUMN IF NOT EXISTS feed_round INTEGER,
  ADD COLUMN IF NOT EXISTS items JSONB,
  ADD COLUMN IF NOT EXISTS scheduled_time TEXT,
  ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS input_value NUMERIC,
  ADD COLUMN IF NOT EXISTS input_unit TEXT;
```

### Step 7 — Add RLS to all unprotected tables
```sql
-- Enable RLS
ALTER TABLE water_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE harvest_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sampling_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplement_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_rounds ENABLE ROW LEVEL SECURITY;

-- water_logs: user owns via pond → farm
CREATE POLICY "Users access their own water logs" ON water_logs
  FOR ALL USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  );

-- Repeat same pattern for harvest_logs, sampling_logs, supplement_logs, feed_rounds, feed_plans
CREATE POLICY "Users access their own harvest logs" ON harvest_logs
  FOR ALL USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "Users access their own sampling logs" ON sampling_logs
  FOR ALL USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "Users access their own supplement logs" ON supplement_logs
  FOR ALL USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "Users access their own feed rounds" ON feed_rounds
  FOR ALL USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "Users access their own feed plans" ON feed_plans
  FOR ALL USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  );

-- DROP the wide-open old policies on feed_rounds
DROP POLICY IF EXISTS "Allow insert for all users" ON feed_rounds;
DROP POLICY IF EXISTS "Allow select for all users" ON feed_rounds;
```

### Step 8 — Fix the RPC round distribution to match Flutter
```sql
CREATE OR REPLACE FUNCTION public.create_pond_with_feed_plan(
  p_farm_id uuid, p_name text, p_area double precision,
  p_stocking_date date, p_seed_count integer, p_pl_size integer,
  p_num_trays integer, p_user_id uuid
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
  v_pond_id UUID;
  v_doc INT;
  v_base_feed_amount DOUBLE PRECISION;
  v_scale_factor DOUBLE PRECISION;
  v_total_feed DOUBLE PRECISION;
  v_plan_date DATE;
  v_round_num INT;
  v_feed_type TEXT;
  -- FIX: Equal 25% distribution to match Flutter feed_plan_constants.dart
  v_round_distribution DOUBLE PRECISION[] := ARRAY[0.25, 0.25, 0.25, 0.25];
BEGIN
  INSERT INTO ponds (farm_id, name, area, stocking_date, seed_count, pl_size, num_trays, user_id)
  VALUES (p_farm_id, p_name, p_area, p_stocking_date, p_seed_count, p_pl_size, p_num_trays, p_user_id)
  RETURNING id INTO v_pond_id;

  v_scale_factor := (p_seed_count::DOUBLE PRECISION / 100000.0) * (p_area / 1.0);

  FOR v_doc IN 1..30 LOOP
    SELECT base_feed_amount INTO v_base_feed_amount FROM feed_base_rates WHERE doc = v_doc;
    IF v_base_feed_amount IS NULL THEN RAISE EXCEPTION 'Base feed missing for DOC %', v_doc; END IF;

    v_total_feed := v_base_feed_amount * v_scale_factor;
    v_plan_date := p_stocking_date + (v_doc - 1);

    IF v_doc <= 7 THEN v_feed_type := '1R';
    ELSIF v_doc <= 14 THEN v_feed_type := '1R + 2R';
    ELSIF v_doc <= 21 THEN v_feed_type := '2R';
    ELSIF v_doc <= 28 THEN v_feed_type := '2R + 3S';
    ELSE v_feed_type := '3S';
    END IF;

    -- FIX: Insert into feed_rounds (not feed_plans) to match Flutter reads
    FOR v_round_num IN 1..4 LOOP
      INSERT INTO feed_rounds (pond_id, doc, date, round, planned_amount, feed_type, is_manual, status)
      VALUES (v_pond_id, v_doc, v_plan_date, v_round_num,
              (v_total_feed * v_round_distribution[v_round_num]),
              v_feed_type, FALSE, 'pending');
    END LOOP;
  END LOOP;

  RETURN v_pond_id;
END;
$$;
```

---

## Priority Fix Order

| Priority | Fix | Impact |
|---|---|---|
| 1 | Run Step 2 + Step 8 (fix feed_rounds + RPC) | Fixes the core feed dashboard |
| 2 | Run Step 1 (fix ponds columns) | Fixes pond status + smart feed toggle |
| 3 | Run Step 7 (RLS) | Security — user data isolation |
| 4 | Run Step 3 (water_logs) + wire Flutter water provider to Supabase | Persists water data |
| 5 | Run Steps 4+5 (harvest + sampling) + wire Flutter providers | Persists harvest + growth data |
| 6 | Run Step 6 (supplement_logs) + wire Flutter provider | Persists supplement logs |
