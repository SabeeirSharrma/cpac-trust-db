-- Migration: Reputation system
-- Adds strike tracking, volunteer reputation stats, and reject-with-strike function
-- Date: 2026-06-29

-- ============================================================
-- 1. STRIKE TRACKING — add strikes column to profiles
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS strikes INTEGER DEFAULT 0;

-- ============================================================
-- 2. VOLUNTEER REPUTATION VIEW
-- ============================================================

CREATE OR REPLACE VIEW volunteer_reputation AS
SELECT
  p.id,
  p.display_name,
  p.role,
  p.strikes,
  p.created_at AS account_age,
  COUNT(pa.id) AS total_submissions,
  COUNT(pa.id) FILTER (WHERE pa.review_status = 'approved') AS approved,
  COUNT(pa.id) FILTER (WHERE pa.review_status = 'rejected') AS rejected,
  COUNT(pa.id) FILTER (WHERE pa.review_status = 'pending') AS pending,
  CASE
    WHEN COUNT(pa.id) = 0 THEN 0
    ELSE ROUND(
      COUNT(pa.id) FILTER (WHERE pa.review_status = 'approved')::NUMERIC
      / NULLIF(COUNT(pa.id) FILTER (WHERE pa.review_status IN ('approved', 'rejected')), 0)
      * 100, 1
    )
  END AS approval_rate,
  COUNT(DISTINCT DATE(pa.created_at)) AS active_days,
  CASE
    WHEN COUNT(pa.id) FILTER (WHERE pa.review_status = 'approved') >= 20
      AND COUNT(pa.id) FILTER (WHERE pa.review_status = 'approved')::NUMERIC
          / NULLIF(COUNT(pa.id) FILTER (WHERE pa.review_status IN ('approved', 'rejected')), 0) >= 0.8
    THEN 'trusted'
    WHEN p.strikes >= 3 THEN 'suspended'
    WHEN p.strikes >= 2 THEN 'probation'
    ELSE 'standard'
  END AS trust_tier
FROM profiles p
LEFT JOIN pending_advisories pa ON pa.submitted_by = p.id
WHERE p.role = 'volunteer'
GROUP BY p.id, p.display_name, p.role, p.strikes, p.created_at;

-- ============================================================
-- 3. MAINTAINER REPUTATION VIEW
-- ============================================================

CREATE OR REPLACE VIEW maintainer_reputation AS
SELECT
  p.id,
  p.display_name,
  p.role,
  p.strikes,
  p.created_at AS account_age,
  COUNT(DISTINCT pa.reviewed_by) FILTER (WHERE pa.reviewed_by = p.id) AS reviews_conducted,
  COUNT(pa.id) AS total_pending_handled,
  COUNT(DISTINCT DATE(pa.reviewed_at)) AS active_review_days
FROM profiles p
LEFT JOIN pending_advisories pa ON pa.reviewed_by = p.id
WHERE p.role IN ('maintainer', 'admin')
GROUP BY p.id, p.display_name, p.role, p.strikes, p.created_at;

-- ============================================================
-- 4. REJECT ADVISORY WITH STRIKE
-- ============================================================

-- When a submission is rejected, increment the submitter's strike count.
-- At 3 strikes, account is flagged for suspension.
CREATE OR REPLACE FUNCTION reject_advisory_with_strike(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS TEXT AS $$
DECLARE
  v_record RECORD;
  v_new_strikes INTEGER;
  v_result TEXT;
BEGIN
  -- Fetch the pending advisory
  SELECT * INTO v_record FROM pending_advisories WHERE id = p_pending_id;

  IF v_record IS NULL THEN
    RAISE EXCEPTION 'Pending advisory not found: %', p_pending_id;
  END IF;

  -- Update pending record to rejected
  UPDATE pending_advisories SET
    review_status = 'rejected',
    reviewed_by = p_reviewed_by,
    reviewed_at = NOW(),
    review_notes = p_review_notes
  WHERE id = p_pending_id;

  -- Increment strike count on the submitter
  UPDATE profiles SET strikes = strikes + 1
  WHERE id = v_record.submitted_by
  RETURNING strikes INTO v_new_strikes;

  -- Determine result
  IF v_new_strikes >= 3 THEN
    v_result := 'rejected_suspended';
    RAISE NOTICE 'Volunteer has % strikes — account flagged for suspension', v_new_strikes;
  ELSIF v_new_strikes = 2 THEN
    v_result := 'rejected_probation';
    RAISE NOTICE 'Volunteer has % strikes — now on probation', v_new_strikes;
  ELSE
    v_result := 'rejected';
    RAISE NOTICE 'Volunteer has % strike(s)', v_new_strikes;
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 5. INACTIVITY CHECK + AUTO-SUSPEND
-- ============================================================

-- Check for volunteers with zero submissions in 30 days
-- Returns list of inactive volunteers for suspension review
CREATE OR REPLACE FUNCTION check_volunteer_inactivity_detailed()
RETURNS TABLE(
  volunteer_id UUID,
  display_name TEXT,
  email TEXT,
  last_submission TIMESTAMPTZ,
  days_inactive BIGINT,
  total_submissions BIGINT,
  trust_tier TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.display_name,
    COALESCE(
      (SELECT au.email FROM auth.users au WHERE au.id = p.id),
      'unknown'
    ) AS email,
    MAX(pa.created_at) AS last_submission,
    EXTRACT(DAY FROM NOW() - COALESCE(MAX(pa.created_at), p.created_at))::BIGINT AS days_inactive,
    COUNT(pa.id)::BIGINT AS total_submissions,
    CASE
      WHEN p.strikes >= 3 THEN 'suspended'
      WHEN p.strikes >= 2 THEN 'probation'
      ELSE 'standard'
    END AS trust_tier
  FROM profiles p
  LEFT JOIN pending_advisories pa ON pa.submitted_by = p.id
  WHERE p.role = 'volunteer'
  GROUP BY p.id, p.display_name, p.created_at, p.strikes
  HAVING MAX(pa.created_at) IS NULL
      OR MAX(pa.created_at) < NOW() - INTERVAL '30 days'
  ORDER BY days_inactive DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- 6. APPROVE ADVISORY — reset strikes on approval
-- ============================================================

-- If a volunteer gets an approval after rejections, reduce strike count by 1
-- (incentivizes quality submissions over time)
CREATE OR REPLACE FUNCTION approve_advisory_with_reputation(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS UUID AS $$
DECLARE
  v_advisory_id UUID;
  v_record RECORD;
  v_submitter UUID;
BEGIN
  -- Call existing approve function
  v_advisory_id := approve_advisory(p_pending_id, p_reviewed_by, p_review_notes);

  -- Get the submitter
  SELECT submitted_by INTO v_submitter FROM pending_advisories WHERE id = p_pending_id;

  -- Reduce strike count by 1 on successful approval (min 0)
  IF v_submitter IS NOT NULL THEN
    UPDATE profiles SET strikes = GREATEST(strikes - 1, 0)
    WHERE id = v_submitter AND strikes > 0;
  END IF;

  RETURN v_advisory_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
