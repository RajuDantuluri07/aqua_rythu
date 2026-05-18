ALTER TABLE public.feed_master_products
  ADD COLUMN IF NOT EXISTS bag_price   numeric,
  ADD COLUMN IF NOT EXISTS price_per_kg numeric;

UPDATE public.feed_master_products AS f
SET bag_price = p.bag_price, price_per_kg = p.price_per_kg
FROM (VALUES
  -- CP India Pvt Ltd — Blanca
  ('900258fd-23e7-495d-8271-cfc2ee5ce765'::uuid, 2722.68, 108.9072),
  ('1e323f2e-f3e5-46ba-8523-5a88d2f82ad7'::uuid, 2722.68, 108.9072),
  ('3617bb99-f365-4c0e-93d7-b2607e469dba'::uuid, 2710.33, 108.4132),
  ('7bae607a-9ba2-4eef-90ac-72222587bb6b'::uuid, 2710.33, 108.4132),
  ('6dcff3f8-9414-43b3-a73b-68c132f05f3c'::uuid, 2672.00, 106.88),
  -- Avanti Feeds Limited — Manamei
  ('4c137865-4065-4423-b2d9-2d964d2db2e0'::uuid, 2766.00, 110.64),
  ('7826f7e1-582c-463d-bfe1-6099d3d46209'::uuid, 2555.75, 102.23),
  ('f7985432-3fe6-42e9-a6e5-d89050581e19'::uuid, 2543.25, 101.73),
  ('f1ea3b06-a6b7-4976-9ecb-97d691519f7c'::uuid, 2543.25, 101.73),
  ('f9bc3c6a-ddbd-4787-80ba-f66343853544'::uuid, 2518.25, 100.73),
  ('ffb58309-dc56-47a1-84c4-364c7d543d54'::uuid, 2505.75, 100.23),
  -- Nexgen Feeds — I Feed
  ('09d98ae5-d477-480b-8d2e-d6b06463be4d'::uuid, 2551.75, 102.07),
  ('8a38f193-4859-4774-bebd-63156f8202a7'::uuid, 2551.75, 102.07),
  ('ebc79db4-fc90-4b19-a0d3-26565ba57f48'::uuid, 2551.75, 102.07),
  ('5d1d9aa7-226f-48d6-b785-cc42d2ccf2ed'::uuid, 2539.25, 101.57),
  ('0e378c77-7361-49b5-aa43-7d13df0721f4'::uuid, 2539.25, 101.57),
  ('9742424e-026c-453d-962c-ec10381bb0dd'::uuid, 2539.25, 101.57),
  ('59aef8d9-9223-49e3-b388-dc2188839043'::uuid, 2517.00, 100.68),
  ('a167cee5-a0f6-4931-bf69-c97f42d797c6'::uuid, 3582.75, 143.31),
  -- Skretting — Gamma
  ('7fbe3eb0-0c25-4302-9ad6-8385c11b6a89'::uuid,  425.00,  85.00),
  ('9b3dea11-4058-4b73-94b5-502dba767d77'::uuid, 2723.75, 108.95),
  ('2bde1fd6-95f4-473f-9904-3f4ab3f00fa2'::uuid, 2723.75, 108.95),
  ('9d40b13b-c293-4de9-b192-f3bbd792e9a0'::uuid, 2723.75, 108.95),
  ('e77831a2-49c1-4d85-8272-97fd9271164c'::uuid, 2723.75, 108.95),
  ('0bbbe4e7-ea5b-4851-8080-3b00a3b3ca2e'::uuid, 2723.75, 108.95),
  ('b88e6b41-e365-4d0b-a7c8-951598391f2f'::uuid, 2723.75, 108.95),
  ('94ce80f6-20fe-4869-959d-9e75cb05fc5f'::uuid, 2723.75, 108.95),
  -- Sandhya Marines Limited — Sandhya
  ('0171e625-b475-417d-8b5e-a97e2c25077f'::uuid,  972.81,  38.9124),
  ('99a0f8f7-8af0-4746-a54e-96ea79fea66b'::uuid, 2243.12,  89.7248),
  ('0b93da09-5095-4af0-8142-c2e17a1f5b5e'::uuid, 2267.16,  90.6864),
  ('8dbcc283-7379-42a9-bdad-68f8a7ae5347'::uuid, 2243.12,  89.7248),
  ('aa4eaf94-bf69-43e8-bdea-a7daf370aaa7'::uuid, 2229.04,  89.1616),
  ('4522ff4f-d6ad-4954-8357-fcc7b504c48d'::uuid, 2229.04,  89.1616),
  ('99be1e89-4529-4f65-b790-38d27d6dff94'::uuid, 2229.04,  89.1616),
  ('8454ef6c-3cb5-491e-b9fe-d4be68b72baf'::uuid, 2203.52,  88.1408),
  -- Kingmei — Kingmei Bluecrown
  ('f455592b-9b20-4ac2-aa64-eddf2ab00154'::uuid, 2599.90, 103.996),
  ('c8520e2f-ed9b-4197-b0d3-1bca389cf307'::uuid, 2599.90, 103.996),
  ('b95f4001-0500-4641-b66f-754170a5757e'::uuid, 2599.90, 103.996),
  ('e930e9ea-59b0-46b4-a27c-477da2b6c771'::uuid, 2587.50, 103.50),
  ('da2b72b2-3735-4e46-80d5-f269cfd07696'::uuid, 2587.50, 103.50),
  ('b041ac95-19a1-4d4c-bb25-ac2d90416217'::uuid, 2587.50, 103.50),
  ('04e95545-c0a8-48ac-b434-4b055aa29373'::uuid, 2587.50, 103.50),
  ('a1781ec5-4d9f-411a-b810-88137158a2b5'::uuid, 2587.50, 103.50),
  -- Growel — Nutriva Plus
  ('375d6236-e4d9-4acc-94b6-7c34fad36d2d'::uuid, 1750.00,  70.00),
  ('5ee62d79-e208-441e-ab04-d1402fba8431'::uuid, 1750.00,  70.00),
  ('dd825304-e0e7-4fa3-8baf-7600459d23e9'::uuid, 1750.00,  70.00),
  ('682b2334-22aa-4174-800a-4baf1d372819'::uuid, 1750.00,  70.00),
  -- Growel — Nutriva
  ('60c94a4e-3fce-4c90-8b4d-9afdd2854524'::uuid, 1450.00,  58.00),
  ('84d523f5-c881-41dd-a821-777567971459'::uuid, 1450.00,  58.00),
  ('d8c76c28-db18-4f80-976d-d5feb72c16b6'::uuid, 1450.00,  58.00),
  ('4b27505c-9433-45ea-9229-ef611c8d5fe8'::uuid, 1450.00,  58.00),
  ('c935dcf8-2c1b-4ff2-b11d-c3dbf169ce3d'::uuid, 1450.00,  58.00),
  ('49548b80-a96d-4818-9041-da1760dcd800'::uuid, 1450.00,  58.00),
  ('cfb62876-e237-45ae-b994-77cb71762563'::uuid, 1450.00,  58.00),
  -- Growel — Marigold
  ('6a7238fc-2734-480f-ae3e-010e0ead63c6'::uuid, 1500.00,  60.00),
  ('541c302d-e898-4259-8425-bbf10149f659'::uuid, 1500.00,  60.00),
  ('eaac9ad6-d78f-4d82-b170-898eca4d326c'::uuid, 1500.00,  60.00),
  ('c60337c8-e600-4f35-bd50-bf995ba19f23'::uuid, 1500.00,  60.00),
  ('a1f0d1bb-f413-4bab-ad56-25f72c79e4aa'::uuid, 1500.00,  60.00),
  ('38799cfa-4de8-4a08-a90a-fec8968362fb'::uuid, 1500.00,  60.00),
  ('bf4456a1-5510-4897-9f0d-0e28c50d112a'::uuid, 1500.00,  60.00),
  -- Growel — Sprint
  ('c068bbac-9cda-446a-9435-d9e141de9527'::uuid, 1250.00,  50.00),
  ('e7a96719-7e9e-45b5-9992-e7a3c1b5bb2b'::uuid, 1250.00,  50.00),
  ('7422f4bb-4c80-4308-aa03-3945954a05b3'::uuid, 1250.00,  50.00),
  ('69b72eaa-3beb-4ab5-b41b-c23bd7450c37'::uuid, 1250.00,  50.00),
  ('eeda688f-b707-4bc9-bb8b-59f7f7bec12e'::uuid, 1250.00,  50.00),
  ('b7a92095-8b8b-4a8d-902c-3eeccb62be14'::uuid, 1250.00,  50.00)
) AS p(id, bag_price, price_per_kg)
WHERE f.id = p.id;
