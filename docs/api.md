---
title: API Endpoints
description: REST API reference for cpac-trust-db.
order: 3
---

# API Endpoints

All endpoints are public read. Writes require an authenticated token.

Base URL: `thecinderproject.qd.je/cpac-trust-db/api/`

---

## Meta

```
GET /api/meta
→ {
    version: "abc123",          # hash of current DB state
    updated_at: "2026-06-26T12:00:00Z",
    advisory_count: 12,
    snapshot_package_count: 847,
    schema_version: 1
  }
```

Used by CPAC clients to check if their local cache is stale without downloading full data. This is the only request made on every `cpac install`.

---

## Advisories

```
GET /api/advisories
→ [ ...all advisories... ]

GET /api/advisories/<package-name>
→ advisory object or 404
```

---

## Snapshots

```
GET /api/snapshots/<package-name>
→ { hashes: [...], pkgbuilds: [...] }

GET /api/snapshots/<package-name>/<version>
→ snapshot entries for a specific version
```

---

## Delta Sync

```
GET /api/delta?since=<timestamp>
→ { advisories: [...changed...], snapshots: [...changed...] }
```

Used by `cpac update` to pull only records that changed since the last sync, rather than re-downloading the full database every time.

---

## Submissions (Authenticated)

```
POST /api/submit/snapshot
Authorization: Bearer <token>
→ Submit a PKGBUILD hash or full sanitized PKGBUILD
```

Tokens are issued per CPAC installation on first run (anonymous, non-identifying). Used for rate limiting and abuse prevention only — not for identifying users.

---

*Part of The Cinder Project*
