-- Add pkgbuild_text column to snapshots table for full PKGBUILD submissions
-- Clients with consent=full will submit the sanitized PKGBUILD text alongside the hash

ALTER TABLE snapshots ADD COLUMN IF NOT EXISTS pkgbuild_text TEXT;

-- Update RLS policy to allow authenticated users to insert with pkgbuild_text
DROP POLICY IF EXISTS "Authenticated users can insert snapshots" ON snapshots;
CREATE POLICY "Authenticated users can insert snapshots"
    ON snapshots FOR INSERT
    WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- Update the upsert function to handle pkgbuild_text
CREATE OR REPLACE FUNCTION upsert_snapshot(
    p_package TEXT, p_version TEXT, p_sha256 TEXT, p_submitted_count INTEGER DEFAULT 1,
    p_pkgbuild_text TEXT DEFAULT NULL
)
RETURNS snapshots AS $$
    INSERT INTO snapshots (package, version, sha256, submitted_count, first_seen, last_seen, pkgbuild_text)
    VALUES (p_package, p_version, p_sha256, p_submitted_count, CURRENT_DATE, CURRENT_DATE, p_pkgbuild_text)
    ON CONFLICT (package, version, sha256)
    DO UPDATE SET
        submitted_count = snapshots.submitted_count + p_submitted_count,
        last_seen = CURRENT_DATE,
        updated_at = NOW(),
        pkgbuild_text = COALESCE(p_pkgbuild_text, snapshots.pkgbuild_text)
    RETURNING *;
$$ LANGUAGE sql VOLATILE;
