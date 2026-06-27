# Release Notes

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
