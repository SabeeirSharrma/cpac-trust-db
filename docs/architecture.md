---
title: Architecture
description: System design and tech stack for cpac-trust-db.
order: 2
---

# Architecture

## Overview

```
GitHub (cpac-trust-db repo)
  Raw TOML files — human-readable, auditable source of truth
       ↓
  GitHub Actions (on merge to main)
       ↓
  Supabase (Postgres)
  Compiled, queryable database
       ↓
  thecinderproject.qd.je/cpac-trust-db/api/*
  Public REST API (proxied through existing domain)
       ↓
  CPAC client
  Local cache at ~/.cpac/trust-db/
```

## Why This Stack

- **GitHub** — source of truth, fully auditable, human-readable TOML diffs on every advisory or snapshot change. Anyone can verify what's in the database.
- **Supabase (Postgres)** — stable, mature, generous free tier, auto-generated REST API, row-level security handles public read / authenticated write cleanly. Supabase is already in use elsewhere in The Cinder Project stack.
- **Custom domain proxy** — `thecinderproject.qd.je/cpac-trust-db/api/*` keeps the API endpoint stable regardless of backend changes. If the backend ever moves from Supabase to something else, the URL doesn't change and no CPAC clients break.

## Data Flow

1. **Advisories** — Core team merges TOML to `main` → GitHub Actions upserts to Supabase
2. **Snapshots** — CPAC clients POST to `/api/submit/snapshot` → GitHub Actions aggregates into TOML → commits to repo → syncs to Supabase
3. **Queries** — CPAC client hits API endpoints → reads from Supabase → caches locally

---

*Part of The Cinder Project*
