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

- Redesigned architecture: GitHub → GitHub Actions → Supabase (Postgres) → Custom domain proxy → CPAC client
- Added API endpoints: `/api/meta`, `/api/advisories`, `/api/snapshots`, `/api/delta`, `/api/submit/snapshot`
- Added staleness check system (meta check + delta sync)
- Added auth model (public reads, authenticated writes via anonymous tokens)
- Added GitHub Actions pipeline spec (TOML → Supabase)
- Updated governance: maintainer-only advisory writes via Supabase RLS
