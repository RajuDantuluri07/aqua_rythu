-- TICKET-027: Revoke client EXECUTE on safe_insert_feed_log RPC.
--
-- safe_insert_feed_log was the pre-Epic-7 feed write path. It uses only
-- (pond_id, doc, round) for deduplication — no operation_id. Now that
-- complete_feed_round_with_log (Epic 7) is the canonical path, keeping
-- safe_insert_feed_log callable by authenticated clients creates a bypass:
-- a client could write feed_logs rows without going through the idempotent
-- RPC, skipping the operation_id uniqueness guarantee.
--
-- Revoking EXECUTE means only service_role (edge functions, migrations) can
-- call it. The Dart code no longer calls it (removed in saveFeed() cleanup).

REVOKE EXECUTE ON FUNCTION safe_insert_feed_log FROM authenticated;
REVOKE EXECUTE ON FUNCTION safe_insert_feed_log FROM anon;

-- Grant only to service_role for any future admin tooling that may need it.
GRANT EXECUTE ON FUNCTION safe_insert_feed_log TO service_role;
