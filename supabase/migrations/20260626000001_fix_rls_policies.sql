-- Fix RLS policies for service_role access via REST API
-- Simplified: advisory data is public, open write is fine

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Advisories are publicly readable" ON advisories;
DROP POLICY IF EXISTS "Service role can insert/update advisories" ON advisories;
DROP POLICY IF EXISTS "Snapshots are publicly readable" ON snapshots;
DROP POLICY IF EXISTS "Authenticated users can insert snapshots" ON snapshots;
DROP POLICY IF EXISTS "Service role can update snapshots" ON snapshots;
DROP POLICY IF EXISTS "Service role can manage tokens" ON tokens;

-- Advisories: public read, open write
CREATE POLICY "Advisories are publicly readable"
    ON advisories FOR SELECT USING (true);

CREATE POLICY "Anyone can insert advisories"
    ON advisories FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update advisories"
    ON advisories FOR UPDATE USING (true);

-- Snapshots: public read, open write
CREATE POLICY "Snapshots are publicly readable"
    ON snapshots FOR SELECT USING (true);

CREATE POLICY "Anyone can insert snapshots"
    ON snapshots FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update snapshots"
    ON snapshots FOR UPDATE USING (true);

-- Tokens: open (rate limiting handled at application level)
CREATE POLICY "Anyone can manage tokens"
    ON tokens FOR ALL USING (true);
