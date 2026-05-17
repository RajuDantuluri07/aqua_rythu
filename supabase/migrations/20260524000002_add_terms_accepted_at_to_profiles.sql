-- Add terms_accepted_at to profiles.
-- Nullable so existing rows are unaffected; app records acceptance on next login.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ DEFAULT NULL;
