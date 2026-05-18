ALTER TABLE public.expenses DROP CONSTRAINT expenses_category_check;

ALTER TABLE public.expenses ADD CONSTRAINT expenses_category_check
  CHECK (category = ANY (ARRAY[
    'feed'::text,
    'supplement'::text,
    'seed'::text,
    'labour'::text,
    'electricity'::text,
    'diesel'::text,
    'sampling'::text,
    'other'::text
  ]));
