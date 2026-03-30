# Aqua Rythu - Supabase Database Schema

## Overview
This document defines the database schema for the Aqua Rythu aquaculture management app. The schema supports farm management, pond lifecycle tracking, feed planning, growth monitoring, water quality tracking, and harvest management.

---

## Core Tables

### 1. **users** (from Supabase Auth)
- Managed automatically by Supabase
- Reference in other tables via `user_id`

---

### 2. **farms**
Represents individual fish farms.

```sql
CREATE TABLE farms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  farm_type TEXT NOT NULL CHECK (farm_type IN ('Intensive', 'Semi-Intensive', 'Extensive')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, name)
);

CREATE INDEX idx_farms_user_id ON farms(user_id);
```

**Columns:**
- `id`: Unique identifier (UUID)
- `user_id`: Reference to authenticated user
- `name`: Farm name
- `location`: Geographic location
- `farm_type`: Farming system type
- `created_at`, `updated_at`: Timestamps

---

### 3. **ponds**
Represents individual ponds within a farm.

```sql
CREATE TABLE ponds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  area NUMERIC(10, 2) NOT NULL, -- area in hectares
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  stocking_date DATE NOT NULL,
  seed_count INTEGER NOT NULL DEFAULT 100000,
  pl_size INTEGER NOT NULL DEFAULT 10, -- post larvae size in mm
  num_trays INTEGER NOT NULL DEFAULT 4,
  current_abw NUMERIC(8, 4), -- average body weight in grams (nullable, can be NULL if not sampled)
  survival_rate NUMERIC(5, 2) DEFAULT 100, -- current survival rate as percentage (100 = 100%)
  is_smart_enabled BOOLEAN DEFAULT FALSE, -- TRUE after first sampling (DOC > 30)
  last_sampling_doc INTEGER, -- DOC of last sampling for logic checks
  is_deleted BOOLEAN DEFAULT FALSE, -- soft delete flag
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ponds_farm_id ON ponds(farm_id);
CREATE INDEX idx_ponds_status ON ponds(status);
CREATE INDEX idx_ponds_is_deleted ON ponds(is_deleted);
```

**Columns:**
- `id`: Unique identifier
- `farm_id`: Reference to farm
- `name`: Pond name/identifier
- `area`: Pond area in hectares
- `status`: Active or completed
- `stocking_date`: Date fish were stocked
- `seed_count`: Initial number of fingerlings
- `pl_size`: Post-larvae size
- `num_trays`: Number of trays (for tracking)
- `current_abw`: Latest sampled average body weight
- `survival_rate`: Current survival rate percentage (updated via sampling)
- `is_smart_enabled`: TRUE after DOC > 30 and first sampling; enables smart feed mode
- `last_sampling_doc`: DOC of most recent sampling (required for feed logic)
- `is_deleted`: Soft delete flag (for audit trail preservation)
- `created_at`, `updated_at`: Timestamps

---

### 4. **sampling_logs** (Growth Monitoring)
Records fish growth sampling data.

```sql
CREATE TABLE sampling_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  doc INTEGER NOT NULL, -- day of culture
  weight_kg NUMERIC(10, 4) NOT NULL, -- total weight of sample in kg
  count_groups INTEGER NOT NULL, -- number of sampling groups
  pieces_per_group INTEGER NOT NULL DEFAULT 1,
  total_pieces INTEGER NOT NULL, -- total fish sampled
  average_body_weight NUMERIC(8, 4) NOT NULL, -- ABW in grams
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (pond_id, date)
);

CREATE INDEX idx_sampling_logs_pond_id ON sampling_logs(pond_id);
CREATE INDEX idx_sampling_logs_doc ON sampling_logs(doc);
CREATE INDEX idx_sampling_logs_pond_date ON sampling_logs(pond_id, date DESC);
```

**Columns:**
- `id`: Unique identifier (for API usage)
- `pond_id`: Reference to pond
- `date`: Sampling date
- `doc`: Day of culture
- `weight_kg`: Total weight of sample
- `count_groups`: Number of sampling groups
- `pieces_per_group`: Fish per group
- `total_pieces`: Total fish sampled
- `average_body_weight`: Calculated ABW in grams
- `is_deleted`: Soft delete flag
- `created_at`: Timestamp
- **UNIQUE constraint** on (pond_id, date) prevents duplicates

---

### 5. **feed_history_logs**
Records actual feed given vs planned feed.

