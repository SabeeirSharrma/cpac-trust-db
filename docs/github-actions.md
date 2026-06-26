---
title: GitHub Actions
description: Sync pipeline from TOML to Supabase.
order: 8
---

# GitHub Actions Pipeline

## Trigger

Push to `main` (advisory added or snapshot aggregated).

## Pipeline Steps

```
Trigger: push to main (advisory added or snapshot aggregated)
        ↓
Action 1: Validate TOML schema
        ↓
Action 2: Compile TOML → Supabase (upsert changed records)
        ↓
Action 3: Update meta/db.toml with new version hash + timestamp
        ↓
Action 4: Cut a new GitHub release with changelog (advisories only)
```

## What It Does

1. **Validates** TOML files against the schema
2. **Upserts** changed records into Supabase
3. **Updates** `meta/db.toml` with new version hash and timestamp
4. **Releases** changelog for advisory changes (not snapshots)

---

*Part of The Cinder Project*
