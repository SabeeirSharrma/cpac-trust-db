-- Migration: Advisory lifecycle, snapshot retention, storage management
-- Date: 2026-06-29

-- ============================================================
-- 1. ADVISORY HISTORY TABLE (append-only version history)
-- ============================================================

CREATE TABLE IF NOT EXISTS advisory_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  advisory_id UUID NOT NULL REFERENCES advisories(id) ON DELETE CASCADE,
  package TEXT NOT NULL,
  severity TEXT NOT NULL,
  status TEXT NOT NULL,
  reported DATE NOT NULL,
  reported_by TEXT NOT NULL,
  cve TEXT DEFAULT '',
  summary TEXT NOT NULL,
  description TEXT NOT NULL,
  affected_versions JSONB DEFAULT '[]',
  safe_versions JSONB DEFAULT '[]',
  reference_urls JSONB DEFAULT '[]',
  file_hash TEXT DEFAULT '',
  snapshot_by UUID REFERENCES profiles(id),
  snapshot_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for looking up history by package
CREATE INDEX IF NOT EXISTS idx_advisory_history_package ON advisory_history (package);

-- Index for looking up history by original advisory
CREATE INDEX IF NOT EXISTS idx_advisory_history_advisory_id ON advisory_history (advisory_id);

-- Chronological order
CREATE INDEX IF NOT EXISTS idx_advisory_history_snapshot_at ON advisory_history (snapshot_at DESC);

-- RLS: public read, service role write
ALTER TABLE advisory_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "advisory_history_public_read" ON advisory_history
  FOR SELECT USING (true);

CREATE POLICY "advisory_history_service_write" ON advisory_history
  FOR ALL USING (auth.role() = 'service_role');

-- ============================================================
-- 2. MODIFY approve_advisory() — snapshot before update
-- ============================================================

