-- =============================================================
-- V1 Product Master: feed_master_products, product_master,
-- prices, supplement_logs + extend feed_logs
-- =============================================================

-- ─── 1. Feed Master Products ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feed_master_products (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  brand           TEXT          NOT NULL,
  product_code    TEXT,
  product_name    TEXT          NOT NULL,
  culture_type    TEXT          DEFAULT 'shrimp',
  stage           TEXT,
  pellet_size_mm  TEXT,
  protein_percent NUMERIC,
  bag_weight_kg   NUMERIC       DEFAULT 25,
  feed_type       TEXT          DEFAULT 'pellet',
  active          BOOLEAN       DEFAULT true,
  created_at      TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.feed_master_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_master_products_select"
  ON public.feed_master_products FOR SELECT
  TO authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_feed_master_products_brand
  ON public.feed_master_products(brand);

CREATE INDEX IF NOT EXISTS idx_feed_master_products_active
  ON public.feed_master_products(active);

-- ─── 2. Product Master (supplements, minerals, etc.) ────────
CREATE TABLE IF NOT EXISTS public.product_master (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  brand           TEXT,
  product_name    TEXT          NOT NULL,
  category        TEXT          NOT NULL,
  sub_category    TEXT,
  form            TEXT,
  unit_type       TEXT,
  package_size    NUMERIC,
  base_unit       TEXT,
  active          BOOLEAN       DEFAULT true,
  created_at      TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.product_master ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_master_select"
  ON public.product_master FOR SELECT
  TO authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_product_master_category
  ON public.product_master(category);

CREATE INDEX IF NOT EXISTS idx_product_master_active
  ON public.product_master(active);

-- ─── 3. Prices ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.prices (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id      UUID          NOT NULL,
  product_type    TEXT          NOT NULL CHECK (product_type IN ('feed', 'supplement')),
  price           NUMERIC       NOT NULL,
  unit            TEXT          NOT NULL,
  dealer_name     TEXT,
  district        TEXT,
  effective_date  DATE          DEFAULT CURRENT_DATE,
  active          BOOLEAN       DEFAULT true,
  created_at      TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "prices_select"
  ON public.prices FOR SELECT
  TO authenticated USING (true);

CREATE INDEX IF NOT EXISTS idx_prices_product_id
  ON public.prices(product_id);

-- ─── 4. Supplement Logs (actual pond-wise usage) ─────────────
CREATE TABLE IF NOT EXISTS public.supplement_logs (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  farm_id         UUID          REFERENCES public.farms(id) ON DELETE CASCADE,
  pond_id         UUID          NOT NULL REFERENCES public.ponds(id) ON DELETE CASCADE,
  crop_cycle_id   UUID,
  product_id      UUID          REFERENCES public.product_master(id),
  product_name    TEXT,
  quantity        NUMERIC       NOT NULL,
  unit            TEXT          NOT NULL,
  total_cost      NUMERIC,
  notes           TEXT,
  applied_at      TIMESTAMPTZ   DEFAULT now(),
  created_at      TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.supplement_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplement_logs_select"
  ON public.supplement_logs FOR SELECT
  USING (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE POLICY "supplement_logs_insert"
  ON public.supplement_logs FOR INSERT
  WITH CHECK (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE POLICY "supplement_logs_delete"
  ON public.supplement_logs FOR DELETE
  USING (pond_id IN (
    SELECT p.id FROM public.ponds p
    JOIN public.farms f ON f.id = p.farm_id
    WHERE f.user_id = auth.uid()
  ));

CREATE INDEX IF NOT EXISTS idx_supplement_logs_pond_id
  ON public.supplement_logs(pond_id);

CREATE INDEX IF NOT EXISTS idx_supplement_logs_applied_at
  ON public.supplement_logs(applied_at DESC);

-- ─── 5. Extend feed_logs with product reference ──────────────
ALTER TABLE public.feed_logs
  ADD COLUMN IF NOT EXISTS feed_product_id UUID REFERENCES public.feed_master_products(id);

-- ─── 6. Seed: Feed Master Products (from feed brands master) ──
INSERT INTO public.feed_master_products
  (brand, product_code, product_name, culture_type, stage, pellet_size_mm, protein_percent, bag_weight_kg, feed_type)
VALUES
  ('CP India Pvt Ltd', '7701', 'Blanca', 'Vannamei', 'Starter-1', '0.8 mm', 36, 25, 'pellet'),
  ('CP India Pvt Ltd', '7702', 'Blanca', 'Vannamei', 'Starter-2', '1.0 mm', 36, 25, 'pellet'),
  ('CP India Pvt Ltd', '7703', 'Blanca', 'Vannamei', 'Pre Grower', '1.4 mm', 36, 25, 'pellet'),
  ('CP India Pvt Ltd', '7704', 'Blanca', 'Vannamei', 'Grower', '1.8 mm', 36, 25, 'pellet'),
  ('CP India Pvt Ltd', '7704S', 'Blanca', 'Vannamei', 'Finisher', '1.8 mm', 36, 25, 'pellet'),

  ('Avanti Feeds Limited', '1', 'Manamei', 'Vannamei', 'Starter-1', '0.8 mm', 34, 25, 'pellet'),
  ('Avanti Feeds Limited', '2', 'Manamei', 'Vannamei', 'Starter-2', '1.0 mm', 34, 25, 'pellet'),
  ('Avanti Feeds Limited', '3P', 'Manamei', 'Vannamei', 'Starter-3', '1.2 mm', 34, 25, 'pellet'),
  ('Avanti Feeds Limited', '3S', 'Manamei', 'Vannamei', 'Pre Grower', '1.4 mm', 34, 25, 'pellet'),
  ('Avanti Feeds Limited', '3M', 'Manamei', 'Vannamei', 'Grower-1', '1.6 mm', 34, 25, 'pellet'),
  ('Avanti Feeds Limited', '3L', 'Manamei', 'Vannamei', 'Finisher', '1.8 mm', 33, 25, 'pellet'),

  ('Nexgen Feeds', '1', 'I Feed', 'Vannamei', 'Starter-1', '0.8 mm', 36, 25, 'pellet'),
  ('Nexgen Feeds', '2P', 'I Feed', 'Vannamei', 'Starter-2', '1.0 mm', 36, 25, 'pellet'),
  ('Nexgen Feeds', '3P', 'I Feed', 'Vannamei', 'Starter-3', '1.2 mm', 36, 25, 'pellet'),
  ('Nexgen Feeds', '3SP', 'I Feed', 'Vannamei', 'Pre Grower', '1.4 mm', 35, 25, 'pellet'),
  ('Nexgen Feeds', '3SP+', 'I Feed', 'Vannamei', 'Grower-1', '1.6 mm', 35, 25, 'pellet'),
  ('Nexgen Feeds', '3M', 'I Feed', 'Vannamei', 'Grower-2', '1.8 mm', 35, 25, 'pellet'),
  ('Nexgen Feeds', '3L', 'I Feed', 'Vannamei', 'Finisher-1', '2.0 mm', 35, 25, 'pellet'),
  ('Nexgen Feeds', '4', 'I Feed', 'Vannamei', 'Finisher-2', '2.2-2.5 mm', 35, 25, 'pellet'),

  ('Skretting', '1', 'Gamma', 'Vannamei', 'Starter-1', '0.8 mm', 38, 5, 'pellet'),
  ('Skretting', '2', 'Gamma', 'Vannamei', 'Starter-2', '1.0-1.5-2 mm', 38, 10, 'pellet'),
  ('Skretting', '3', 'Gamma', 'Vannamei', 'Pre Grower', '1.2-1.5-2 mm', 38, 20, 'pellet'),
  ('Skretting', '4', 'Gamma', 'Vannamei', 'Grower-1', '1.4-2-4 mm', 38, 20, 'pellet'),
  ('Skretting', '5', 'Gamma', 'Vannamei', 'Grower-2', '1.6-2-4 mm', 36, 20, 'pellet'),
  ('Skretting', '6', 'Gamma', 'Vannamei', 'Grower-3', '1.8-2-4 mm', 36, 20, 'pellet'),
  ('Skretting', '7', 'Gamma', 'Vannamei', 'Finisher-1', '1.8-3-5 mm', 36, 20, 'pellet'),
  ('Skretting', '8', 'Gamma', 'Vannamei', 'Finisher-2', '2-3-5 mm', 36, 20, 'pellet'),

  ('Sandhya Marines Limited', '1C', 'Sandhya', 'Vannamei', 'Starter-1', '0.6-0.8 mm', 36, 10, 'pellet'),
  ('Sandhya Marines Limited', '2', 'Sandhya', 'Vannamei', 'Starter-2', '0.8-1.0 mm', 36, 25, 'pellet'),
  ('Sandhya Marines Limited', '2P', 'Sandhya', 'Vannamei', 'Starter-3', '1.0-1.2 mm', 36, 25, 'pellet'),
  ('Sandhya Marines Limited', '3S', 'Sandhya', 'Vannamei', 'Pre Grower', '1.2-1.4 mm', 36, 25, 'pellet'),
  ('Sandhya Marines Limited', '3SP', 'Sandhya', 'Vannamei', 'Grower-1', '1.4-1.6 mm', 35, 25, 'pellet'),
  ('Sandhya Marines Limited', '3P', 'Sandhya', 'Vannamei', 'Grower-2', '1.6-1.8 mm', 35, 25, 'pellet'),
  ('Sandhya Marines Limited', '3L', 'Sandhya', 'Vannamei', 'Grower-3', '1.8-2.0 mm', 35, 25, 'pellet'),
  ('Sandhya Marines Limited', '4M', 'Sandhya', 'Vannamei', 'Finisher', '2.0-2.2 mm', 35, 25, 'pellet'),

  ('Kingmei', '1', 'Kingmei Bluecrown', 'Vannamei', 'Starter 1', '0.6-0.8 mm', 36, 25, 'pellet'),
  ('Kingmei', '2', 'Kingmei Bluecrown', 'Vannamei', 'Starter 2', '0.8-1.0 mm', 36, 25, 'pellet'),
  ('Kingmei', '2P', 'Kingmei Bluecrown', 'Vannamei', 'Pre Grower', '1.0-1.2 mm', 36, 25, 'pellet'),
  ('Kingmei', '3SP', 'Kingmei Bluecrown', 'Vannamei', 'Grower-1', '1.2-1.4 mm', 35, 25, 'pellet'),
  ('Kingmei', '3P', 'Kingmei Bluecrown', 'Vannamei', 'Grower-2', '1.4-1.6 mm', 35, 25, 'pellet'),
  ('Kingmei', '3S', 'Kingmei Bluecrown', 'Vannamei', 'Grower-3', '1.6-1.8 mm', 35, 25, 'pellet'),
  ('Kingmei', '4M', 'Kingmei Bluecrown', 'Vannamei', 'Finisher-1', '2.0-2.2 mm', 35, 25, 'pellet'),
  ('Kingmei', '4L', 'Kingmei Bluecrown', 'Vannamei', 'Finisher-2', '2.2-2.5 mm', 35, 25, 'pellet'),

  ('Growel', '3S1', 'Nutriva Plus', 'Vannamei', 'Starter-1', '1.0 mm', 38, 25, 'pellet'),
  ('Growel', '3S2', 'Nutriva Plus', 'Vannamei', 'Starter-2', '1.2 mm', 38, 25, 'pellet'),
  ('Growel', '3S3', 'Nutriva Plus', 'Vannamei', 'Grower-1', '1.4 mm', 36, 25, 'pellet'),
  ('Growel', '3S4', 'Nutriva Plus', 'Vannamei', 'Grower-2', '1.6 mm', 36, 25, 'pellet'),

  ('Growel', '1C', 'Nutriva', 'Vannamei', 'Starter-1', '<0.5 mm', 36, 25, 'pellet'),
  ('Growel', '2C', 'Nutriva', 'Vannamei', 'Starter-2', '0.5-1.0 mm', 36, 25, 'pellet'),
  ('Growel', '3SP', 'Nutriva', 'Vannamei', 'Starter-3', '1.2-1.7 mm', 35, 25, 'pellet'),
  ('Growel', '4P', 'Nutriva', 'Vannamei', 'Starter-4', '2.0-4.0 mm', 35, 25, 'pellet'),
  ('Growel', '5P', 'Nutriva', 'Vannamei', 'Grower-1', '3.0-5.0 mm', 35, 25, 'pellet'),
  ('Growel', '6P', 'Nutriva', 'Vannamei', 'Grower-2', '3.0-5.0 mm', 35, 25, 'pellet'),
  ('Growel', '7P', 'Nutriva', 'Vannamei', 'Grower-2', '3.0-5.0 mm', 35, 25, 'pellet'),

  ('Growel', '1C', 'Marigold', 'Vannamei', 'Starter-1', '<0.5 mm', 36, 25, 'pellet'),
  ('Growel', '2C', 'Marigold', 'Vannamei', 'Starter-2', '0.5-1.0 mm', 36, 25, 'pellet'),
  ('Growel', '3SP', 'Marigold', 'Vannamei', 'Starter-3', '1.0 mm', 35, 25, 'pellet'),
  ('Growel', '4P', 'Marigold', 'Vannamei', 'Starter-4', '1.2 mm', 35, 25, 'pellet'),
  ('Growel', '5P', 'Marigold', 'Vannamei', 'Grower-1', '1.4 mm', 35, 25, 'pellet'),
  ('Growel', '6P', 'Marigold', 'Vannamei', 'Grower-2', '1.6 mm', 35, 25, 'pellet'),
  ('Growel', '7P', 'Marigold', 'Vannamei', 'Finisher', '1.8 mm', 35, 25, 'pellet'),

  ('Growel', '3P', 'Sprint', 'Vannamei', 'Starter', '1.6 mm', 34, 25, 'pellet'),
  ('Growel', '4P', 'Sprint', 'Vannamei', 'Grower-1', '1.8 mm', 34, 25, 'pellet'),
  ('Growel', '5P', 'Sprint', 'Vannamei', 'Grower-2', '2.0 mm', 32, 25, 'pellet'),
  ('Growel', '6P', 'Sprint', 'Vannamei', 'Grower-3', '2.2 mm', 32, 25, 'pellet'),
  ('Growel', '7P', 'Sprint', 'Vannamei', 'Finisher-1', '2.5 mm', 30, 25, 'pellet'),
  ('Growel', '8P', 'Sprint', 'Vannamei', 'Finisher-2', '2.8 mm', 30, 25, 'pellet')
ON CONFLICT DO NOTHING;

-- ─── 7. Seed: Product Master (supplements) ───────────────────
INSERT INTO public.product_master
  (brand, product_name, category, sub_category, form, unit_type, package_size, base_unit)
VALUES
  -- Feed Supplements
  ('Nutrimax', 'Nutriva Plus 3S1',  'Feed Supplement', 'Growth Booster',  'powder', 'g',  1000, 'g'),
  ('Nutrimax', 'Nutriva 1C',        'Feed Supplement', 'Immunity',        'powder', 'g',  500,  'g'),
  ('Sprint',   'Sprint 4P',         'Feed Supplement', 'Growth Booster',  'powder', 'g',  1000, 'g'),
  ('CARPMAX',  'CARPMAX 1',         'Feed Supplement', 'Immunity',        'powder', 'g',  500,  'g'),
  ('Growmax',  'Growmax Pro',       'Feed Supplement', 'Growth Booster',  'powder', 'g',  1000, 'g'),
  ('Immunovet','Immunoboost',       'Feed Supplement', 'Immunity',        'powder', 'g',  500,  'g'),
  ('Vetcare',  'VetProbiotic Plus', 'Feed Supplement', 'Probiotic',       'powder', 'g',  500,  'g'),
  ('Growel',   'AquaGrow',          'Feed Supplement', 'Growth Booster',  'powder', 'g',  1000, 'g'),
  ('Aquasave', 'Stress Guard',      'Feed Supplement', 'Stress Recovery', 'powder', 'g',  500,  'g'),
  ('Nutrision','Vit C 35',          'Feed Supplement', 'Vitamins',        'powder', 'g',  1000, 'g'),

  -- Water Supplements
  ('Generic',  'Zeolite',           'Water Supplement','Mineral',         'granule','kg', 25,   'kg'),
  ('Generic',  'Dolomite',          'Water Supplement','Mineral',         'powder', 'kg', 50,   'kg'),
  ('Generic',  'Calcium Carbonate', 'Water Supplement','Mineral',         'powder', 'kg', 50,   'kg'),
  ('Generic',  'Pond Mineral',      'Water Supplement','Mineral',         'powder', 'kg', 25,   'kg'),
  ('Generic',  'Water Conditioner', 'Water Supplement','Water Treatment', 'liquid', 'ml', 1000, 'ml'),
  ('Probiogen','Probiotic Mix',     'Water Supplement','Probiotic',       'powder', 'g',  500,  'g'),
  ('Aquacare', 'BKC 50%',           'Water Supplement','Disinfectant',    'liquid', 'ml', 1000, 'ml'),
  ('Generic',  'Lime (CaO)',        'Water Supplement','Mineral',         'powder', 'kg', 50,   'kg'),
  ('Aquaone',  'Aqua Probiotic',    'Water Supplement','Probiotic',       'powder', 'g',  500,  'g'),
  ('Generic',  'EDTA',              'Water Supplement','Water Treatment', 'powder', 'g',  1000, 'g'),

  -- Probiotics
  ('Biomin',   'BIOMIN P.E.P.',     'Probiotic',       NULL,              'powder', 'g',  1000, 'g'),
  ('Sanzyme',  'Sanzyme Aqua',      'Probiotic',       NULL,              'powder', 'g',  500,  'g'),

  -- Minerals
  ('Generic',  'MgSO4 (Epsom Salt)','Mineral',         NULL,              'powder', 'kg', 25,   'kg'),
  ('Generic',  'KCl (Potash)',       'Mineral',         NULL,              'powder', 'kg', 25,   'kg'),

  -- Medicines
  ('Vetcare',  'OTC (Oxytetracycline)','Medicine',      'Antibiotic',      'powder', 'g',  100,  'g'),
  ('Vetcare',  'Ciprofloxacin',     'Medicine',        'Antibiotic',      'powder', 'g',  100,  'g'),

  -- Pond Preparation
  ('Generic',  'Urea',              'Pond Preparation','Fertilizer',      'granule','kg', 50,   'kg'),
  ('Generic',  'DAP',               'Pond Preparation','Fertilizer',      'granule','kg', 50,   'kg'),
  ('Generic',  'Bleaching Powder',  'Pond Preparation','Disinfectant',    'powder', 'kg', 25,   'kg'),

  -- Water Treatment
  ('Generic',  'Alum',              'Water Treatment', NULL,              'powder', 'kg', 25,   'kg'),
  ('Generic',  'Potassium Permanganate','Water Treatment',NULL,           'powder', 'g',  500,  'g')
ON CONFLICT DO NOTHING;

-- ─── 8. Seed: Feed Master Product Prices ───────────────────────
INSERT INTO public.prices
  (product_id, product_type, price, unit, effective_date, active)
-- Non-Growel prices (unambiguous brand+code matches)
SELECT fmp.id, 'feed'::TEXT, price_data.price_per_kg::NUMERIC, 'kg'::TEXT, CURRENT_DATE, true
FROM (VALUES
  ('CP India Pvt Ltd', '7701', 108.9072),
  ('CP India Pvt Ltd', '7702', 108.9072),
  ('CP India Pvt Ltd', '7703', 108.4132),
  ('CP India Pvt Ltd', '7704', 108.4132),
  ('CP India Pvt Ltd', '7704S', 106.88),
  ('Avanti Feeds Limited', '1', 110.64),
  ('Avanti Feeds Limited', '2', 102.23),
  ('Avanti Feeds Limited', '3P', 101.73),
  ('Avanti Feeds Limited', '3S', 101.73),
  ('Avanti Feeds Limited', '3M', 100.73),
  ('Avanti Feeds Limited', '3L', 100.23),
  ('Nexgen Feeds', '1', 102.07),
  ('Nexgen Feeds', '2P', 102.07),
  ('Nexgen Feeds', '3P', 102.07),
  ('Nexgen Feeds', '3SP', 101.57),
  ('Nexgen Feeds', '3SP+', 101.57),
  ('Nexgen Feeds', '3M', 101.57),
  ('Nexgen Feeds', '3L', 100.68),
  ('Nexgen Feeds', '4', 143.31),
  ('Skretting', '1', 85),
  ('Skretting', '2', 108.95),
  ('Skretting', '3', 108.95),
  ('Skretting', '4', 108.95),
  ('Skretting', '5', 108.95),
  ('Skretting', '6', 108.95),
  ('Skretting', '7', 108.95),
  ('Skretting', '8', 108.95),
  ('Sandhya Marines Limited', '1C', 38.9124),
  ('Sandhya Marines Limited', '2', 89.7248),
  ('Sandhya Marines Limited', '2P', 90.6864),
  ('Sandhya Marines Limited', '3S', 89.7248),
  ('Sandhya Marines Limited', '3SP', 89.1616),
  ('Sandhya Marines Limited', '3P', 89.1616),
  ('Sandhya Marines Limited', '3L', 89.1616),
  ('Sandhya Marines Limited', '4M', 88.1408),
  ('Kingmei', '1', 103.996),
  ('Kingmei', '2', 103.996),
  ('Kingmei', '2P', 103.996),
  ('Kingmei', '3SP', 103.5),
  ('Kingmei', '3P', 103.5),
  ('Kingmei', '3S', 103.5),
  ('Kingmei', '4M', 103.5),
  ('Kingmei', '4L', 103.5)
) AS price_data(brand, product_code, price_per_kg)
JOIN public.feed_master_products fmp
  ON fmp.brand = price_data.brand AND fmp.product_code = price_data.product_code

UNION ALL

-- Growel Nutriva Plus prices
SELECT fmp.id, 'feed'::TEXT, 70::NUMERIC, 'kg'::TEXT, CURRENT_DATE, true
FROM public.feed_master_products fmp
WHERE fmp.brand = 'Growel' AND fmp.product_name = 'Nutriva Plus'

UNION ALL

-- Growel Nutriva prices
SELECT fmp.id, 'feed'::TEXT, 58::NUMERIC, 'kg'::TEXT, CURRENT_DATE, true
FROM public.feed_master_products fmp
WHERE fmp.brand = 'Growel' AND fmp.product_name = 'Nutriva'

UNION ALL

-- Growel Marigold prices
SELECT fmp.id, 'feed'::TEXT, 60::NUMERIC, 'kg'::TEXT, CURRENT_DATE, true
FROM public.feed_master_products fmp
WHERE fmp.brand = 'Growel' AND fmp.product_name = 'Marigold'

UNION ALL

-- Growel Sprint prices
SELECT fmp.id, 'feed'::TEXT, 50::NUMERIC, 'kg'::TEXT, CURRENT_DATE, true
FROM public.feed_master_products fmp
WHERE fmp.brand = 'Growel' AND fmp.product_name = 'Sprint'
ON CONFLICT DO NOTHING;
