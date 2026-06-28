# Release Notes

## v1.7.0 — 2026-06-28

**NVIDIA NIM AI integration, panel redesign, cron-triggered email reports.**

### What's New

- **NVIDIA NIM AI analysis** — Worker proxies requests to NVIDIA NIM free tier (no credit card)
  - Reasoning model (`nemotron-3-super-120b-a12b`) for security-focused PKGBUILD diff analysis
  - Nano model (`nemotron-3-nano-30b-a3b`) for weekly report summaries
  - Structured response: recommendation, summary, severity, affected/safe versions, references
  - API key stays server-side (never exposed to browser)
- **Unified Review tab** — all panels share same workflow (package list → compare → AI → publish/submit)
- **Layout toggle** — Tabs or Side-by-Side, persisted to `localStorage`
- **Notes system** — floating notes button, auto-saved per package, cleared on publish
- **Automated weekly email reports** — Resend integration, staggered by account creation date
  - Reports sent exactly 7 days after previous report per user (DOW matching)
  - HTML table in email body, ephemeral (stored→sent→deleted)
  - Zero activity = no email that week
- **Cloudflare cron trigger** — daily at midnight UTC, calls `/reports/generate` + `/reports/send`
- **Account management** — admin panel creates volunteer/maintainer accounts (random password emailed)
- **RLS recursion fix** — `SECURITY DEFINER` helper functions prevent infinite recursion
- **Worker config** — migrated from `wrangler.toml` to `wrangler.jsonc`

### Database Changes

- **New migration:** `20260629000005_fix_rls_recursion.sql`

### Worker Changes

- `POST /ai/analyze-diff` — NVIDIA NIM reasoning model for diff analysis
- `POST /ai/generate-report` — NVIDIA NIM nano model for report insights
- `POST /accounts/create` — admin account creation with Resend email
- `POST /reports/generate` — weekly report generation
- `POST /reports/send` — send queued reports via Resend
- `scheduled()` handler — daily cron trigger

### Migration

```bash
# Run in Supabase SQL editor:
# supabase/migrations/20260629000005_fix_rls_recursion.sql

# Deploy Worker:
# cd worker && wrangler deploy
```

---

## v1.6.0 — 2026-06-29

**Weekly advisory reports via email, staggered by account creation date.**

### What's New

- **Email log** — `email_log` table tracks all sent emails (weekly reports, suspension notices)
- **Report queue** — `report_queue` table holds generated reports (ephemeral: sent → deleted)
- **`get_volunteers_for_today()`** — returns volunteers whose report day matches today
- **`get_weekly_submissions()`** — returns submissions for a volunteer in a date range
- **`cleanup_old_reports()`** — deletes sent reports older than 7 days
- **`POST /reports/generate`** — generates weekly reports for volunteers due today
- **`POST /reports/send`** — sends queued reports via Resend, logs in email_log
- **Staggered schedule** — reports sent based on account creation day of week (Mon→Mon, etc.)
- **Zero activity = no email** — volunteers with no submissions that week receive no report

### Database Changes

- **New tables:** `email_log`, `report_queue`
- **New functions:** `get_volunteers_for_today()`, `get_weekly_submissions()`, `cleanup_old_reports()`

### Migration

```bash
# Run in Supabase SQL editor:
# 1. supabase/migrations/20260629000004_add_email_notifications.sql
```

---

## v1.5.0 — 2026-06-29

**Reputation system, strike tracking, and volunteer stats.**

### What's New

- **Strike tracking** — `profiles.strikes` column; rejected submissions increment strikes, approved submissions reduce strikes
- **Trust tiers** — Trusted (80%+ rate, 20+ approved), Standard, Probation (2 strikes), Suspended (3+ strikes)
- **Volunteer reputation view** — approval rate, submission counts, active days, trust tier per volunteer
- **Maintainer reputation view** — reviews conducted, active review days per maintainer
- **`reject_advisory_with_strike()`** — rejects submission and increments strike count
- **`approve_advisory_with_reputation()`** — approves submission and reduces strikes by 1
- **`check_volunteer_inactivity_detailed()`** — returns inactive volunteers with trust tier info

### Database Changes

- **New column:** `profiles.strikes` (INTEGER, default 0)
- **New views:** `volunteer_reputation`, `maintainer_reputation`
- **New functions:** `reject_advisory_with_strike()`, `approve_advisory_with_reputation()`, `check_volunteer_inactivity_detailed()`

### Migration

```bash
# Run in Supabase SQL editor:
# 1. supabase/migrations/20260629000003_add_reputation_system.sql
```

---

## v1.4.0 — 2026-06-29

**Advisory lifecycle, snapshot retention, and storage management.**

### What's New

- **Advisory versioning** — `advisory_history` table stores append-only version history; `advisories` always holds current state
- **`approve_advisory()` updated** — now snapshots existing advisory into history before overwriting (UPSERT logic)
- **Snapshot retention** — `cleanup_old_snapshots()` removes old version snapshots (2-day/5-day retention based on package size, core packages never cleaned)
- **Core package protection** — `is_core_package()` function identifies 40+ packages that are never cleaned up
- **Storage tracking** — `package_storage_usage` view shows per-package stats and activity status
- **Cleanup queue** — `packages_flagged_for_cleanup` view lists packages inactive 30+ days
- **Inactivity check** — `check_volunteer_inactivity()` identifies volunteers with zero submissions in 30+ days

### Database Changes

- **New table:** `advisory_history`
- **New functions:** `is_core_package()`, `cleanup_old_snapshots()`, `check_volunteer_inactivity()`
- **New views:** `package_storage_usage`, `packages_flagged_for_cleanup`
- **Modified function:** `approve_advisory()` — snapshots history before update
- **New migration:** `20260629000001_advisory_lifecycle.sql`

