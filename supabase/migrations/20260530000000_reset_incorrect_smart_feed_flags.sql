-- Reset smart feed flags that were auto-set by the DOC-based activation code.
-- Only resets ponds where the farmer never explicitly completed smart initialization
-- (smart_feed_initialized = false means initializeSmartFeedPond() was never called).
-- Explicitly initialized ponds (smart_feed_initialized = true) are preserved.

UPDATE ponds
SET
  is_smart_feed_enabled     = false,
  anchor_feed               = null,
  is_anchor_initialized     = false,
  smart_feed_initialized_at = null,
  initialization_doc        = null,
  updated_at                = now()
WHERE
  status != 'harvested'
  AND (smart_feed_initialized IS NULL OR smart_feed_initialized = false)
  AND (anchor_feed IS NULL OR is_anchor_initialized = false);
