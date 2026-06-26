---
title: Architecture
description: System design and tech stack for cpac-trust-db.
order: 2
---

# Architecture

## Overview

```
CPAC client
  POST /api/submit/snapshot → writes directly to Supabase
       ↓
  Supabase (Postgres)
  Compiled, queryable database
       ↓
  thecinderproject.qd.je/cpac-trust-db/api/*
  Public REST API (proxied through existing domain)
       ↓
  CPAC client reads (GET /api/meta, /api/advisories, /api/snapshots, /api/delta)
  Local cache at ~/.cpac/trust-db/
       ↑
  GitHub Actions (runs on schedule, e.g. nightly)
  Reads aggregated data from Supabase → commits updated TOML to repo
```

## Why This Stack

- **Supabase (Postgres)** — stable, mature, generous free tier, auto-generated REST API, row-level security handles public read / authenticated write cleanly. CPAC clients write directly to Supabase on submission — no GitHub round-trip.
- **GitHub** — source of truth, fully auditable, human-readable TOML diffs on every advisory or snapshot change. GitHub Actions reads aggregated data from Supabase and commits updated TOML files on a schedule (e.g. nightly). One single commit per run, no overlap possible.
- **Custom domain proxy** — `thecinderproject.qd.je/cpac-trust-db/api/*` keeps the API endpoint stable regardless of backend changes.

## Data Flow

1. **Snapshots** — CPAC clients POST to `/api/submit/snapshot` → writes directly to Supabase
2. **Advisories** — Core team merges TOML to `main` → GitHub Actions upserts to Supabase
3. **Sync** — GitHub Actions runs nightly → reads from Supabase → commits TOML to repo
4. **Queries** — CPAC client hits API endpoints → reads from Supabase → caches locally

---

*Part of The Cinder Project*
