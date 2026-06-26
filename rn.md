# Release Notes

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
- Custom domain proxy (`thecinderproject.qd.je/cpac-trust-db/api/*`)
- Local cache at `~/.cpac/trust-db/` for offline use

### API Endpoints

| Endpoint | Description |
|---|---|
| `GET /api/meta` | Version hash, timestamps, counts |
| `GET /api/advisories` | All advisories |
| `GET /api/advisories/<pkg>` | Advisory for a package |
| `GET /api/snapshots/<pkg>` | Snapshots for a package |
| `GET /api/snapshots/<pkg>/<ver>` | Snapshots for a specific version |
| `GET /api/delta?since=<ts>` | Changed records since last sync |
| `POST /api/submit/snapshot` | Submit hash or full PKGBUILD (auth required) |

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

- No advisory entries yet (first entries pending Atomic Arch investigation)
- No public advisory index on website yet
- Schema v2 planned (maintainer transfer history, popularity trends)

---

*Part of The Cinder Project*