```sql
CREATE TABLE feed_history_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  doc INTEGER NOT NULL,
  rounds NUMERIC(8, 2)[] NOT NULL, -- array of feed quantities per round
  smart_feed_recommendations NUMERIC(8, 2)[], -- optional smart recommendations
  tray_statuses TEXT[], -- array of tray statuses
  expected_feed NUMERIC(8, 2) NOT NULL, -- expected feed for the day
  cumulative_feed NUMERIC(10, 2) NOT NULL, -- cumulative feed given
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (pond_id, date)
);

CREATE INDEX idx_feed_history_pond_id ON feed_history_logs(pond_id);
CREATE INDEX idx_feed_history_doc ON feed_history_logs(doc);
CREATE INDEX idx_feed_history_pond_date ON feed_history_logs(pond_id, date DESC);
```

**Columns:**
- `id`: Unique identifier (for API usage)
- `pond_id`: Reference to pond
- `date`: Feed date
- `doc`: Day of culture
- `rounds`: Array of feed quantities (NUMERIC[])
- `smart_feed_recommendations`: Optional array of recommendations
- `tray_statuses`: Array of tray status values
- `expected_feed`: Expected feed based on plan
- `cumulative_feed`: Total feed given in cycle
- `is_deleted`: Soft delete flag
- `created_at`: Timestamp
- **UNIQUE constraint** on (pond_id, date) prevents duplicates

---

### 6. **water_logs**
Records water quality parameters.

```sql
CREATE TABLE water_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  doc INTEGER NOT NULL,
  ph NUMERIC(4, 2) NOT NULL,
  dissolved_oxygen NUMERIC(5, 2) NOT NULL, -- mg/L
  salinity NUMERIC(6, 2) NOT NULL, -- ppt (parts per thousand)
  ammonia NUMERIC(6, 3) NOT NULL, -- mg/L
  nitrite NUMERIC(6, 3) NOT NULL, -- mg/L
  alkalinity NUMERIC(6, 1) NOT NULL, -- mg/L
  temperature NUMERIC(5, 2), -- optional: Celsius
  health_score INTEGER GENERATED ALWAYS AS (
    CASE
      WHEN dissolved_oxygen < 3.5 THEN (100 - 20)
      WHEN dissolved_oxygen < 4.5 THEN (100 - 10)
      ELSE 100
    END
  ) STORED, -- simplified health score
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (pond_id, date)
);

CREATE INDEX idx_water_logs_pond_id ON water_logs(pond_id);
CREATE INDEX idx_water_logs_doc ON water_logs(doc);
CREATE INDEX idx_water_logs_pond_date ON water_logs(pond_id, date DESC);
```

**Columns:**
- `id`: Unique identifier (for API usage)
- `pond_id`: Reference to pond
- `date`: Measurement date
- `doc`: Day of culture
- `ph`, `dissolved_oxygen`, `salinity`, `ammonia`, `nitrite`, `alkalinity`: Water parameters
- `temperature`: Optional water temperature
- `health_score`: Computed health score
- `is_deleted`: Soft delete flag
- `created_at`: Timestamp
- **UNIQUE constraint** on (pond_id, date) prevents duplicates

---

### 7. **harvest_entries**
Records partial and final harvests.

```sql
CREATE TABLE harvest_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  doc INTEGER NOT NULL,
  harvest_type TEXT NOT NULL CHECK (harvest_type IN ('partial', 'intermediate', 'final')),
  quantity_kg NUMERIC(10, 2) NOT NULL, -- harvest weight in kg
  count_per_kg INTEGER NOT NULL, -- count/kg for sizing
  price_per_kg NUMERIC(8, 2) NOT NULL, -- selling price per kg
  revenue NUMERIC(12, 2) GENERATED ALWAYS AS (quantity_kg * price_per_kg) STORED,
  expenses NUMERIC(10, 2) DEFAULT 0, -- harvest-related expenses
  profit NUMERIC(12, 2) GENERATED ALWAYS AS (
    (quantity_kg * price_per_kg) - COALESCE(expenses, 0)
  ) STORED,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(pond_id, date, harvest_type)
);

CREATE INDEX idx_harvest_entries_pond_id ON harvest_entries(pond_id);
CREATE INDEX idx_harvest_entries_date ON harvest_entries(date);
```

**Columns:**
- `id`: Unique identifier
- `pond_id`: Reference to pond
- `date`: Harvest date
- `doc`: Day of culture
- `harvest_type`: partial, intermediate, or final
- `quantity_kg`: Harvested weight
- `count_per_kg`: Fish count per kg (size indicator)
- `price_per_kg`: Market price
- `revenue`: Computed (quantity × price)
- `expenses`: Associated costs
- `profit`: Computed (revenue - expenses)
- `notes`: Additional notes
- `created_at`: Timestamp

---

### 8. **tray_logs**
Records tray status (health indicator) for each feeding round.

