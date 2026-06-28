# Recorded Changes

All notable changes to cpac-trust-db are documented here.

---

## 2026-06-28 — Phase 9: NVIDIA NIM Integration

### Worker: NVIDIA NIM Proxy

- Added `callNvidiaNim()` helper — OpenAI-compatible API calls to `https://integrate.api.nvidia.com/v1/chat/completions`
- **`POST /ai/analyze-diff`** — calls `nvidia/nemotron-3-super-120b-a12b` reasoning model
  - Accepts: package, versions, old/new PKGBUILD, suspicious patterns
  - Returns: `{recommendation, analysis, summary, advisory_severity, affected_versions, safe_versions, references}`
  - Stores result in `ai_analysis` cache (3-hour TTL)
- **`POST /ai/generate-report`** — calls `nvidia/nemotron-3-nano-30b-a3b` for volunteer weekly report insights
  - Accepts: volunteer name, submissions, approval rate, trust tier
  - Returns: `{highlights, feedback, recommendation}`
- `NVIDIA_API_KEY` added to `wrangler.toml` and Worker env

### Worker: Scheduled Cron Trigger

- Added `scheduled()` handler to Worker exports
- Calls `POST /reports/generate` then `POST /reports/send` daily at midnight UTC
- Config migrated from `wrangler.toml` to `wrangler.jsonc` (preferred format)
- Cron trigger: `0 0 * * *` (daily)

### Panel Updates

- All panels: `runAiAnalysisBase()` calls Worker `/ai/analyze-diff` endpoint (not direct Supabase)
- All panels: `renderAiResult()` handles structured JSON response (summary, severity, affected/safe versions)
- Cache check still reads from Supabase `ai_analysis` table (3-hour TTL)

---

## 2026-06-28 — Phase 8: Panel Redesign

### Unified Review Tab

- Replaced old "Comparer" tab with "Review" tab in all three panels
- Package list auto-fetched on tab load (packages needing advisories)
- Automated LCS diff on package select
- AI analysis on-demand (3-hour cache)
- Layout toggle: Tabs or Side-by-Side, persisted to `localStorage`
- Notes system: floating button, textarea, auto-save to `localStorage`, cleared on publish

### Volunteer Panel

- Review tab + My Submissions tab
- Same workflow as maintainer but submits to pending queue (not direct publish)

### Maintainer Panel

- Review tab + Pending/Published/Stats/Volunteers tabs
- Can publish directly or review volunteer submissions

### Admin Panel

- Review tab + Accounts/Pending/Published/Inactivity/Stats tabs
- Can do everything maintainers can + create/suspend/delete accounts

### NetworkError Fix

- Panels were calling unreachable Worker proxy URL (`api.thecinderproject.qd.je`)
- Fixed: snapshots, advisories, ai_analysis, pending_advisories, RPC calls → Supabase REST API directly
- AUR proxy + accounts/create → Worker direct URL (`cpac-trust-db-api.sabplay-idk.workers.dev`)

---

## 2026-06-29

### Advisory Lifecycle & Data Management

- New migration: `20260629000001_advisory_lifecycle.sql`
  - `advisory_history` table (append-only version history)
  - `is_core_package()` function (40+ core packages never cleaned)
  - `cleanup_old_snapshots()` function (2-day/5-day retention)
  - `check_volunteer_inactivity()` function (30-day inactivity check)
  - `package_storage_usage` view (per-package stats)
  - `packages_flagged_for_cleanup` view (inactive 30+ days)
- Modified `approve_advisory()` — now snapshots existing advisory into history before overwriting (UPSERT logic)

---

## 2026-06-28

### Auth & Role-Based Panels

- New migration: `20260628000000_add_auth_and_roles.sql`
  - `profiles` table (links Supabase Auth users to roles)
  - `pending_advisories` table (volunteer submissions awaiting review)
  - `daily_submission_counts` view (rate limiting)
  - `approve_advisory()` and `reject_advisory()` RPC functions
  - Daily rate limit trigger (5/day per volunteer)
  - RLS policies for role-based access
- Panel pages: login, volunteer dashboard, maintainer dashboard
- Client-side comparer: fetches PKGBUILD from AUR, runs comparison logic in browser
- Approval workflow: volunteer submits → pending queue → maintainer approves/rejects

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
