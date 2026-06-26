-- cpac-trust-db: Initial schema
-- Creates advisories and snapshots tables for the trust database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- Advisories table
-- Stores known malicious, compromised, or suspicious packages
-- ============================================================================
CREATE TABLE advisories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    package TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
    status TEXT NOT NULL CHECK (status IN ('confirmed', 'suspected', 'resolved')),
    reported DATE NOT NULL,
    updated DATE NOT NULL,
    reported_by TEXT NOT NULL,
    cve TEXT DEFAULT '',
    summary TEXT NOT NULL,
    description TEXT NOT NULL,
    affected_versions JSONB NOT NULL DEFAULT '[]',
    safe_versions JSONB NOT NULL DEFAULT '[]',
    reference_urls JSONB NOT NULL DEFAULT '[]',
    file_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Unique constraint on package name (one advisory per package)
    UNIQUE (package)
);

-- Index for fast lookup by package name
CREATE INDEX idx_advisories_package ON advisories (package);

-- Index for filtering by severity
CREATE INDEX idx_advisories_severity ON advisories (severity);

-- Index for filtering by status
CREATE INDEX idx_advisories_status ON advisories (status);

-- Index for delta sync (changes since timestamp)
CREATE INDEX idx_advisories_updated_at ON advisories (updated_at);

-- ============================================================================
-- Snapshots table
-- Stores anonymized PKGBUILD hash submissions from CPAC clients
-- ============================================================================
CREATE TABLE snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    package TEXT NOT NULL,
    version TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    submitted_count INTEGER NOT NULL DEFAULT 1,
    first_seen DATE NOT NULL,
    last_seen DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Unique constraint on package + version + sha256
    UNIQUE (package, version, sha256)
);

-- Index for fast lookup by package name
CREATE INDEX idx_snapshots_package ON snapshots (package);

-- Index for fast lookup by package + version
CREATE INDEX idx_snapshots_package_version ON snapshots (package, version);

-- Index for delta sync (changes since timestamp)
CREATE INDEX idx_snapshots_updated_at ON snapshots (updated_at);

-- Index for finding majority consensus (most common hash per package+version)
CREATE INDEX idx_snapshots_package_version_count ON snapshots (package, version, submitted_count DESC);

-- ============================================================================
-- Tokens table (for anonymous submission auth)
-- Stores per-install tokens for rate limiting and abuse prevention
-- ============================================================================
CREATE TABLE tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ,
    request_count INTEGER NOT NULL DEFAULT 0
);

-- Index for token lookup
CREATE INDEX idx_tokens_token ON tokens (token);

-- ============================================================================
-- Row Level Security (RLS) policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE advisories ENABLE ROW LEVEL SECURITY;
ALTER TABLE snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE tokens ENABLE ROW LEVEL SECURITY;

-- Advisories: public read, service role write
CREATE POLICY "Advisories are publicly readable"
    ON advisories FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert/update advisories"
    ON advisories FOR ALL
    USING (auth.role() = 'service_role');

-- Snapshots: public read, authenticated write
CREATE POLICY "Snapshots are publicly readable"
    ON snapshots FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can insert snapshots"
    ON snapshots FOR INSERT
    WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Service role can update snapshots"
    ON snapshots FOR UPDATE
    USING (auth.role() = 'service_role');

-- Tokens: service role only
CREATE POLICY "Service role can manage tokens"
    ON tokens FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================================================
-- Functions for delta sync
-- ============================================================================

-- Function to get advisories changed since a timestamp
CREATE OR REPLACE FUNCTION get_advisories_since(since TIMESTAMPTZ)
RETURNS SETOF advisories AS $$
    SELECT * FROM advisories
    WHERE updated_at > since
    ORDER BY updated_at DESC;
$$ LANGUAGE sql STABLE;

-- Function to get snapshots changed since a timestamp
CREATE OR REPLACE FUNCTION get_snapshots_since(since TIMESTAMPTZ)
RETURNS SETOF snapshots AS $$
    SELECT * FROM snapshots
    WHERE updated_at > since
    ORDER BY updated_at DESC;
$$ LANGUAGE sql STABLE;

-- Function to increment snapshot submission count
CREATE OR REPLACE FUNCTION upsert_snapshot(
    p_package TEXT,
    p_version TEXT,
    p_sha256 TEXT,
    p_submitted_count INTEGER DEFAULT 1
)
RETURNS snapshots AS $$
    INSERT INTO snapshots (package, version, sha256, submitted_count, first_seen, last_seen)
    VALUES (p_package, p_version, p_sha256, p_submitted_count, CURRENT_DATE, CURRENT_DATE)
    ON CONFLICT (package, version, sha256)
    DO UPDATE SET
        submitted_count = snapshots.submitted_count + p_submitted_count,
        last_seen = CURRENT_DATE,
        updated_at = NOW()
    RETURNING *;
$$ LANGUAGE sql VOLATILE;

-- Function to increment token request count
CREATE OR REPLACE FUNCTION use_token(p_token TEXT)
RETURNS tokens AS $$
    INSERT INTO tokens (token, request_count, last_used_at)
    VALUES (p_token, 1, NOW())
    ON CONFLICT (token)
    DO UPDATE SET
        request_count = tokens.request_count + 1,
        last_used_at = NOW()
    RETURNING *;
$$ LANGUAGE sql VOLATILE;