-- Drop the old version first
DROP FUNCTION IF EXISTS approve_advisory(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION approve_advisory(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS UUID AS $$
DECLARE
  v_advisory_id UUID;
  v_record RECORD;
  v_existing RECORD;
  v_reporter TEXT;
BEGIN
  -- Fetch the pending advisory
  SELECT * INTO v_record FROM pending_advisories WHERE id = p_pending_id;

  IF v_record IS NULL THEN
    RAISE EXCEPTION 'Pending advisory not found: %', p_pending_id;
  END IF;

  -- Get the submitter's display name
  SELECT display_name INTO v_reporter FROM profiles WHERE id = v_record.submitted_by;

  -- Check if there's already an advisory for this package
  SELECT * INTO v_existing FROM advisories WHERE package = v_record.package;

  IF v_existing IS NOT NULL THEN
    -- Snapshot the existing advisory into history before overwriting
    INSERT INTO advisory_history (
      advisory_id, package, severity, status, reported,
      reported_by, cve, summary, description,
      affected_versions, safe_versions, reference_urls,
      file_hash, snapshot_by
    ) VALUES (
      v_existing.id, v_existing.package, v_existing.severity, v_existing.status,
      v_existing.reported, v_existing.reported_by, v_existing.cve,
      v_existing.summary, v_existing.description,
      v_existing.affected_versions, v_existing.safe_versions,
      v_existing.reference_urls, v_existing.file_hash, p_reviewed_by
    );

    -- Update existing advisory
    UPDATE advisories SET
      severity = v_record.severity,
      status = v_record.status,
      updated = CURRENT_DATE,
      cve = v_record.cve,
      summary = v_record.summary,
      description = v_record.description,
      affected_versions = v_record.affected_versions,
      safe_versions = v_record.safe_versions,
      reference_urls = v_record.reference_urls,
      updated_at = NOW()
    WHERE package = v_record.package
    RETURNING id INTO v_advisory_id;
  ELSE
    -- Insert new advisory
    INSERT INTO advisories (
      package, severity, status, reported, updated,
      reported_by, cve, summary, description,
      affected_versions, safe_versions, reference_urls
    ) VALUES (
      v_record.package, v_record.severity, v_record.status,
      CURRENT_DATE, CURRENT_DATE,
      COALESCE(v_reporter, 'Unknown'),
      v_record.cve, v_record.summary, v_record.description,
      v_record.affected_versions, v_record.safe_versions, v_record.reference_urls
    ) RETURNING id INTO v_advisory_id;
  END IF;

  -- Update pending record
  UPDATE pending_advisories SET
    review_status = 'approved',
    reviewed_by = p_reviewed_by,
    reviewed_at = NOW(),
    review_notes = p_review_notes
  WHERE id = p_pending_id;

  RETURN v_advisory_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 3. SNAPSHOT RETENTION — cleanup function
-- ============================================================

-- Core packages that should NEVER be cleaned up
CREATE OR REPLACE FUNCTION is_core_package(p_package TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN p_package IN (
    'base', 'base-devel', 'linux', 'linux-lts', 'linux-zen',
    'systemd', 'glibc', 'gcc', 'binutils', 'gdb', 'make',
    'coreutils', 'bash', 'zsh', 'fish', 'sudo', 'openssh',
    'openssl', 'git', 'curl', 'wget', 'python', 'python-pip',
    'nodejs', 'npm', 'rust', 'cargo', 'go', 'java-environment',
    'docker', 'podman', 'vim', 'neovim', 'nano', 'tmux',
    'htop', 'neofetch', 'man-db', 'texinfo'
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to clean up old snapshots
-- Retention: large packages (>10MB) = 2 days, small = 5 days
CREATE OR REPLACE FUNCTION cleanup_old_snapshots()
RETURNS INTEGER AS $$
DECLARE
  v_deleted INTEGER := 0;
  v_cutoff_large TIMESTAMPTZ;
  v_cutoff_small TIMESTAMPTZ;
BEGIN
  v_cutoff_large := NOW() - INTERVAL '2 days';
  v_cutoff_small := NOW() - INTERVAL '5 days';

  -- Delete snapshots for non-core packages where:
  -- - The package has a newer snapshot (not the latest version)
  -- - The snapshot is older than the retention cutoff
  -- - The package is not a core package
  WITH latest_versions AS (
    SELECT package, MAX(last_seen) as max_last_seen
    FROM snapshots
    GROUP BY package
  ),
  deletable AS (
    SELECT s.id
    FROM snapshots s
    JOIN latest_versions lv ON s.package = lv.package
    WHERE NOT is_core_package(s.package)
      AND s.last_seen < lv.max_last_seen  -- not the latest version
      AND (
        (s.last_seen < v_cutoff_large)  -- large package cutoff
        OR (s.last_seen < v_cutoff_small)  -- small package cutoff
      )
  )
  DELETE FROM snapshots WHERE id IN (SELECT id FROM deletable);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 4. STORAGE MANAGEMENT — usage tracking view
-- ============================================================

-- View: storage usage per package
CREATE OR REPLACE VIEW package_storage_usage AS
SELECT
  package,
  COUNT(*) as snapshot_count,
  SUM(submitted_count) as total_submissions,
  MAX(last_seen) as last_activity,
  MIN(first_seen) as first_activity,
  CASE
    WHEN MAX(last_seen) < NOW() - INTERVAL '30 days' THEN 'inactive'
    WHEN MAX(last_seen) < NOW() - INTERVAL '7 days' THEN 'stale'
    ELSE 'active'
  END as activity_status
FROM snapshots
GROUP BY package
ORDER BY total_submissions DESC;

-- View: packages flagged for cleanup (inactive 30+ days, non-core)
CREATE OR REPLACE VIEW packages_flagged_for_cleanup AS
SELECT * FROM package_storage_usage
WHERE activity_status = 'inactive'
  AND NOT is_core_package(package);

-- ============================================================
-- 5. VOLUNTEER INACTIVITY CHECK
-- ============================================================

-- Function to check if a volunteer has been inactive for 30+ days
CREATE OR REPLACE FUNCTION check_volunteer_inactivity()
RETURNS TABLE(volunteer_id UUID, display_name TEXT, last_submission TIMESTAMPTZ) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.display_name,
    MAX(pa.created_at) as last_submission
  FROM profiles p
  LEFT JOIN pending_advisories pa ON pa.submitted_by = p.id
  WHERE p.role = 'volunteer'
  GROUP BY p.id, p.display_name
  HAVING MAX(pa.created_at) IS NULL  -- never submitted
     OR MAX(pa.created_at) < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql STABLE;
