-- =============================================================
-- Batch 2: GEL, YEAST, NITRATES, VITAMIN C, GEOLITE products
-- =============================================================

-- GEL (23), YEAST (9), NITRATES (9), VITAMIN C (15), GEOLITE (18) = 74 products
INSERT INTO public.product_master
  (brand, product_name, category, sub_category, form, unit_type, package_size, base_unit)
VALUES
  -- GEL Products (23)
  ('Dr Pharma', 'All in One', 'GEL', NULL, 'gel', 'ltr', 25000, 'ml'),
  ('Aqua Seed Enterprise', 'AQUA BIND', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('Matrix Sea Foods India Limited', 'Bindex Gel', 'GEL', NULL, 'gel', 'ltr', 25000, 'ml'),
  ('ChemiFine Formulations Pvt Ltd', 'C Min Gel', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('ChemiFine Formulations Pvt Ltd', 'C Min Gel', 'GEL', NULL, 'gel', 'ltr', 20000, 'ml'),
  ('Confier International Pvt Ltd', 'Confier Liv', 'GEL', NULL, 'gel', 'gm', 500, 'g'),
  ('De Generic Bio - Tech Private Limited', 'De Pro-Gel', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('Proprenz Biotech Pvt Ltd', 'GEL-LIFE', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('Proprenz Biotech Pvt Ltd', 'GEL-LIFE', 'GEL', NULL, 'gel', 'ltr', 25000, 'ml'),
  ('Proprenz Biotech Pvt Ltd', 'GEL-LIFE', 'GEL', NULL, 'gel', 'ltr', 20000, 'ml'),
  ('Reddy Drugs(KGR Marketing)', 'Immuno Stim', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('Reddy Drugs(KGR Marketing)', 'Immuno Stim', 'GEL', NULL, 'gel', 'ltr', 20000, 'ml'),
  ('Hallmark', 'Lipidol', 'GEL', NULL, 'gel', 'ltr', 20000, 'ml'),
  ('Hallmark', 'Lipidol', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('Himalaya', 'Liv.52', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),
  ('Himalaya', 'Liv.52', 'GEL', NULL, 'gel', 'ltr', 30000, 'ml'),
  ('Intas Pharmaceutical Ltd', 'Livotas Gel', 'GEL', NULL, 'gel', 'ltr', 30000, 'ml'),
  ('Neospark', 'Nutrigel-p-FS', 'GEL', NULL, 'gel', 'ltr', 25000, 'ml'),
  ('Alembic Pharmaceuticals Limited', 'Sharkoferrol Aqua', 'GEL', NULL, 'gel', 'kg', 20000, 'g'),
  ('Alembic Pharmaceuticals Limited', 'Sharkoferrol Aqua', 'GEL', NULL, 'gel', 'kg', 5000, 'g'),
  ('CP India Pvt Ltd', 'Turbobind', 'GEL', NULL, 'gel', 'ltr', 20000, 'ml'),
  ('Vinmax Aqua Solutions', 'Vingel', 'GEL', NULL, 'gel', 'ltr', 20000, 'ml'),
  ('Vinmax Aqua Solutions', 'Vingel', 'GEL', NULL, 'gel', 'ltr', 5000, 'ml'),

  -- YEAST Products (9)
  ('SURYA BIOAAA', 'BIOA GLUCOVIT YEAST', 'YEAST', NULL, 'powder', 'kg', 1000, 'g'),
  ('Helia', 'HELIA AAALGAE', 'YEAST', NULL, 'powder', 'gm', 250, 'g'),
  ('Devee Biologicals Pvt Ltd', 'Hydro Yeast plus', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Devee Biologicals Pvt Ltd', 'HydroYeast', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Amnion Bio Sciences', 'JUICEYEAST', 'YEAST', NULL, 'liquid', 'ml', 150, 'ml'),
  ('Nutriferm', 'NUTRIFERM ACTIVE DRIED YEAST', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Vinmax Aqua Solutions', 'Pro Yeast', 'YEAST', NULL, 'powder', 'kg', 1000, 'g'),
  ('Lifecare probiotics', 'Yeast care', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Neospark', 'Yeast Plus', 'YEAST', NULL, 'powder', 'kg', 1000, 'g'),

  -- NITRATES (9)
  ('Zymonutrients Pvt Ltd', 'NITROGUARD', 'NITRATES', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('KINGSTON MARINE INC', 'Spring NB', 'NITRATES', NULL, 'liquid', 'ltr', 1000, 'ml'),
  ('KINGSTON MARINE INC', 'Spring NB', 'NITRATES', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('Amnion Bio Sciences', 'AM Nitro D Tox', 'NITRATES', NULL, 'powder', 'gm', 500, 'g'),
  ('Bio Genetics', 'Bio Nb', 'NITRATES', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('De Generic Bio - Tech Private Limited', 'De Nitro-Free', 'NITRATES', NULL, 'powder', 'gm', 500, 'g'),
  ('KCP Sugars', 'Nitro Bacter(NB)', 'NITRATES', NULL, 'powder', 'kg', 1000, 'g'),
  ('CP Prime', 'Nitro Care 2', 'NITRATES', NULL, 'powder', 'gm', 500, 'g'),
  ('PVS Laboratories', 'Nitro Fix DS', 'NITRATES', NULL, 'powder', 'kg', 1000, 'g'),

  -- VITAMIN C (15)
  ('SKYRIDGE', 'Ascoridge', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('Neospark', 'ASCOSAL C', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('Dharani', 'Ayurvita-C', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('Biofera', 'Beta C', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('Vinmax Aqua Solutions', 'C - Max', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('CP India Pvt Ltd', 'C 150', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('Amnion Bio Sciences', 'C-Booster', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('Confier International Pvt Ltd', 'Confier C', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('De Generic Bio - Tech Private Limited', 'De C-Herb', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('Himalaya', 'Him-C', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('Pellucid Lifesciences Pvt.Ltd', 'Pellupro-Vit C', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('Matrix sea Foods India Limited', 'ReCoup', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),
  ('Lifecare probiotics', 'Vitamin C care', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('Biostadt India Limited', 'Wockcee', 'VITAMIN C', NULL, 'powder', 'gm', 500, 'g'),
  ('SKYRIDGE', 'Zyridge C', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g'),

  -- GEOLITE (18)
  ('Aqua Seed Enterprise', 'AQUA BALL 10kg', 'GEOLITE', NULL, 'granule', 'kg', 10000, 'g'),
  ('Srinivasa Cystine', 'Avanti geo tuff', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('SURYA BIOAAA', 'BIOAZLITE', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('Biostadt India Limited', 'Clinzex - DS', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('De Generic Bio - Tech Private Limited', 'De Zeolite', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('De Generic Bio - Tech Private Limited', 'De Zeolite Granules', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('Sheng Long', 'La Zeo', 'GEOLITE', NULL, 'granule', 'kg', 20000, 'g'),
  ('Proprenz Biotech Pvt Ltd', 'Tox-Life [G]', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('Proprenz Biotech Pvt Ltd', 'Tox-Life [P]', 'GEOLITE', NULL, 'granule', 'kg', 25000, 'g'),
  ('Neospark', 'UltraSil - Aqua', 'GEOLITE', NULL, 'granule', 'kg', 20000, 'g'),
  ('Amnion Bio Sciences', 'ZEOKLEAN FORTE', 'GEOLITE', NULL, 'granule', 'kg', 20000, 'g'),
  ('Amnion Bio Sciences', 'ZEOKLEAN FORTE', 'GEOLITE', NULL, 'granule', 'kg', 5000, 'g'),
  ('Amnion Bio Sciences', 'ZEOKLEAN FORTE GRANULES', 'GEOLITE', NULL, 'granule', 'kg', 20000, 'g'),
  ('Amnion Bio Sciences', 'Zeoklean Forte Granules', 'GEOLITE', NULL, 'granule', 'kg', 5000, 'g'),
  ('Amnion Bio Sciences', 'ZEOKLEAN FORTE GRANULES', 'GEOLITE', NULL, 'granule', 'kg', 1000, 'g'),
  ('Amnion Bio Sciences', 'ZEOKLEAN FORTE GRANULES', 'GEOLITE', NULL, 'granule', 'kg', 10000, 'g'),
  ('Sheng Long', 'Zeolite', 'GEOLITE', NULL, 'granule', 'kg', 20000, 'g'),
  ('Hallmark', 'Megatron', 'LOOSE SHEEL', NULL, 'powder', 'kg', 1000, 'g')
ON CONFLICT DO NOTHING;
