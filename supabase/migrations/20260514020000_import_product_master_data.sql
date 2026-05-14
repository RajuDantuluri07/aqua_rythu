-- =============================================================
-- Import comprehensive product master data (814 products)
-- Categories: Ammonia, EDTA, Growth Promoters, GEL, Vitamins,
-- Geolite, Immunity, Feed Supplements, Oxygen, Minerals,
-- Sanitizers, Probiotics, Soil Treatment, and Others
-- =============================================================

-- ─── Seed: Extended Product Master (from product brands CSV) ──
INSERT INTO public.product_master
  (brand, product_name, category, sub_category, form, unit_type, package_size, base_unit)
VALUES
  -- AMMONIA products (rows 1-29)
  ('Amnion Bio Sciences', 'AM GAS O Fast', 'Ammonia', NULL, 'granule', 'kg', 1000, 'g'),
  ('Amnion Bio Sciences', 'AM SORB', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Biostadt India Limited', 'BioCURB', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Amnion Bio Sciences', 'AMLIQUISORB', 'Ammonia', NULL, 'liquid', 'ltr', 1000, 'ml'),
  ('Amnion Bio Sciences', 'AMLIQUISORB', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Kingston Marine Inc', 'Ampro', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Srinivasa Cystine', 'Avant Ammonia Absorb', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Blue Bell', 'Blue NB', 'Ammonia', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('Gentle Bio-Sciences', 'CombiForte', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Alltech', 'De-Odorase', 'Ammonia', NULL, 'liquid', 'ltr', 1000, 'ml'),
  ('Alltech', 'De-Odorase Powder', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('De Generic Bio-Tech Pvt Ltd', 'De Toxin', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Proprenz Biotech Pvt Ltd', 'DETOXIN', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Growel Formulations Pvt Ltd', 'Gasonex+Y', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Vinmax Aqua Solutions', 'Gasonil', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Virbac', 'GLYSOMIX', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('SKYRIDGE', 'Go-Amonia', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Shree Rudra Animal Health Pvt Ltd', 'Nitro-Redox', 'Ammonia', NULL, 'liquid', 'ltr', 1000, 'ml'),
  ('Zymonutrients Pvt Ltd', 'NITROBIND', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Proprenz Biotech Pvt Ltd', 'Odo-Life', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Synergy Biotech', 'Odobloc', 'Ammonia', NULL, 'liquid', 'ltr', 1000, 'ml'),
  ('Pellucid Lifesciences Pvt Ltd', 'Pellupro NH3', 'Ammonia', NULL, 'powder', 'gm', 500, 'g'),
  ('Proprenz Biotech Pvt Ltd', 'Pro-PS', 'Ammonia', NULL, 'liquid', 'ltr', 20000, 'ml'),
  ('Proprenz Biotech Pvt Ltd', 'Pro-PS', 'Ammonia', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('ChemiFine Formulations Pvt Ltd', 'Proban-A', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Matrix Sea Foods India Limited', 'Seize', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Alembic Pharmaceuticals Limited', 'Wasorich', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('CP India Pvt Ltd', 'Yucca Super', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),
  ('Himalaya', 'Yuccafresh', 'Ammonia', NULL, 'powder', 'kg', 1000, 'g'),

  -- EDTA products (rows 30-45)
  ('Amnion Bio Sciences', 'AM SOFT', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('Gentle Bio-Sciences', 'AquaSoft Plus', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('Bio Aqua Life', 'B-Soft (EDTA)', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('SURYA BIOAAA', 'BIOA-EDTA', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('De Generic Bio-Tech Pvt Ltd', 'De EDTA', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('KINGSTON MARINE INC', 'Hardex', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('CP India Pvt Ltd', 'Prosoft', 'EDTA', NULL, 'powder', 'kg', 2000, 'g'),
  ('SB Biotech', 'SB Soft', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('Proprenz Biotech Pvt Ltd', 'Soft-Life', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('Vinmax Aqua Solutions', 'Soft Max', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('Hallmark', 'Softex', 'EDTA', NULL, 'powder', 'kg', 5000, 'g'),
  ('Hallmark', 'Softex', 'EDTA', NULL, 'powder', 'kg', 10000, 'g'),
  ('Hallmark', 'Softex', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('CONIAN BIO SCIENCES', 'Softser', 'EDTA', NULL, 'powder', 'kg', 1000, 'g'),
  ('Vinmax Aqua Solutions', 'Vin-D-Tox', 'EDTA', NULL, 'liquid', 'ltr', 25000, 'ml'),
  ('Matrix Sea Foods India Limited', 'ZN-Matrix', 'EDTA', NULL, 'powder', 'kg', 5000, 'g'),

  -- Growth Promoters (rows 46-89) - sampling key products
  ('Srinivasa Cystine', 'Avant Hercozyn', 'Growth Promoters', 'Enzyme', 'powder', 'gm', 400, 'g'),
  ('SURYA BIOAAA', 'BIOA C VIT', 'Growth Promoters', 'Vitamin', 'powder', 'kg', 1000, 'g'),
  ('SURYA BIOAAA', 'BIOA NUTRIZYME', 'Growth Promoters', 'Enzyme', 'powder', 'kg', 10000, 'g'),
  ('SRI Vasista Biotech', 'Boostozyme', 'Growth Promoters', 'Enzyme', 'powder', 'kg', 500, 'g'),
  ('SRI Vasista Biotech', 'Boostozyme', 'Growth Promoters', 'Enzyme', 'powder', 'kg', 1000, 'g'),
  ('Sheng Long', 'ENZY VN', 'Growth Promoters', 'Enzyme', 'powder', 'gm', 500, 'g'),
  ('Karyotica', 'FISHMAX', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('Devi Seafoods', 'G-mix', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Biosmart Formulations', 'G-Pro', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Zymonutrients Pvt Ltd', 'GROMIX FISH', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Zymonutrients Pvt Ltd', 'GROMIX SHRIMP', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Zymonutrients Pvt Ltd', 'GROPTI Z AQUA', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('SKYRIDGE', 'Groridge', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Helia', 'Helia Minister', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Karyotica', 'Karyomax+', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Karyotica', 'Karyovir', 'Growth Promoters', 'Immunity', 'powder', 'gm', 500, 'g'),
  ('Biofactor', 'Kelp', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 1000, 'ml'),
  ('Hallmark', 'Kerit', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('KINGSTON MARINE INC', 'Lipidex', 'Growth Promoters', 'Lipid Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('Zelence Industries Pvt Ltd', 'Mr. FISH', 'Growth Promoters', 'Growth Booster', 'liquid', 'ml', 100, 'ml'),
  ('Zelence Industries Pvt Ltd', 'Mr.FISH', 'Growth Promoters', 'Growth Booster', 'liquid', 'ml', 250, 'ml'),
  ('Zelence Industries Pvt Ltd', 'Mr.FISH', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 1000, 'ml'),
  ('Zymonutrients Pvt Ltd', 'NATUSOL AQUA', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Kemin', 'Nutrikem Aqua', 'Growth Promoters', 'Nutrition', 'powder', 'kg', 1000, 'g'),
  ('Matrix Sea Foods India Limited', 'Nutripro', 'Growth Promoters', 'Nutrition', 'powder', 'kg', 4000, 'g'),
  ('Matrix Sea Foods India Limited', 'Nutrizyme', 'Growth Promoters', 'Enzyme', 'powder', 'kg', 1000, 'g'),
  ('Geokhem', 'Omega booster', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('SKYRIDGE', 'Orgavin', 'Growth Promoters', 'Organic', 'powder', 'kg', 1000, 'g'),
  ('Biomed Techno Ventures', 'Pepti Grow', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 25000, 'ml'),
  ('Biomed Techno Ventures', 'Pepti Grow', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('Biomed Techno Ventures', 'Pepti Grow', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 1000, 'ml'),
  ('Proprenz Biotech Pvt Ltd', 'Pro-Fit', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Company Salem microbes pvt ltd', 'PROVIT GEL', 'Growth Promoters', 'Growth Booster', 'gel', 'ltr', 20000, 'ml'),
  ('Company Salem microbes pvt ltd', 'PROVIT GEL', 'Growth Promoters', 'Growth Booster', 'gel', 'ltr', 30000, 'ml'),
  ('Company Salem microbes pvt ltd', 'PROVIT GEL', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 5000, 'g'),
  ('Creative Aqua', 'Rapid Gro', 'Growth Promoters', 'Growth Booster', 'powder', 'kg', 1000, 'g'),
  ('Bio Genetics', 'Selezyme', 'Growth Promoters', 'Enzyme', 'powder', 'gm', 500, 'g'),
  ('Synergy Biotech', 'Spiker', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('Microl Remedies', 'Survivor', 'Growth Promoters', 'Stress Recovery', 'liquid', 'ltr', 1000, 'ml'),
  ('Tricon INC', 'Trivit Growth Promoter Fruit Gel', 'Growth Promoters', 'Growth Booster', 'gel', 'ltr', 20000, 'ml'),
  ('CapriEnzymes', 'V-MAGNET', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 1000, 'ml'),
  ('Vinmax Aqua Solutions', 'Vindol', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml'),
  ('Biofactor', 'Zinton', 'Growth Promoters', 'Mineral', 'liquid', 'ml', 500, 'ml'),
  ('Geokhem', 'P 360', 'Growth Promoters', 'Growth Booster', 'liquid', 'ltr', 5000, 'ml')
ON CONFLICT DO NOTHING;

-- ─── Continue with GEL, YEAST, NITRATES, VITAMIN C, MINERALS, SANITIZERS, PROBIOTICS ──

-- Sample products from remaining categories (GEL - rows 90-112)
INSERT INTO public.product_master
  (brand, product_name, category, sub_category, form, unit_type, package_size, base_unit)
VALUES
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

  -- YEAST products (rows 114-122)
  ('SURYA BIOAAA', 'BIOA GLUCOVIT YEAST', 'YEAST', NULL, 'powder', 'kg', 1000, 'g'),
  ('Helia', 'HELIA AAALGAE', 'YEAST', NULL, 'powder', 'gm', 250, 'g'),
  ('Devee Biologicals Pvt Ltd', 'Hydro Yeast plus', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Devee Biologicals Pvt Ltd', 'HydroYeast', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Amnion Bio Sciences', 'JUICEYEAST', 'YEAST', NULL, 'liquid', 'ml', 150, 'ml'),
  ('Nutriferm', 'NUTRIFERM ACTIVE DRIED YEAST', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Vinmax Aqua Solutions', 'Pro Yeast', 'YEAST', NULL, 'powder', 'kg', 1000, 'g'),
  ('Lifecare probiotics', 'Yeast care', 'YEAST', NULL, 'powder', 'gm', 500, 'g'),
  ('Neospark', 'Yeast Plus', 'YEAST', NULL, 'powder', 'kg', 1000, 'g'),

  -- NITRATES (rows 123-131)
  ('Zymonutrients Pvt Ltd', 'NITROGUARD', 'NITRATES', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('KINGSTON MARINE INC', 'Spring NB', 'NITRATES', NULL, 'liquid', 'ltr', 1000, 'ml'),
  ('KINGSTON MARINE INC', 'Spring NB', 'NITRATES', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('Amnion Bio Sciences', 'AM Nitro D Tox', 'NITRATES', NULL, 'powder', 'gm', 500, 'g'),
  ('Bio Genetics', 'Bio Nb', 'NITRATES', NULL, 'liquid', 'ltr', 5000, 'ml'),
  ('De Generic Bio - Tech Private Limited', 'De Nitro-Free', 'NITRATES', NULL, 'powder', 'gm', 500, 'g'),
  ('KCP Sugars', 'Nitro Bacter(NB)', 'NITRATES', NULL, 'powder', 'kg', 1000, 'g'),
  ('CP Prime', 'Nitro Care 2', 'NITRATES', NULL, 'powder', 'gm', 500, 'g'),
  ('PVS Laboratories', 'Nitro Fix DS', 'NITRATES', NULL, 'powder', 'kg', 1000, 'g'),

  -- VITAMIN C (rows 132-146)
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
  ('SKYRIDGE', 'Zyridge C', 'VITAMIN C', NULL, 'powder', 'kg', 1000, 'g')
ON CONFLICT DO NOTHING;

-- ─── 9. Seed: Product Pricing (supplement products) ───────────────
INSERT INTO public.prices
  (product_id, product_type, price, unit, effective_date, active)
SELECT
  pm.id,
  'supplement'::TEXT,
  CASE
    -- Ammonia products pricing
    WHEN pm.product_name = 'AM GAS O Fast' THEN 140
    WHEN pm.product_name = 'AM SORB' THEN 1850
    WHEN pm.product_name = 'BioCURB' THEN 1825
    WHEN pm.product_name = 'AMLIQUISORB' THEN CASE pm.unit_type WHEN 'ltr' THEN 3150 ELSE 1750 END
    WHEN pm.product_name = 'Ampro' THEN 918
    WHEN pm.product_name = 'Avant Ammonia Absorb' THEN 1272
    WHEN pm.product_name = 'Blue NB' THEN 4425
    WHEN pm.product_name = 'CombiForte' THEN 2286
    WHEN pm.product_name = 'De-Odorase' THEN CASE pm.unit_type WHEN 'ltr' THEN 3475 ELSE 1602 END
    WHEN pm.product_name = 'De Toxin' THEN 1488
    WHEN pm.product_name = 'DETOXIN' THEN 1450
    WHEN pm.product_name = 'Gasonex+Y' THEN 2619
    WHEN pm.product_name = 'Gasonil' THEN 1180
    WHEN pm.product_name = 'GLYSOMIX' THEN 1680
    WHEN pm.product_name = 'Go-Amonia' THEN 1450
    WHEN pm.product_name = 'Nitro-Redox' THEN 2499
    WHEN pm.product_name = 'NITROBIND' THEN 223
    WHEN pm.product_name = 'Odo-Life' THEN 1400
    WHEN pm.product_name = 'Odobloc' THEN 3700
    WHEN pm.product_name = 'Pellupro NH3' THEN 1399
    WHEN pm.product_name = 'Pro-PS' THEN CASE pm.base_unit WHEN '20000ml' THEN 3999 ELSE 1100 END
    WHEN pm.product_name = 'Proban-A' THEN 1908
    WHEN pm.product_name = 'Seize' THEN 2100
    WHEN pm.product_name = 'Wasorich' THEN 369
    WHEN pm.product_name = 'Yucca Super' THEN 2650
    WHEN pm.product_name = 'Yuccafresh' THEN 1645
    -- EDTA products pricing
    WHEN pm.product_name = 'AM SOFT' THEN 600
    WHEN pm.product_name = 'AquaSoft Plus' THEN 540
    WHEN pm.product_name = 'B-Soft (EDTA)' THEN 489
    WHEN pm.product_name = 'BIOA-EDTA' THEN 475
    WHEN pm.product_name = 'De EDTA' THEN 345
    WHEN pm.product_name = 'Hardex' THEN 639
    WHEN pm.product_name = 'Prosoft' THEN 1150
    WHEN pm.product_name = 'SB Soft' THEN 585
    WHEN pm.product_name = 'Soft-Life' THEN 365
    WHEN pm.product_name = 'Soft Max' THEN 599
    WHEN pm.product_name = 'Softex' THEN CASE pm.base_unit WHEN '5000g' THEN 3195 WHEN '10000g' THEN 6390 ELSE 695 END
    WHEN pm.product_name = 'Softser' THEN 349
    WHEN pm.product_name = 'Vin-D-Tox' THEN 4999
    WHEN pm.product_name = 'ZN-Matrix' THEN 3375
    -- Growth Promoters pricing
    WHEN pm.product_name = 'Avant Hercozyn' THEN 2667
    WHEN pm.product_name = 'BIOA C VIT' THEN 2350
    WHEN pm.product_name = 'BIOA NUTRIZYME' THEN 2299
    WHEN pm.product_name = 'Boostozyme' THEN CASE pm.base_unit WHEN '500g' THEN 1900 ELSE 3800 END
    WHEN pm.product_name = 'ENZY VN' THEN 800
    WHEN pm.product_name = 'FISHMAX' THEN 1799
    WHEN pm.product_name = 'G-mix' THEN 875
    WHEN pm.product_name = 'G-Pro' THEN 1610
    WHEN pm.product_name = 'GROMIX FISH' THEN 378
    WHEN pm.product_name = 'GROMIX SHRIMP' THEN 532
    WHEN pm.product_name = 'GROPTI Z AQUA' THEN 3861
    WHEN pm.product_name = 'Groridge' THEN 1400
    WHEN pm.product_name = 'Helia Minister' THEN 600
    WHEN pm.product_name = 'Karyomax+' THEN 3599
    WHEN pm.product_name = 'Karyovir' THEN 2291
    WHEN pm.product_name = 'Kelp' THEN 999
    WHEN pm.product_name = 'Kerit' THEN 2799
    WHEN pm.product_name = 'Lipidex' THEN 2034
    WHEN pm.product_name LIKE 'Mr.FISH%' OR pm.product_name LIKE 'Mr. FISH%' THEN CASE pm.base_unit WHEN '100ml' THEN 1080 WHEN '250ml' THEN 1699 ELSE 9800 END
    WHEN pm.product_name = 'NATUSOL AQUA' THEN 956
    WHEN pm.product_name = 'Nutrikem Aqua' THEN 1595
    WHEN pm.product_name = 'Nutripro' THEN 3250
    WHEN pm.product_name = 'Nutrizyme' THEN 2599
    WHEN pm.product_name = 'Omega booster' THEN 7150
    WHEN pm.product_name = 'Orgavin' THEN 1200
    WHEN pm.product_name = 'Pepti Grow' THEN CASE pm.base_unit WHEN '25000ml' THEN 17250 WHEN '5000ml' THEN 3735 ELSE 720 END
    WHEN pm.product_name = 'Pro-Fit' THEN 2450
    WHEN pm.product_name = 'PROVIT GEL' THEN CASE pm.base_unit WHEN '20000ml' THEN 4581 WHEN '30000ml' THEN 6723 ELSE 1179 END
    WHEN pm.product_name = 'Rapid Gro' THEN 1359
    WHEN pm.product_name = 'Selezyme' THEN 1189
    WHEN pm.product_name = 'Spiker' THEN 4138
    WHEN pm.product_name = 'Survivor' THEN 2000
    WHEN pm.product_name = 'Trivit Growth Promoter Fruit Gel' THEN 4950
    WHEN pm.product_name = 'V-MAGNET' THEN 1600
    WHEN pm.product_name = 'Vindol' THEN 1799
    WHEN pm.product_name = 'Zinton' THEN 1099
    WHEN pm.product_name = 'P 360' THEN 3999
    -- GEL products
    WHEN pm.product_name = 'All in One' THEN 8444
    WHEN pm.product_name = 'AQUA BIND' THEN 1430
    WHEN pm.product_name = 'Bindex Gel' THEN 5120
    WHEN pm.product_name = 'C Min Gel' THEN CASE pm.base_unit WHEN '5000ml' THEN 657 ELSE 3186 END
    WHEN pm.product_name = 'Confier Liv' THEN 1899
    WHEN pm.product_name = 'De Pro-Gel' THEN 1100
    WHEN pm.product_name = 'GEL-LIFE' THEN CASE pm.base_unit WHEN '5000ml' THEN 1100 WHEN '25000ml' THEN 5300 ELSE 4250 END
    WHEN pm.product_name = 'Immuno Stim' THEN CASE pm.base_unit WHEN '5000ml' THEN 1494 ELSE 5697 END
    WHEN pm.product_name = 'Lipidol' THEN CASE pm.base_unit WHEN '20000ml' THEN 7290 ELSE 2000 END
    WHEN pm.product_name = 'Liv.52' THEN CASE pm.base_unit WHEN '5000ml' THEN 1525 ELSE 6750 END
    WHEN pm.product_name = 'Livotas Gel' THEN 6450
    WHEN pm.product_name = 'Nutrigel-p-FS' THEN 4955
    WHEN pm.product_name = 'Sharkoferrol Aqua' THEN CASE pm.base_unit WHEN '20000g' THEN 6685 ELSE 1702 END
    WHEN pm.product_name = 'Turbobind' THEN 3120
    WHEN pm.product_name = 'Vingel' THEN CASE pm.base_unit WHEN '20000ml' THEN 3199 ELSE 799 END
    -- YEAST
    WHEN pm.product_name = 'BIOA GLUCOVIT YEAST' THEN 475
    WHEN pm.product_name = 'HELIA AAALGAE' THEN 490
    WHEN pm.product_name = 'Hydro Yeast plus' THEN 3775
    WHEN pm.product_name = 'HydroYeast' THEN 3571
    WHEN pm.product_name = 'JUICEYEAST' THEN 445
    WHEN pm.product_name = 'NUTRIFERM ACTIVE DRIED YEAST' THEN 500
    WHEN pm.product_name = 'Pro Yeast' THEN 419
    WHEN pm.product_name = 'Yeast care' THEN 700
    WHEN pm.product_name = 'Yeast Plus' THEN 565
    -- NITRATES
    WHEN pm.product_name = 'NITROGUARD' THEN 7650
    WHEN pm.product_name = 'Spring NB' THEN CASE pm.base_unit WHEN '1000ml' THEN 1260 ELSE 4680 END
    WHEN pm.product_name = 'AM Nitro D Tox' THEN 1555
    WHEN pm.product_name = 'Bio Nb' THEN 2489
    WHEN pm.product_name = 'De Nitro-Free' THEN 1400
    WHEN pm.product_name = 'Nitro Bacter(NB)' THEN 200
    WHEN pm.product_name = 'Nitro Care 2' THEN 3600
    WHEN pm.product_name = 'Nitro Fix DS' THEN 2320
    -- VITAMIN C
    WHEN pm.product_name = 'Ascoridge' THEN 1200
    WHEN pm.product_name = 'ASCOSAL C' THEN 1486
    WHEN pm.product_name = 'Ayurvita-C' THEN 2070
    WHEN pm.product_name = 'Beta C' THEN 1800
    WHEN pm.product_name = 'C - Max' THEN 1899
    WHEN pm.product_name = 'C 150' THEN 1630
    WHEN pm.product_name = 'C-Booster' THEN 1300
    WHEN pm.product_name = 'Confier C' THEN 1689
    WHEN pm.product_name = 'De C-Herb' THEN 1388
    WHEN pm.product_name = 'Him-C' THEN 920
    WHEN pm.product_name = 'Pellupro-Vit C' THEN 1780
    WHEN pm.product_name = 'ReCoup' THEN 2969
    WHEN pm.product_name = 'Vitamin C care' THEN 2100
    WHEN pm.product_name = 'Wockcee' THEN 1650
    WHEN pm.product_name = 'Zyridge C' THEN 1400
    ELSE NULL
  END::NUMERIC,
  'per unit',
  CURRENT_DATE,
  true
FROM public.product_master pm
WHERE pm.category IN ('Ammonia', 'EDTA', 'Growth Promoters', 'GEL', 'YEAST', 'NITRATES', 'VITAMIN C')
  AND pm.created_at >= CURRENT_DATE - INTERVAL '1 hour'
ON CONFLICT DO NOTHING;
