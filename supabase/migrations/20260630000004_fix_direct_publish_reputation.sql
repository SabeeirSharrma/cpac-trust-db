-- Migration: Fix direct_publish_advisory — remove broken volunteer_reputation INSERT
-- volunteer_reputation is a VIEW (not a table), can't INSERT into it
-- Admin/maintainer direct publish doesn't need volunteer reputation tracking

CREATE OR REPLACE FUNCTION direct_publish_advisory(
  p_package TEXT, p_severity TEXT, p_status TEXT, p_summary TEXT,
  p_description TEXT DEFAULT '', p_affected_versions JSONB DEFAULT '[]',
  p_safe_versions JSONB DEFAULT '[]', p_reference_urls JSONB DEFAULT '[]',
  p_cve TEXT DEFAULT ''
)
RETURNS UUID AS $$
DECLARE
  v_advisory_id UUID; v_caller_role TEXT; v_display_name TEXT; v_existing RECORD;
BEGIN
  SELECT role INTO v_caller_role FROM profiles WHERE id = auth.uid();
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'maintainer') THEN
    RAISE EXCEPTION 'Only admins and maintainers can publish directly';
  END IF;
  SELECT display_name INTO v_display_name FROM profiles WHERE id = auth.uid();
  SELECT * INTO v_existing FROM advisories WHERE package = p_package;
  IF FOUND THEN
    INSERT INTO advisory_history (advisory_id, package, severity, status, reported, updated, reported_by, cve, summary, description, affected_versions, safe_versions, reference_urls, file_hash, snapshot_by)
    VALUES (v_existing.id, v_existing.package, v_existing.severity, v_existing.status, v_existing.reported, v_existing.updated, v_existing.reported_by, v_existing.cve, v_existing.summary, v_existing.description, v_existing.affected_versions, v_existing.safe_versions, v_existing.reference_urls, v_existing.file_hash, auth.uid());
    UPDATE advisories SET severity = p_severity, status = p_status, updated = CURRENT_DATE, reported_by = COALESCE(v_display_name, 'Unknown'), cve = p_cve, summary = p_summary, description = p_description, affected_versions = p_affected_versions, safe_versions = p_safe_versions, reference_urls = p_reference_urls, updated_at = NOW() WHERE package = p_package RETURNING id INTO v_advisory_id;
  ELSE
    INSERT INTO advisories (package, severity, status, reported, updated, reported_by, cve, summary, description, affected_versions, safe_versions, reference_urls, file_hash)
    VALUES (p_package, p_severity, p_status, CURRENT_DATE, CURRENT_DATE, COALESCE(v_display_name, 'Unknown'), p_cve, p_summary, p_description, p_affected_versions, p_safe_versions, p_reference_urls, '') RETURNING id INTO v_advisory_id;
  END IF;
  RETURN v_advisory_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
