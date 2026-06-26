# Recorded Changes

All notable changes to cpac-trust-db are documented here.

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
