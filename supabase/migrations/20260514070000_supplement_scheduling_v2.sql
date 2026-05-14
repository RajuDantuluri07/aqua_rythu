-- =============================================================
-- Supplement Scheduling V2: Dynamic categories + normalized schedules
-- =============================================================

-- ─── 1. Master Categories Table ────────────────────────────
CREATE TABLE IF NOT EXISTS public.master_categories (
  id                        UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  name                      TEXT          NOT NULL UNIQUE,
  display_name              TEXT          NOT NULL,
  default_application_type  TEXT          NOT NULL
    CHECK (default_application_type IN ('feed_mix', 'water_mix', 'both')),
  sort_order                INT           DEFAULT 0,
  active                    BOOLEAN       DEFAULT true,
  created_at                TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.master_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "master_categories_select"
  ON public.master_categories FOR SELECT TO authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_master_categories_application_type
  ON public.master_categories(default_application_type);

-- ─── 2. Seed Master Categories ────────────────────────────
INSERT INTO public.master_categories
  (name, display_name, default_application_type, sort_order)
VALUES
  -- Real product categories
  ('EDTA',                   'EDTA',                    'water_mix', 1),
  ('FEED SUPPLEMENTS',       'Feed Supplements',        'feed_mix',  2),
  ('GEL',                    'Gel',                     'feed_mix',  3),
  ('GEOLITE',                'Geolite',                 'water_mix', 4),
  ('Growth Promoters',       'Growth Promoters',        'feed_mix',  5),
  ('GUT PROBIOTICS',         'Gut Probiotics',          'feed_mix',  6),
  ('IMMUNITY',               'Immunity',                'feed_mix',  7),
  ('LOOSE SHEEL',            'Loose Shell',             'both',      8),
  ('MINERALS',               'Minerals',                'water_mix', 9),
  ('NITRATES',               'Nitrates',                'water_mix', 10),
  ('OTHERS',                 'Others',                  'both',      11),
  ('OXYGEN',                 'Oxygen',                  'water_mix', 12),
  ('SANITIZERS',             'Sanitizers',              'water_mix', 13),
  ('SOIL TREATMENT',         'Soil Treatment',          'water_mix', 14),
  ('VITAMIN C',              'Vitamin C',               'both',      15),
  ('WATER & SOIL PROBIOTICS','Water & Soil Probiotics', 'water_mix', 16),
  ('WATER PROBIOTICS',       'Water Probiotics',        'water_mix', 17),
  ('YEAST',                  'Yeast',                   'water_mix', 18),
  ('Ammonia',                'Ammonia',                 'water_mix', 19),
  -- Legacy seed categories
  ('Feed Supplement',  'Feed Supplement',  'feed_mix',  20),
  ('Water Supplement', 'Water Supplement', 'water_mix', 21),
  ('Probiotic',        'Probiotic',        'water_mix', 22),
  ('Mineral',          'Mineral',          'water_mix', 23),
  ('Medicine',         'Medicine',         'both',      24),
  ('Pond Preparation', 'Pond Preparation', 'water_mix', 25),
  ('Water Treatment',  'Water Treatment',  'water_mix', 26)
ON CONFLICT (name) DO NOTHING;

-- ─── 3. Supplement Schedules Table ────────────────────────
CREATE TABLE IF NOT EXISTS public.supplement_schedules (
  id                    UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  farm_id               UUID          REFERENCES public.farms(id) ON DELETE CASCADE,
  pond_id               UUID          NOT NULL REFERENCES public.ponds(id) ON DELETE CASCADE,
  product_id            UUID          REFERENCES public.product_master(id),
  product_name          TEXT,
  category_name         TEXT,
  category_id           UUID          REFERENCES public.master_categories(id),
  application_type      TEXT          NOT NULL
    CHECK (application_type IN ('feed_mix', 'water_mix')),
  start_date            DATE          NOT NULL,
  end_date              DATE          NOT NULL,
  selected_feed_rounds  JSONB         DEFAULT '[]',
  notes                 TEXT,
  status                TEXT          DEFAULT 'active'
    CHECK (status IN ('active', 'paused', 'completed')),
  created_by            UUID          REFERENCES auth.users(id),
  created_at            TIMESTAMPTZ   DEFAULT now(),
  updated_at            TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.supplement_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplement_schedules_select"
  ON public.supplement_schedules FOR SELECT
  USING (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE POLICY "supplement_schedules_insert"
  ON public.supplement_schedules FOR INSERT
  WITH CHECK (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE POLICY "supplement_schedules_update"
  ON public.supplement_schedules FOR UPDATE
  USING (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE POLICY "supplement_schedules_delete"
  ON public.supplement_schedules FOR DELETE
  USING (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE INDEX IF NOT EXISTS idx_supplement_schedules_pond
  ON public.supplement_schedules(pond_id);

CREATE INDEX IF NOT EXISTS idx_supplement_schedules_dates
  ON public.supplement_schedules(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_supplement_schedules_status
  ON public.supplement_schedules(status);

-- ─── 4. Supplement Schedule Logs Table ─────────────────────
CREATE TABLE IF NOT EXISTS public.supplement_schedule_logs (
  id                        UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  supplement_schedule_id    UUID          NOT NULL REFERENCES public.supplement_schedules(id) ON DELETE CASCADE,
  applied_date              DATE          NOT NULL,
  feed_round                TEXT,
  status                    TEXT          DEFAULT 'pending'
    CHECK (status IN ('pending', 'applied', 'skipped')),
  remarks                   TEXT,
  created_at                TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.supplement_schedule_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplement_schedule_logs_select"
  ON public.supplement_schedule_logs FOR SELECT
  USING (supplement_schedule_id IN (
    SELECT ss.id FROM public.supplement_schedules ss
    WHERE ss.pond_id IN (
      SELECT p.id FROM public.ponds p
      JOIN public.farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  ));

CREATE POLICY "supplement_schedule_logs_insert"
  ON public.supplement_schedule_logs FOR INSERT
  WITH CHECK (supplement_schedule_id IN (
    SELECT ss.id FROM public.supplement_schedules ss
    WHERE ss.pond_id IN (
      SELECT p.id FROM public.ponds p
      JOIN public.farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  ));

CREATE POLICY "supplement_schedule_logs_update"
  ON public.supplement_schedule_logs FOR UPDATE
  USING (supplement_schedule_id IN (
    SELECT ss.id FROM public.supplement_schedules ss
    WHERE ss.pond_id IN (
      SELECT p.id FROM public.ponds p
      JOIN public.farms f ON f.id = p.farm_id
      WHERE f.user_id = auth.uid()
    )
  ));

CREATE INDEX IF NOT EXISTS idx_supplement_schedule_logs_schedule_id
  ON public.supplement_schedule_logs(supplement_schedule_id);

CREATE INDEX IF NOT EXISTS idx_supplement_schedule_logs_applied_date
  ON public.supplement_schedule_logs(applied_date);
