-- Migration: Email notifications — email_log and report_queue tables
-- Date: 2026-06-29

-- ============================================================
-- 1. EMAIL LOG — tracks sent emails, prevents duplicates
-- ============================================================

CREATE TABLE IF NOT EXISTS email_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID REFERENCES profiles(id),
  recipient_email TEXT NOT NULL,
  email_type TEXT NOT NULL CHECK (email_type IN ('weekly_report', 'suspension', 'welcome', 'appeal')),
  subject TEXT NOT NULL,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed', 'bounced')),
  metadata JSONB DEFAULT '{}'
);

-- Index for checking duplicate sends
CREATE INDEX IF NOT EXISTS idx_email_log_recipient_type
  ON email_log (recipient_id, email_type, sent_at DESC);

-- Index for querying recent emails
CREATE INDEX IF NOT EXISTS idx_email_log_sent_at
  ON email_log (sent_at DESC);

-- RLS: service role only
ALTER TABLE email_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "email_log_service_only" ON email_log
  FOR ALL USING (auth.role() = 'service_role');

-- ============================================================
-- 2. REPORT QUEUE — generated reports awaiting send
-- ============================================================

CREATE TABLE IF NOT EXISTS report_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  volunteer_id UUID REFERENCES profiles(id) NOT NULL,
  volunteer_email TEXT NOT NULL,
  volunteer_name TEXT NOT NULL,
  report_html TEXT NOT NULL,
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  sent_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed'))
);

-- Index for finding pending reports
CREATE INDEX IF NOT EXISTS idx_report_queue_pending
  ON report_queue (status, created_at)
  WHERE status = 'pending';

-- Index for finding reports by volunteer
CREATE INDEX IF NOT EXISTS idx_report_queue_volunteer
  ON report_queue (volunteer_id, week_start);

-- RLS: service role only
ALTER TABLE report_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "report_queue_service_only" ON report_queue
  FOR ALL USING (auth.role() = 'service_role');

-- ============================================================
-- 3. REPORT DAY FUNCTION — get volunteers due for reports today
-- ============================================================

-- Returns volunteers whose report day (based on account creation day of week) is today
CREATE OR REPLACE FUNCTION get_volunteers_for_today()
RETURNS TABLE(
  volunteer_id UUID,
  email TEXT,
  display_name TEXT,
  created_at TIMESTAMPTZ,
  account_age_days BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    COALESCE((SELECT au.email FROM auth.users au WHERE au.id = p.id), 'unknown') AS email,
    p.display_name,
    p.created_at,
    EXTRACT(DAY FROM NOW() - p.created_at)::BIGINT AS account_age_days
  FROM profiles p
  WHERE p.role = 'volunteer'
    AND EXTRACT(DOW FROM p.created_at) = EXTRACT(DOW FROM NOW());
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- 4. WEEKLY SUBMISSIONS FUNCTION — get submissions for a volunteer in a date range
-- ============================================================

CREATE OR REPLACE FUNCTION get_weekly_submissions(
  p_volunteer_id UUID,
  p_week_start DATE,
  p_week_end DATE
)
RETURNS TABLE(
  package TEXT,
  severity TEXT,
  status TEXT,
  review_status TEXT,
  submitted_date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pa.package,
    pa.severity,
    pa.status,
    pa.review_status,
    pa.created_at::DATE AS submitted_date
  FROM pending_advisories pa
  WHERE pa.submitted_by = p_volunteer_id
    AND pa.created_at::DATE BETWEEN p_week_start AND p_week_end
  ORDER BY pa.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- 5. CLEANUP OLD REPORTS — delete sent reports older than 7 days
-- ============================================================

CREATE OR REPLACE FUNCTION cleanup_old_reports()
RETURNS INTEGER AS $$
DECLARE
  v_deleted INTEGER := 0;
BEGIN
  DELETE FROM report_queue
  WHERE status = 'sent'
    AND sent_at < NOW() - INTERVAL '7 days';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;
