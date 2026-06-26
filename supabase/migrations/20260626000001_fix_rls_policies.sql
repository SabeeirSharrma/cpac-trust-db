-- Fix RLS policies for service_role access via REST API
-- The auth.role() check doesn't work reliably with direct PostgREST calls

-- Drop existing policies
DROP POLICY IF EXISTS "Advisories are publicly readable" ON advisories;
DROP POLICY IF EXISTS "Service role can insert/update advisories" ON advisories;
DROP POLICY IF EXISTS "Snapshots are publicly readable" ON snapshots;
DROP POLICY IF EXISTS "Authenticated users can insert snapshots" ON snapshots;
DROP POLICY IF EXISTS "Service role can update snapshots" ON snapshots;
DROP POLICY IF EXISTS "Service role can manage tokens" ON tokens;

-- Advisories: public read, service role write (using JWT claims)
CREATE POLICY "Advisories are publicly readable"
    ON advisories FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert advisories"
    ON advisories FOR INSERT
    WITH CHECK (
        current_setting('request.jwt.claims', true)::json->>'role' = 'service_role'
        OR current_setting('request.jwt.claims', true) IS NULL
    );

CREATE POLICY "Service role can update advisories"
    ON advisories FOR UPDATE
    USING (
        current_setting('request.jwt.claims', true)::json->>'role' = 'service_role'
        OR current_setting('request.jwt.claims', true) IS NULL
    );

-- Snapshots: public read, authenticated write
CREATE POLICY "Snapshots are publicly readable"
    ON snapshots FOR SELECT
    USING (true);

CREATE POLICY "Anyone can insert snapshots"
    ON snapshots FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Service role can update snapshots"
    ON snapshots FOR UPDATE
    USING (
        current_setting('request.jwt.claims', true)::json->>'role' = 'service_role'
        OR current_setting('request.jwt.claims', true) IS NULL
    );

-- Tokens: service role only
CREATE POLICY "Service role can manage tokens"
    ON tokens FOR ALL
    USING (
        current_setting('request.jwt.claims', true)::json->>'role' = 'service_role'
        OR current_setting('request.jwt.claims', true) IS NULL
    );
