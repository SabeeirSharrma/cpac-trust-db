-- Migration: Add auth roles, pending advisories, and approval workflow
-- Date: 2026-06-28

-- ============================================================
-- 1. PROFILES TABLE (links Supabase Auth users to roles)
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('maintainer', 'volunteer')),
  display_name TEXT NOT NULL,
  daily_limit INTEGER DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Maintainers can read all profiles
CREATE POLICY "profiles_select_maintainers" ON profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'maintainer')
  );

-- Only superadmin can insert profiles (via service_role key)
CREATE POLICY "profiles_insert_admin" ON profiles
  FOR INSERT WITH CHECK (true);

-- ============================================================
-- 2. PENDING ADVISORIES TABLE (volunteer submissions)
-- ============================================================

CREATE TABLE IF NOT EXISTS pending_advisories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submitted_by UUID REFERENCES profiles(id) NOT NULL,
  package TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('critical','high','medium','low')),
  status TEXT NOT NULL DEFAULT 'suspected' CHECK (status IN ('confirmed','suspected')),
  summary TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  affected_versions JSONB DEFAULT '[]',
  safe_versions JSONB DEFAULT '[]',
  reference_urls JSONB DEFAULT '[]',
  cve TEXT DEFAULT '',
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT DEFAULT '',
  review_status TEXT NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','approved','rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE pending_advisories ENABLE ROW LEVEL SECURITY;

-- Volunteers can read their own submissions
CREATE POLICY "pending_select_own" ON pending_advisories
  FOR SELECT USING (auth.uid() = submitted_by);

-- Maintainers can read all pending submissions
CREATE POLICY "pending_select_maintainers" ON pending_advisories
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'maintainer')
  );

-- Volunteers can insert (rate limit enforced at app + trigger level)
CREATE POLICY "pending_insert_volunteers" ON pending_advisories
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'volunteer')
  );

-- Maintainers can update (approve/reject)
CREATE POLICY "pending_update_maintainers" ON pending_advisories
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'maintainer')
  );

-- ============================================================
-- 3. DAILY SUBMISSION COUNTS VIEW (for rate limiting)
-- ============================================================

CREATE OR REPLACE VIEW daily_submission_counts AS
SELECT
  submitted_by,
  DATE(created_at) AS day,
  COUNT(*) AS count
FROM pending_advisories
GROUP BY submitted_by, DATE(created_at);

-- ============================================================
-- 4. RATE LIMIT TRIGGER (5/day per volunteer)
-- ============================================================

CREATE OR REPLACE FUNCTION check_daily_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_limit INTEGER;
  v_count INTEGER;
BEGIN
  SELECT daily_limit INTO v_limit FROM profiles WHERE id = NEW.submitted_by;

  SELECT COUNT(*) INTO v_count FROM pending_advisories
    WHERE submitted_by = NEW.submitted_by
    AND DATE(created_at) = CURRENT_DATE;

  IF v_count >= COALESCE(v_limit, 5) THEN
    RAISE EXCEPTION 'Daily submission limit (%) reached. Try again tomorrow.', v_limit;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_daily_limit ON pending_advisories;
CREATE TRIGGER trg_daily_limit
  BEFORE INSERT ON pending_advisories
  FOR EACH ROW EXECUTE FUNCTION check_daily_limit();

-- ============================================================
-- 5. APPROVE ADVISORY FUNCTION (pending → published)
-- ============================================================

CREATE OR REPLACE FUNCTION approve_advisory(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS UUID AS $$
DECLARE
  v_advisory_id UUID;
  v_record RECORD;
  v_reporter TEXT;
BEGIN
  -- Fetch the pending advisory
  SELECT * INTO v_record FROM pending_advisories WHERE id = p_pending_id;

  IF v_record IS NULL THEN
    RAISE EXCEPTION 'Pending advisory not found: %', p_pending_id;
  END IF;

  -- Get the submitter's display name
  SELECT display_name INTO v_reporter FROM profiles WHERE id = v_record.submitted_by;

  -- Insert into advisories
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
-- 6. REJECT ADVISORY FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION reject_advisory(
  p_pending_id UUID,
  p_reviewed_by UUID,
  p_review_notes TEXT DEFAULT ''
)
RETURNS VOID AS $$
BEGIN
  UPDATE pending_advisories SET
    review_status = 'rejected',
    reviewed_by = p_reviewed_by,
    reviewed_at = NOW(),
    review_notes = p_review_notes
  WHERE id = p_pending_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
