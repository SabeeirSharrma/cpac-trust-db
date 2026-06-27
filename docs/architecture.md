---
title: Architecture
description: System design and tech stack for cpac-trust-db.
order: 2
---

# Architecture

## Overview

```
CPAC client
       ↓
  api.thecinderproject.qd.je/cpac-trust-db/api/*
  Cloudflare Worker (URL proxy, rate limiting, CORS)
       ↓
  Supabase (Postgres)
  qzhhsyucnlswmsvpssdh.supabase.co
       ↓
  CPAC client reads → local cache at ~/.cpac/trust-db/
       ↑
  GitHub Actions (runs nightly)
  Reads from Supabase → commits updated TOML to repo
```

## Why This Stack

- **Cloudflare Worker** — proxies `api.thecinderproject.qd.je` to Supabase. Provides a stable API URL independent of the backend, handles CORS, and can add rate limiting or request logging later.
- **Supabase (Postgres)** — stable, mature, generous free tier, auto-generated REST API, row-level security handles public read / authenticated write cleanly.
- **GitHub** — source of truth, fully auditable, human-readable TOML diffs on every advisory or snapshot change. GitHub Actions reads aggregated data from Supabase and commits updated TOML files on a schedule (nightly). One single commit per run, no overlap possible.

## Data Flow

1. **Snapshots** — CPAC clients POST to `api.thecinderproject.qd.je/cpac-trust-db/api/snapshots` → Worker proxies to Supabase
2. **Advisories** — Core team merges TOML to `main` → GitHub Actions upserts to Supabase
3. **Sync** — GitHub Actions runs nightly → reads from Supabase → commits TOML to repo
4. **Queries** — CPAC client hits Worker API → Worker proxies to Supabase → CPAC caches locally

## Direct Supabase (Fallback)

If the proxy is unavailable, CPAC clients can fall back to direct Supabase access at `https://qzhhsyucnlswmsvpssdh.supabase.co`. The anon key is embedded in the client, which is safe because row-level security policies enforce public reads and rate-limited writes only.

---

*Part of The Cinder Project*
