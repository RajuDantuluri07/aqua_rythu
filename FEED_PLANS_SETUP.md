# 🚨 CRITICAL: Feed Plans Table Setup Guide

## ⚠️ Issue
Pond creation is failing with error:
```
PostgrestException: Could not find table 'public.feed_plans' in the schema cache
code: PGRST205
```

## ✅ Solution: Create feed_plans Table

### Step 1: Open Supabase SQL Editor
1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Click **New Query**

### Step 2: Copy & Paste the SQL Migration
Copy the entire content from:
```
/migrations/001_create_feed_plans_table.sql
```

### Step 3: Execute the SQL
- Paste the SQL into the editor
- Click **Run** button
- Wait for confirmation: "Query successful"

### Step 4: Verify Table Creation
In SQL Editor, run:
```sql
SELECT * FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'feed_plans';
```

Expected output: One row showing the feed_plans table

### Step 5: Test Pond Creation
1. Go back to your app
2. Try creating a new pond
3. Should now complete without error ✅

---

## 📋 What Gets Created

### Table Structure
| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID | Primary key |
| `pond_id` | UUID | Reference to pond |
| `doc` | INTEGER | Day of Culture (1-30) |
| `date` | DATE | Calendar date |
| `round` | INTEGER | Feeding round (1-4) |
| `feed_amount` | NUMERIC | Feed quantity (kg) |
| `feed_type` | TEXT | standard/adjusted/skipped |
| `is_manual` | BOOLEAN | User override flag |
| `is_completed` | BOOLEAN | Completion status |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update time |

### Records Created Per Pond
- **Days**: 30
- **Rounds per day**: 4
- **Total records**: 120
- Example:
  - DOC 1, Round 1: 1.5 kg
  - DOC 1, Round 2: 1.5 kg
  - DOC 1, Round 3: 1.5 kg
  - DOC 1, Round 4: 1.5 kg
  - DOC 2, Round 1: 1.6 kg
  - ... and so on

### Indexes Created
- `idx_feed_plans_pond_id` - Fast lookups by pond
- `idx_feed_plans_pond_doc` - Fast lookups by pond + DOC
- `idx_feed_plans_date` - Fast lookups by calendar date
- `idx_feed_plans_completed` - Fast lookups by completion status

### Security (RLS)
- Users can only view their own feed plans
- Users can only modify plans for their ponds
- Automatic cascade delete when pond is deleted

---

## 🔍 Troubleshooting

### Error: "Table already exists"
- Table might already be created
- Run the verification query above
- If table exists but empty, tables are fine

### Error: "Invalid foreign key reference"
- Ensure `ponds` table already exists
- Check `ponds` table has proper structure

### Error: "Permission denied"
- Ensure you're using Supabase role with table creation permissions
- Use the service role or owner account

---

## ✨ What's Fixed in the Code

### PondService._generateFeedPlan()
✅ Now creates 120 individual records (30 days × 4 rounds)
✅ Proper date calculation for each DOC
✅ Validation for pondId
✅ Better error handling with detailed messages

### FeedService
✅ Added getFeedPlans() - get all plans for a pond
✅ Added getFeedPlanForDoc() - get specific DOC
✅ Added getFeedPlansByDateRange() - get date range
✅ Added markFeedPlanCompleted() - mark as done
✅ Added overrideFeedAmount() - manual override

---

## 🧪 Expected Behavior After Setup

### Creating a New Pond
1. User enters: Name, Area, Seed Count, PL Size, Trays
2. Click "Create Pond"
3. Backend:
   - ✅ Creates pond record
   - ✅ Generates 30-day feed schedule (120 records)
   - ✅ Stores in feed_plans table
4. UI:
   - ✅ Shows success message
   - ✅ Redirects to pond dashboard
   - ✅ Feed rounds display planned quantities

---

## 📞 Need Help?

If you get stuck:
1. Check Supabase SQL Editor history for error details
2. Verify table exists: `SELECT * FROM feed_plans;`
3. Check row level security is enabled
4. Ensure all foreign keys reference valid tables

---

**Status**: 🔴 BLOCKED (pending database setup)
**Start Date**: 31 March 2026
**Next Step**: Run SQL migration in Supabase
