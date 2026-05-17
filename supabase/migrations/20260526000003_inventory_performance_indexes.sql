-- Performance indexes for the most common inventory query patterns.
-- Addresses the missing index on (farm_id, category, is_auto_tracked) that
-- every inventory_stock_view lookup and getFeedItemForFarm() scan hits.

-- Composite index for farm + category filter (getInventoryStock, dashboard)
CREATE INDEX IF NOT EXISTS idx_inventory_items_farm_category
  ON public.inventory_items(farm_id, category)
  WHERE deleted_at IS NULL;

-- Partial index for feed item lookup (getFeedItemForFarm, deduction path)
CREATE INDEX IF NOT EXISTS idx_inventory_items_feed_auto
  ON public.inventory_items(farm_id)
  WHERE category = 'feed'
    AND is_auto_tracked = TRUE
    AND deleted_at IS NULL;

-- Consumption date range index (getTodayUsage, stock view aggregation)
CREATE INDEX IF NOT EXISTS idx_inventory_consumption_item_date
  ON public.inventory_consumption(item_id, date DESC);
