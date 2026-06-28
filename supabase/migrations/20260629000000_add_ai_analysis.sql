-- Migration: AI analysis cache table
-- Stores on-demand AI analysis results for 3-hour cache

CREATE TABLE IF NOT EXISTS ai_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package TEXT NOT NULL,
  version_old TEXT NOT NULL,
  version_new TEXT NOT NULL,
  diff_hash TEXT NOT NULL,
  analysis TEXT NOT NULL,
  recommendation TEXT NOT NULL CHECK (recommendation IN ('safe', 'suspicious', 'malicious')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);

-- Index for cache lookups: same package + versions + diff_hash
CREATE INDEX IF NOT EXISTS idx_ai_analysis_cache
  ON ai_analysis (package, version_old, version_new, diff_hash);

-- Index for cleanup of expired entries
CREATE INDEX IF NOT EXISTS idx_ai_analysis_expiry
  ON ai_analysis (expires_at);

-- RLS: public read, authenticated write
ALTER TABLE ai_analysis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_analysis_public_read" ON ai_analysis
  FOR SELECT USING (true);

CREATE POLICY "ai_analysis_authenticated_insert" ON ai_analysis
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Function to clean up expired AI analysis entries
CREATE OR REPLACE FUNCTION cleanup_expired_ai_analysis()
RETURNS void AS $$
BEGIN
  DELETE FROM ai_analysis WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;
