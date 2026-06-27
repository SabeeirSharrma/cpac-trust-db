---
title: Architecture
description: System design and tech stack for cpac-trust-db.
order: 2
---

# Architecture

## Overview

```
CPAC client
  POST /rest/v1/snapshots → writes directly to Supabase
       ↓
  Supabase (Postgres)
  Compiled, queryable database
       ↓
  CPAC client reads (GET /rest/v1/advisories, /rest/v1/snapshots, /rest/v1/meta)
  Local cache at ~/.cpac/trust-db/
       ↑
  GitHub Actions (runs nightly)
  Reads aggregated data from Supabase → commits updated TOML to repo
```

## Why This Stack

- **Supabase (Postgres)** — stable, mature, generous free tier, auto-generated REST API, row-level security handles public read / authenticated write cleanly. CPAC clients write directly to Supabase on submission — no GitHub round-trip.
- **GitHub** — source of truth, fully auditable, human-readable TOML diffs on every advisory or snapshot change. GitHub Actions reads aggregated data from Supabase and commits updated TOML files on a schedule (nightly). One single commit per run, no overlap possible.
- **Direct Supabase** — CPAC talks directly to Supabase REST API. Custom domain proxy planned but not yet implemented.

## Data Flow

1. **Snapshots** — CPAC clients POST to `/rest/v1/snapshots` → writes directly to Supabase
2. **Advisories** — Core team merges TOML to `main` → GitHub Actions upserts to Supabase
3. **Sync** — GitHub Actions runs nightly → reads from Supabase → commits TOML to repo
4. **Queries** — CPAC client hits Supabase REST API → reads data → caches locally

---

*Part of The Cinder Project*
