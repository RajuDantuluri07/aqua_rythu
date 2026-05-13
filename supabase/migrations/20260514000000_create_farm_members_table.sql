-- =============================================================
-- Create farm_members table for managing farm team roles
-- =============================================================
CREATE TABLE IF NOT EXISTS public.farm_members (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  farm_id         UUID          NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
  email           TEXT          NOT NULL,
  role            TEXT          NOT NULL CHECK (role IN ('farmer', 'partner', 'supervisor', 'worker')),
  invited_by      UUID          REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ   DEFAULT now(),
  updated_at      TIMESTAMPTZ   DEFAULT now(),

  -- Prevent duplicate members per farm
  UNIQUE(farm_id, email)
);

ALTER TABLE public.farm_members ENABLE ROW LEVEL SECURITY;

-- Policy: Farm owner can see all members of their farms
CREATE POLICY "farm_members_select"
  ON public.farm_members FOR SELECT
  USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));

-- Policy: Farm owner can add members to their farms
CREATE POLICY "farm_members_insert"
  ON public.farm_members FOR INSERT
  WITH CHECK (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));

-- Policy: Farm owner can delete members from their farms
CREATE POLICY "farm_members_delete"
  ON public.farm_members FOR DELETE
  USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));

-- Trigger to update updated_at
CREATE TRIGGER farm_members_updated_at
  BEFORE UPDATE ON public.farm_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_farm_members_farm_id ON public.farm_members(farm_id);
CREATE INDEX IF NOT EXISTS idx_farm_members_email ON public.farm_members(email);
