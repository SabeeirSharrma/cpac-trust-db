---
title: GitHub Actions
description: Sync pipeline from TOML to Supabase.
order: 8
---

# GitHub Actions Pipeline

## Trigger

Scheduled (e.g. nightly), not on push.

## Pipeline Steps

```
Trigger: scheduled (e.g. nightly)
        ↓
Action 1: Read aggregated snapshot data from Supabase
        ↓
Action 2: Compile + update hashes.toml files
        ↓
Action 3: Commit updated TOML to repo (one single commit per run)
        ↓
Action 4: Update meta/db.toml with new version hash + timestamp
```

## What It Does

1. **Reads** aggregated snapshot data from Supabase
2. **Compiles** updated `hashes.toml` files
3. **Commits** to the repo (one single commit per scheduled run)
4. **Updates** `meta/db.toml` with new version hash and timestamp

GitHub Actions runs on a schedule, **not on push**. It reads FROM Supabase
and commits TO the repo. One single commit per run, no overlap possible.

---

*Part of The Cinder Project*
