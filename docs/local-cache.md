---
title: Local Cache
description: Local storage structure for offline trust queries.
order: 5
---

# Local Cache

## Storage Location

```
~/.cpac/trust-db/
  meta.toml           # version hash, last sync timestamp, schema version
  advisories.db       # compiled advisory index (fast lookup by package name)
  snapshots.db        # compiled snapshot index (fast lookup by package + version)
```

## How It Works

The raw TOML from the GitHub repo is compiled into a local binary format on sync, so runtime queries are fast and don't require network access.

## Offline Behavior

If the local cache is stale and the network is unavailable, CPAC warns the user but continues using the local copy — **never blocks on network.**

---

*Part of The Cinder Project*