---

## v1.3.0 — 2026-06-28

**Comparer redesign, AI analysis cache, and AUR CORS proxy.**

### What's New

- **Version-focused comparer** — Select any two versions of a package to compare PKGBUILDs side-by-side
- **Package search autocomplete** — Search by DB snapshots or AUR with dropdown
- **Line-by-line diff** — LCS-based diff with added/removed line highlighting
- **Suspicious pattern detection** — 8 categories (curl/wget pipe, eval, rm -rf, npm/bun/npx pipe, hex escapes, base64)
- **AI analysis** — On-demand "Analyze with AI" button, 3-hour cache in `ai_analysis` table
- **Recompare** — Re-run comparison with different versions
- **Maintainer comparer tab** — Same version-comparison workflow available to maintainers
- **AUR CORS proxy** — Worker now proxies `/aur/info/<pkg>` and `/aur/pkgbuild/<pkg>` (browser can't fetch AUR directly)

### Database Changes

- **New table:** `ai_analysis` — caches AI analysis results with 3-hour expiry
- **New migration:** `20260629000000_add_ai_analysis.sql`

### Worker Changes

- Added AUR proxy endpoints: `/cpac-trust-db/api/aur/info/<pkg>`, `/cpac-trust-db/api/aur/pkgbuild/<pkg>`
- Added CORS preflight (`OPTIONS`) handling
- Refactored with shared `CORS_HEADERS` constant

---

## v1.2.0 — 2026-06-28

**Auth panels, volunteer/maintainer workflow, and web comparer.**

### What's New

- **Maintainer panel** — Review and approve/reject volunteer advisory submissions
- **Volunteer panel** — Submit advisories (rate-limited: 5/day), use comparer tool
- **Login page** — Supabase Auth email/password, role-based redirect
- **Client-side comparer** — Fetches PKGBUILD from AUR, computes SHA-256, compares against trust DB, shows verdict
- **Approval workflow** — Volunteer submits → pending queue → maintainer approves (goes live) or rejects (with notes)
- **Database tables** — `profiles`, `pending_advisories`, `daily_submission_counts` view
- **RPC functions** — `approve_advisory()`, `reject_advisory()`
- **Rate limit trigger** — Enforces 5 submissions/day per volunteer at database level

### Access

- No public signups — accounts created via Discord ticket
- Panels at `/cpac-trust-db/web/panel/login`

---

## v1.1.0 — 2026-06-27

**Trust DB client integration + advisory entries + snapshot seeding.**

### What's New

- **CPAC client integration** — Client connects via Cloudflare Worker proxy at `api.thecinderproject.qd.je`
- **Advisory entries** — 6 published advisories:
  - Atomic Arch campaign (1600+ AUR packages compromised)
  - snapd-git, ipfs-desktop-bin, perl-alien-wxwidgets, premake-git
  - cachy-browser (unconfirmed)
- **Snapshot seed data** — Legitimate packages: firefox, git, vim, python, nodejs, base-devel
- **Snapshot seed data** — Compromised hashes: snapd-git, ipfs-desktop-bin, perl-alien-wxwidgets, premake-git
- **pkgbuild_text column** — Full sanitized PKGBUILD stored alongside hashes
- **Anonymous client tokens** — UUID-based rate limiting, no authentication
- **Delta sync** — Lightweight incremental updates via `updated_at > last_sync` filters
- **Pending queue** — Local JSON queue flushed on `cpac update` (never blocks install)

### Architecture Updates

- CPAC clients connect via API proxy at `api.thecinderproject.qd.je` → Cloudflare Worker → Supabase
- GitHub repo remains auditable source of truth (TOML files)
- GitHub Actions nightly sync: advisories→Supabase, snapshots→Supabase, snapshots←Supabase
- Local cache at `~/.cpac/trust-db/` for offline use
- RLS policies opened for REST API compatibility (public data, rate limiting at app level)

### Schema Changes

- Added `pkgbuild_text TEXT` column to `snapshots` table
- Updated `upsert_snapshot` function to accept `p_pkgbuild_text`
- Migration: `20260627000001_add_pkgbuild_text.sql`

### API Endpoints

| Endpoint | Description |
|---|---|
| `GET /rest/v1/advisories` | All advisories (Supabase REST) |
| `GET /rest/v1/snapshots` | All snapshots (Supabase REST) |
| `GET /rest/v1/meta` | Version hash, timestamps, counts |

### Trust Score Impact

| Severity | Penalty | Floor |
|---|---|---|
| Critical | -30 | DANGER |
| High | -20 | WARNING |
| Medium | -10 | CAUTION |
| Low | -5 | — |
| Suspected | -15 | WARNING |
| Resolved | 0 | — |

### Known Limitations

- Schema v2 planned (maintainer transfer history, popularity trends)

---

## v1.0.0 — 2026-06-26

**Initial release of cpac-trust-db.**

### What's New

- **Advisory system** — TOML-based advisory format for reporting malicious, compromised, or suspicious packages
- **Snapshot system** — Crowdsourced PKGBUILD snapshots for detecting package divergence
- **Supabase backend** — Public REST API with row-level security
- **Delta sync** — Lightweight staleness check and incremental updates
- **Anonymous auth** — Rate-limited submissions without user identification

### Architecture

- CPAC clients write directly to Supabase (skip GitHub entirely)
- GitHub repo as auditable source of truth (TOML files)
- GitHub Actions runs on schedule (nightly) — reads from Supabase, commits to repo
- One single commit per scheduled run, no overlap possible
- Local cache at `~/.cpac/trust-db/` for offline use

### Known Limitations

- Schema v2 planned (maintainer transfer history, popularity trends)

---

*Part of The Cinder Project*
