# Recorded Changes

All notable changes to cpac-trust-db are documented here.

---

## 2026-06-27

### API Proxy Worker (Cloudflare Workers)

- Scaffolded `worker/` directory with Cloudflare Worker project
- Worker proxies `api.thecinderproject.qd.je/cpac-trust-db/api/*` → Supabase `/rest/v1/*`
- Handles CORS, header forwarding, client token pass-through
- DNS: CNAME `api.thecinderproject.qd.je` → `cpac-trust-db-api.sabplay-idk.workers.dev`
- Supports all endpoints: advisories, snapshots, meta, upsert

### Trust DB Client Integration

- CPAC client connects via API proxy (not direct Supabase)
- Added meta check, full sync, and delta sync
- Added anonymous client tokens (UUID-based rate limiting)
- Added snapshot submission pipeline with local queue
- Added consent-aware submissions (hash-only or full sanitized PKGBUILD)
- Added auto-sync during `cpac install` and `cpac update`

### Schema Changes

- Added `pkgbuild_text TEXT` column to `snapshots` table
- Updated `upsert_snapshot` function to accept `p_pkgbuild_text`
- Migration: `20260627000001_add_pkgbuild_text.sql`

### Advisory Entries Published

- Atomic Arch campaign (1600+ AUR packages compromised)
- snapd-git, ipfs-desktop-bin, perl-alien-wxwidgets, premake-git
- cachy-browser (unconfirmed)

### Snapshot Seed Data

- Legitimate: firefox, git, vim, python, nodejs, base-devel
- Compromised: snapd-git, ipfs-desktop-bin, perl-alien-wxwidgets, premake-git (known-bad hashes)

### PKGBUILD Sanitization

- Pass 1: Structural redaction (URLs, maintainer, comments, local files)
- Pass 2: Anomaly detection (8 categories, 6 tests)
- SHA-256 hashing for fast consensus checking
- Pre-flight intelligence check with verdicts (Clean, AdvisoryHit, Divergent, Outdated, Unknown)

### Release Workflow

- GitHub Actions release workflow (x86_64 + aarch64 binaries)
- SHA-256 checksums, GitHub Release with assets
- Switched to rustls-tls (no OpenSSL dependency)

### Infrastructure

- RLS policies opened for REST API compatibility (public data, rate limiting at app level)
- GitHub Actions nightly sync: advisories→Supabase, snapshots→Supabase, snapshots←Supabase
- Custom domain proxy not yet set up (GitHub Pages is static)

---

## 2026-06-26

### Initial Release

- Created project structure: `advisories/`, `snapshots/`, `meta/`
- Added `meta/db.toml` with initial schema (v1.0.0, schema_version=1)
- Added advisory and snapshot schemas (`advisories/schema.md`, `snapshots/schema.md`)
- Added submission guides (`advisories/SUBMISSION.md`, `snapshots/SUBMISSION.md`)
- Added `CONTRIBUTING.md` with contribution policy

### Architecture Update

- Redesigned architecture: CPAC client → Supabase (direct writes) → GitHub Actions (nightly) → repo
- Added API endpoints: `/api/meta`, `/api/advisories`, `/api/snapshots`, `/api/delta`, `/api/submit/snapshot`
- Added staleness check system (meta check + delta sync)
- Added auth model (public reads, authenticated writes via anonymous tokens)
- Added GitHub Actions pipeline spec (scheduled, reads from Supabase, commits to repo)
- Updated governance: maintainer-only advisory writes via Supabase RLS

### Submission Flow Update

- Submissions now write directly to Supabase (skip GitHub entirely)
- GitHub Actions runs on a schedule (e.g. nightly), not on push
- GitHub Actions reads FROM Supabase and commits TO repo
- One single commit per scheduled run, no overlap possible
- Added `version` and `last_sync` fields to `meta/db.toml`