```sql
CREATE TABLE tray_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  doc INTEGER NOT NULL,
  round_number INTEGER NOT NULL,
  tray_statuses TEXT[] NOT NULL, -- array of status values (e.g., 'good', 'warning', 'bad')
  observations JSONB, -- map of tray_index -> observation_array
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_tray_logs_pond_id ON tray_logs(pond_id);
CREATE INDEX idx_tray_logs_date ON tray_logs(date);
CREATE INDEX idx_tray_logs_doc ON tray_logs(doc);
```

**Columns:**
- `id`: Unique identifier
- `pond_id`: Reference to pond
- `date`: Log date
- `doc`: Day of culture
- `round_number`: Feeding round (1-4 typically)
- `tray_statuses`: Array of status values
- `observations`: JSONB with detailed observations
- `created_at`: Timestamp

---

### 9. **supplements**
Records supplement schedules (feed mix or water mix).

```sql
CREATE TABLE supplements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  start_doc INTEGER NOT NULL, -- starting day of culture
  end_doc INTEGER NOT NULL, -- ending day of culture
  start_date DATE,
  end_date DATE,
  supplement_type TEXT NOT NULL CHECK (supplement_type IN ('feed_mix', 'water_mix')),
  goal TEXT CHECK (goal IN ('growth_boost', 'disease_prevention', 'water_correction', 'stress_recovery')),
  
  -- FEED MIX specific
  feed_qty NUMERIC(8, 2) DEFAULT 0, -- kg for the supplement
  feeding_times TEXT[], -- array of feeding round times (e.g., ['R1', 'R2'])
  
  -- WATER MIX specific
  frequency_days INTEGER, -- repeat every N days
  preferred_time TEXT, -- 'morning', 'evening', 'after_feed'
  water_time TEXT, -- HH:mm format
  
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused')),
  notes TEXT,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_supplements_status ON supplements(status);
```

**Columns:**
- `id`: Unique identifier
- `name`: Supplement name
- `start_doc`, `end_doc`: Day of culture range
- `start_date`, `end_date`: Date range
- `supplement_type`: feed_mix or water_mix
- `goal`: Purpose of supplement
- `feed_qty`: For feed mix, quantity to add
- `feeding_times`: Array of feeding rounds
- `frequency_days`: For water mix, frequency
- `preferred_time`: For water mix, timing preference
- `water_time`: For water mix, specific time
- `status`: Active, completed, or paused
- `notes`: Additional info
- `is_deleted`: Soft delete flag
- `created_at`, `updated_at`: Timestamps

**Note:** Pond associations are managed via the `supplement_ponds` junction table (see below).

---

### 10. **supplement_ponds** (Junction Table - M:N Relationship)
Maps supplements to ponds (many-to-many relationship).

```sql
CREATE TABLE supplement_ponds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplement_id UUID NOT NULL REFERENCES supplements(id) ON DELETE CASCADE,
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE (supplement_id, pond_id)
);

CREATE INDEX idx_supplement_ponds_supplement_id ON supplement_ponds(supplement_id);
CREATE INDEX idx_supplement_ponds_pond_id ON supplement_ponds(pond_id);
```

**Columns:**
- `id`: Unique identifier
- `supplement_id`: Reference to supplement
- `pond_id`: Reference to pond
- `created_at`: Timestamp
- **UNIQUE constraint** prevents duplicate associations
- **Indexes** on both foreign keys for efficient queries

**Advantages of junction table:**
- ✅ Proper referential integrity (FK constraints)
- ✅ Easy to query: "which supplements apply to pond X?"
- ✅ Scales well with analytics
- ✅ Supports many-to-many efficiently
- ✅ No data integrity issues with arrays

---

### 10. **supplement_items**
Individual items in a supplement mix.

```sql
CREATE TABLE supplement_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplement_id UUID NOT NULL REFERENCES supplements(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL, -- name of supplement item (e.g., 'Vitamin B Complex')
  quantity NUMERIC(10, 4) NOT NULL, -- quantity of item
  unit TEXT NOT NULL, -- 'grams', 'kg', 'ml', 'liters', etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_supplement_items_supplement_id ON supplement_items(supplement_id);
```

**Columns:**
- `id`: Unique identifier
- `supplement_id`: Reference to supplement
- `item_name`: Name of the item
- `quantity`: Amount
- `unit`: Unit of measurement
- `created_at`: Timestamp

---

### 11. **feed_plans** (Optional but useful for quick access)
Cache of daily feed plans by pond.

