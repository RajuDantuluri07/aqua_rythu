-- Migration: P0.6 Hardening - Data Integrity Monitoring Queries
-- Purpose: Detect data mismatches and inconsistencies
-- Run these queries periodically to catch edge-case bugs early

-- Query 1: Detect inconsistent states (status vs logs)
CREATE OR REPLACE VIEW data_integrity_check AS
SELECT 
  fr.id,
  fr.pond_id,
  fr.doc,
  fr.round,
  fr.status,
  COUNT(fl.id) as log_count,
  CASE 
    WHEN fr.status = 'completed' AND COUNT(fl.id) = 0 THEN 'ERROR: Status completed but no log'
    WHEN fr.status = 'pending' AND COUNT(fl.id) > 0 THEN 'ERROR: Status pending but log exists'
    WHEN COUNT(fl.id) > 1 THEN 'ERROR: Multiple logs for one round'
    ELSE 'OK'
  END as status_check
FROM feed_rounds fr
LEFT JOIN feed_logs fl ON fl.feed_round_id = fr.id
GROUP BY fr.id, fr.pond_id, fr.doc, fr.round, fr.status
ORDER BY status_check DESC, fr.created_at DESC;

COMMENT ON VIEW data_integrity_check IS
'Detects data integrity violations:
1. Status=completed but no log (orphaned status)
2. Status=pending but log exists (stale status)
3. Multiple logs per round (duplicate violation)
Run daily: SELECT * FROM data_integrity_check WHERE status_check != "OK"';

-- Query 2: Detect duplicate logs (UNIQUE constraint failure detection)
CREATE OR REPLACE VIEW duplicate_feed_logs_check AS
SELECT 
  feed_round_id,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::text, ', ') as log_ids,
  MAX(created_at) as latest_timestamp
FROM feed_logs
WHERE feed_round_id IS NOT NULL
GROUP BY feed_round_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

COMMENT ON VIEW duplicate_feed_logs_check IS
'Identifies duplicate feed_logs entries (UNIQUE constraint violation).
Should return 0 rows. If entries appear, it indicates:
1. UNIQUE constraint not enforced properly
2. Historical data before constraint was added
Run immediately: SELECT * FROM duplicate_feed_logs_check';

-- Query 3: Verify aggregation accuracy per pond per day
CREATE OR REPLACE VIEW feed_aggregation_check AS
SELECT 
  fl.pond_id,
  DATE(fl.created_at) as feed_date,
  COUNT(DISTINCT fl.feed_round_id) as unique_rounds,
  SUM(fl.feed_given) as total_feed_given,
  MIN(fl.created_at) as first_log_time,
  MAX(fl.created_at) as last_log_time,
  COUNT(*) as total_log_entries,
  CASE 
    WHEN COUNT(*) != COUNT(DISTINCT fl.feed_round_id) THEN 'ERROR: Duplicates detected'
    ELSE 'OK'
  END as aggregation_status
FROM feed_logs fl
GROUP BY fl.pond_id, DATE(fl.created_at)
ORDER BY feed_date DESC, fl.pond_id;

COMMENT ON VIEW feed_aggregation_check IS
'Verifies feed aggregation accuracy:
- Each round should have exactly 1 log entry
- total_log_entries == unique_rounds (if duplicates, they differ)
Run daily: SELECT * FROM feed_aggregation_check
Expected: aggregation_status = "OK" for all rows';

-- Query 4: Monitor timestamp consistency (server time enforcement)
CREATE OR REPLACE VIEW timestamp_consistency_check AS
SELECT 
  id,
  feed_round_id,
  pond_id,
  doc,
  round,
  created_at,
  EXTRACT(EPOCH FROM (NOW() - created_at)) as seconds_ago,
  CASE 
    WHEN created_at > NOW() THEN 'ERROR: Future timestamp'
    WHEN created_at < (NOW() - INTERVAL '30 days') THEN 'WARNING: Very old entry'
    ELSE 'OK'
  END as timestamp_status
FROM feed_logs
ORDER BY created_at DESC
LIMIT 100;

COMMENT ON VIEW timestamp_consistency_check IS
'Detects timestamp anomalies:
- Future timestamps (impossible)
- Very old entries (data quality check)
- Helps detect client clock skew issues
Run hourly for recent entries: SELECT * FROM timestamp_consistency_check';

-- Alert: Create simple alert function
CREATE OR REPLACE FUNCTION check_feed_data_integrity()
RETURNS TABLE(check_name TEXT, issue_count INTEGER, severity TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'Duplicate Logs'::TEXT,
    (SELECT COUNT(*) FROM duplicate_feed_logs_check)::INTEGER,
    'CRITICAL'::TEXT
  UNION ALL
  SELECT 
    'Inconsistent States'::TEXT,
    (SELECT COUNT(*) FROM data_integrity_check WHERE status_check LIKE 'ERROR%')::INTEGER,
    'CRITICAL'::TEXT
  UNION ALL
  SELECT 
    'Future Timestamps'::TEXT,
    (SELECT COUNT(*) FROM feed_logs WHERE created_at > NOW())::INTEGER,
    'CRITICAL'::TEXT;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_feed_data_integrity IS
'Quick integrity check - run daily.
Returns count of issues by category.
Should return all zeros.';
