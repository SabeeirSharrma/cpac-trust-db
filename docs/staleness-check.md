---
title: Staleness Check
description: How CPAC detects and syncs stale trust data.
order: 4
---

# Staleness Check System

CPAC never blindly re-downloads the full database. Instead it uses a lightweight two-step check.

---

## Step 1 — Meta Check

**When:** Every `cpac install`, `cpac trust`, `cpac audit`

```
GET /api/meta
  → { version: "abc123" }
          ↓
Compare against local ~/.cpac/trust-db/meta.toml
  → version matches?  Use local cache. Done. (one cheap HTTP request)
  → version differs?  Queue a delta sync for next cpac update.
  → no local cache?   Fetch full DB immediately.
```

---

## Step 2 — Delta Sync

**When:** `cpac update`, or when meta check detects a change

```
GET /api/delta?since=<last_sync_timestamp>
  → only changed advisories and snapshots since last sync
          ↓
Merge into local cache
          ↓
Update local meta.toml with new version hash + timestamp
```

---

## Summary

| Command | Network Request | Behavior |
|---|---|---|
| `cpac install` | GET `/api/meta` | One cheap request, uses local cache |
| `cpac update` | GET `/api/delta` | Full delta sync if version changed |
| Offline | None | Uses local cache, warns user |

---

*Part of The Cinder Project*
