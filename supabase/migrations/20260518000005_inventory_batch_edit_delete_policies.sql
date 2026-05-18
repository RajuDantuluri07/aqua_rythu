-- Allow farm owner and privileged members (farmer / partner) to edit & delete batches.

CREATE POLICY inventory_batches_update ON public.inventory_batches
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.farm_members fm
      JOIN auth.users u ON u.email = fm.email
      WHERE fm.farm_id = inventory_batches.farm_id
        AND fm.role IN ('farmer', 'partner')
        AND u.id = auth.uid()
    )
  );

CREATE POLICY inventory_batches_delete ON public.inventory_batches
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.farm_members fm
      JOIN auth.users u ON u.email = fm.email
      WHERE fm.farm_id = inventory_batches.farm_id
        AND fm.role IN ('farmer', 'partner')
        AND u.id = auth.uid()
    )
  );

CREATE POLICY inventory_entries_update ON public.inventory_entries
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.farm_members fm
      JOIN auth.users u ON u.email = fm.email
      WHERE fm.farm_id = inventory_entries.farm_id
        AND fm.role IN ('farmer', 'partner')
        AND u.id = auth.uid()
    )
  );

CREATE POLICY inventory_entries_delete ON public.inventory_entries
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.farm_members fm
      JOIN auth.users u ON u.email = fm.email
      WHERE fm.farm_id = inventory_entries.farm_id
        AND fm.role IN ('farmer', 'partner')
        AND u.id = auth.uid()
    )
  );
