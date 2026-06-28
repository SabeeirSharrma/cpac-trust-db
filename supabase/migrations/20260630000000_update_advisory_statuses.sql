-- ============================================================
-- Advisory Status Update: Bidirectional Trust Attestations
-- ============================================================
-- Old statuses: confirmed, suspected, resolved
-- New statuses: safe, suspicious, warning, malicious, resolved
--
-- safe        → positive attestation, package verified clean (+10)
-- suspicious  → under investigation, proceed with caution (-15)
-- warning     → credible concern, not yet confirmed (-20)
-- malicious   → confirmed malicious (-30)
-- resolved    → was malicious/suspicious, now clean (0, neutral)
-- ============================================================

-- 1. Drop old CHECK constraints (before data migration)
ALTER TABLE advisories DROP CONSTRAINT IF EXISTS advisories_status_check;
ALTER TABLE pending_advisories DROP CONSTRAINT IF EXISTS pending_advisories_status_check;

-- 2. Migrate existing data FIRST (before adding new constraints)
UPDATE advisories SET status = 'warning' WHERE status = 'confirmed';
UPDATE advisories SET status = 'suspicious' WHERE status = 'suspected';
-- resolved stays as resolved

UPDATE pending_advisories SET status = 'warning' WHERE status = 'confirmed';
UPDATE pending_advisories SET status = 'suspicious' WHERE status = 'suspected';

-- 3. NOW add new CHECK constraints (all data already matches)
ALTER TABLE advisories
  ADD CONSTRAINT advisories_status_check
  CHECK (status IN ('safe', 'suspicious', 'warning', 'malicious', 'resolved'));

ALTER TABLE pending_advisories
  ADD CONSTRAINT pending_advisories_status_check
  CHECK (status IN ('safe', 'suspicious', 'warning', 'malicious'));

-- 4. Update default for pending_advisories
ALTER TABLE pending_advisories ALTER COLUMN status SET DEFAULT 'suspicious';

-- 5. Update approve_advisory() to handle new statuses
CREATE OR REPLACE FUNCTION approve_advisory(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS TEXT AS $$
DECLARE
  v_record RECORD;
  v_existing RECORD;
BEGIN
  -- Fetch the pending advisory
  SELECT * INTO v_record FROM pending_advisories WHERE id = p_pending_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending advisory not found';
  END IF;

  -- Check if advisory already exists for this package
  SELECT * INTO v_existing FROM advisories WHERE package = v_record.package;

  -- If existing advisory, snapshot it into history before overwriting
  IF FOUND THEN
    INSERT INTO advisory_history (
      advisory_id, package, severity, status, reported, updated,
      reported_by, cve, summary, description,
      affected_versions, safe_versions, reference_urls,
      file_hash, snapshot_by
    ) VALUES (
      v_existing.id, v_existing.package, v_existing.severity, v_existing.status,
      v_existing.reported, v_existing.updated, v_existing.reported_by,
      v_existing.cve, v_existing.summary, v_existing.description,
      v_existing.affected_versions, v_existing.safe_versions,
      v_existing.reference_urls, v_existing.file_hash, p_reviewed_by
    );

    -- Update existing advisory
    UPDATE advisories SET
      severity = v_record.severity,
      status = v_record.status,
      updated = CURRENT_DATE,
      reported_by = COALESCE((SELECT display_name FROM profiles WHERE id = v_record.submitted_by), 'Unknown'),
      cve = v_record.cve,
      summary = v_record.summary,
      description = v_record.description,
      affected_versions = v_record.affected_versions,
      safe_versions = v_record.safe_versions,
      reference_urls = v_record.reference_urls,
      updated_at = NOW()
    WHERE package = v_record.package;
  ELSE
    -- Insert new advisory
    INSERT INTO advisories (
      package, severity, status, reported, updated,
      reported_by, cve, summary, description,
      affected_versions, safe_versions, reference_urls, file_hash
    ) VALUES (
      v_record.package,
      v_record.severity,
      v_record.status,
      CURRENT_DATE,
      CURRENT_DATE,
      COALESCE((SELECT display_name FROM profiles WHERE id = v_record.submitted_by), 'Unknown'),
      v_record.cve,
      v_record.summary,
      v_record.description,
      v_record.affected_versions,
      v_record.safe_versions,
      v_record.reference_urls,
      ''
    );
  END IF;

  -- Mark as approved
  UPDATE pending_advisories SET
    review_status = 'approved',
    reviewed_by = p_reviewed_by,
    reviewed_at = NOW(),
    review_notes = p_review_notes
  WHERE id = p_pending_id;

  RETURN 'approved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Update reject_advisory()
CREATE OR REPLACE FUNCTION reject_advisory(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS TEXT AS $$
BEGIN
  UPDATE pending_advisories SET
    review_status = 'rejected',
    reviewed_by = p_reviewed_by,
    reviewed_at = NOW(),
    review_notes = p_review_notes
  WHERE id = p_pending_id;

  RETURN 'rejected';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
