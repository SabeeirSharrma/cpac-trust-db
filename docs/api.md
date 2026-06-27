---
title: API Endpoints
description: REST API reference for cpac-trust-db.
order: 3
---

# API Endpoints

All endpoints are served directly by Supabase REST API. There is no custom domain proxy — CPAC clients talk to Supabase at:

```
https://qzhhsyucnlswmsvpssdh.supabase.co
```

All reads are public (anon key). Writes require an anonymous client token (rate limiting only, not authentication).

---

## Meta

```text
GET /rest/v1/meta?select=*
→ [{
    version: "abc123",          # hash of current DB state
    updated_at: "2026-06-26T12:00:00Z",
    advisory_count: 12,
    snapshot_package_count: 847,
    schema_version: 1
  }]
```

Used by CPAC clients to check if their local cache is stale without downloading full data. This is the only request made on every `cpac install`.

---

## Advisories

```text
GET /rest/v1/advisories?select=*&order=reported.desc
→ [ ...all advisories... ]

GET /rest/v1/advisories?select=*&package=eq.<package-name>
→ advisory object or empty array
```

---

## Snapshots

```text
GET /rest/v1/snapshots?select=*&package=eq.<package-name>
→ [ ...snapshot entries for a package... ]

GET /rest/v1/snapshots?select=*&package=eq.<package-name>&version=eq.<version>
→ snapshot entries for a specific version
```

---

## Submissions (Authenticated)

```text
POST /rest/v1/snapshots
Authorization: Bearer <anon-key>
X-Client-Token: <anonymous-token>
Content-Type: application/json

→ Submit a PKGBUILD hash or full sanitized PKGBUILD
```

Tokens are issued per CPAC installation on first run (anonymous, non-identifying). Used for rate limiting and abuse prevention only — not for identifying users. See [Auth Model](auth.md) for token issuance details.

---

*Part of The Cinder Project*
