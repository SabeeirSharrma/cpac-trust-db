-- Migration: Remove core package exclusion from snapshot cleanup
-- All packages now get cleaned up (old versions only, latest always kept)
-- Advisory system still protects against malicious packages regardless of snapshots

-- Update cleanup function: remove core package exclusion
CREATE OR REPLACE FUNCTION cleanup_old_snapshots()
RETURNS INTEGER AS $$
DECLARE
  v_deleted INTEGER := 0;
  v_cutoff_large TIMESTAMPTZ;
  v_cutoff_small TIMESTAMPTZ;
BEGIN
  v_cutoff_large := NOW() - INTERVAL '2 days';
  v_cutoff_small := NOW() - INTERVAL '5 days';

  WITH latest_versions AS (
    SELECT package, MAX(last_seen) as max_last_seen
    FROM snapshots
    GROUP BY package
  ),
  deletable AS (
    SELECT s.id
    FROM snapshots s
    JOIN latest_versions lv ON s.package = lv.package
    WHERE s.last_seen < lv.max_last_seen
      AND (
        (s.last_seen < v_cutoff_large)
        OR (s.last_seen < v_cutoff_small)
      )
  )
  DELETE FROM snapshots WHERE id IN (SELECT id FROM deletable);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- Update flagged-for-cleanup view: include all inactive packages
CREATE OR REPLACE VIEW packages_flagged_for_cleanup AS
SELECT * FROM package_storage_usage
WHERE activity_status = 'inactive';