```sql
CREATE TABLE feed_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
  doc INTEGER NOT NULL, -- day of culture
  rounds NUMERIC(8, 2)[] NOT NULL, -- array of planned feed for each round
  total_daily_feed NUMERIC(8, 2) GENERATED ALWAYS AS (
    (COALESCE((SELECT SUM(x) FROM UNNEST(rounds) AS x), 0))::NUMERIC(8,2)
  ) STORED,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(pond_id, doc)
);

CREATE INDEX idx_feed_plans_pond_id ON feed_plans(pond_id);
```

---

## Row-Level Security (RLS) Policies

Enable RLS and create policies to ensure users only access their own data:

```sql
-- Enable RLS
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE ponds ENABLE ROW LEVEL SECURITY;
ALTER TABLE sampling_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_history_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE water_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE harvest_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE tray_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplements ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplement_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_plans ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own farms
CREATE POLICY "Users can view their own farms" ON farms
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own farms" ON farms
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own farms" ON farms
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own farms" ON farms
  FOR DELETE USING (user_id = auth.uid());

-- Policy: Users can view ponds from their farms
CREATE POLICY "Users can view ponds from their farms" ON ponds
  FOR SELECT USING (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
  );

CREATE POLICY "Users can insert ponds into their farms" ON ponds
  FOR INSERT WITH CHECK (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
  );

-- Similar policies for other tables...
```

---

## Relationships Diagram

```
users (Supabase Auth)
  ├── farms
  │   ├── ponds
  │   │   ├── sampling_logs (1:n)
  │   │   ├── feed_history_logs (1:n)
  │   │   ├── water_logs (1:n)
  │   │   ├── harvest_entries (1:n)
  │   │   ├── tray_logs (1:n)
  │   │   └── feed_plans (1:n)
  │   └── supplements (m:n via pond_ids array)
  │       └── supplement_items (1:n)
```

---

## Data Types Reference

| Type | Usage |
|------|-------|
| UUID | Primary keys, foreign keys (Supabase standard) |
| TEXT | Names, descriptions, enums (CHECK constraints) |
| NUMERIC(precision, scale) | Monetary values, measurements |
| DATE | Date-only records |
| TIMESTAMP WITH TIME ZONE | Audit timestamps |
| INTEGER[] | Arrays (e.g., tray counts) |
| NUMERIC[] | Arrays of decimal values |
| JSONB | Complex nested data (observations, metadata) |
| GENERATED ALWAYS AS ... STORED | Computed columns |

---

## Important Notes

1. **Array Types**: PostgreSQL arrays are used for feeding rounds, tray statuses, and pond IDs. Use `ARRAY_AGG()` for grouping or `UNNEST()` for flattening.

2. **Timestamps**: All tables use `TIMESTAMP WITH TIME ZONE` for consistency across timezones.

3. **Computed Columns**: `revenue`, `profit`, and `total_daily_feed` are computed at the database level to ensure consistency.

4. **Indexes**: Indexes are created on frequently queried columns (user_id, pond_id, date, doc, status).

5. **Constraints**:
   - `CHECK` constraints enforce enum values
   - `UNIQUE` constraints prevent duplicate records
   - Foreign keys with `ON DELETE CASCADE` maintain referential integrity

6. **Feed Calculation Formula**:
   ```
   Daily Feed = Biomass × Feed%
   Biomass = (seedCount × survival × weight) / 1000
   Feed% = determined by average body weight (ABW)
   ```

---

## Migration Path

1. Create tables in order: `users` → `farms` → `ponds` → `sampling_logs`, `feed_history_logs`, etc.
2. Enable RLS policies
3. Create indexes for performance
4. Set up backups in Supabase dashboard
5. Test data insertion and query patterns

---

## Common Queries

**Latest ABW for a pond:**
```sql
SELECT average_body_weight 
FROM sampling_logs 
WHERE pond_id = 'pond_id_here' 
ORDER BY date DESC 
LIMIT 1;
```

**Total harvest for a pond:**
```sql
SELECT SUM(quantity_kg) as total_kg, SUM(revenue) as total_revenue
FROM harvest_entries
WHERE pond_id = 'pond_id_here';
```

**Daily feed compliance:**
```sql
SELECT 
  date,
  expected_feed,
  (SELECT SUM(x) FROM UNNEST(rounds) AS x) as actual_feed,
  ((SELECT SUM(x) FROM UNNEST(rounds) AS x) - expected_feed) as delta
FROM feed_history_logs
WHERE pond_id = 'pond_id_here'
ORDER BY date DESC;
```

**Active supplements for a pond:**
```sql
SELECT * FROM supplements
WHERE status = 'active' 
  AND pond_ids @> ARRAY['pond_id_here'::UUID]
  AND start_doc <= 45  -- current DOC
  AND end_doc >= 45;
```

