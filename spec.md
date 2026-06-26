# cpac-trust-db
> *Community-maintained trust data for CPAC.*

> **The Cinder Project** — *"Burn the Blind Spots"*

---

## What is cpac-trust-db?

`cpac-trust-db` is the trust data backend for CPAC. It stores two categories of data:

1. **PKGBUILD snapshots** — anonymized, crowdsourced snapshots submitted by CPAC
   clients, used to detect divergence from known-good package states
2. **Advisories** — maintainer-curated records of known malicious, compromised, or
   suspicious packages (e.g. Atomic Arch-style hijacks)

---

## Architecture

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

### Why this stack

- **GitHub** — source of truth, fully auditable, human-readable TOML diffs on every
  advisory or snapshot change. Anyone can verify what's in the database.
- **Supabase (Postgres)** — stable, mature, generous free tier, auto-generated REST API,
  row-level security handles public read / authenticated write cleanly. Supabase is
  already in use elsewhere in The Cinder Project stack.
- **Custom domain proxy** — `thecinderproject.qd.je/cpac-trust-db/api/*` keeps the
  API endpoint stable regardless of backend changes. If the backend ever moves from
  Supabase to something else, the URL doesn't change and no CPAC clients break.

---

## API Endpoints

All endpoints are public read. Writes require an authenticated token.

### Meta

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

Used by CPAC clients to check if their local cache is stale without
downloading full data. This is the only request made on every `cpac install`.

### Advisories

```
GET /api/advisories
→ [ ...all advisories... ]

GET /api/advisories/<package-name>
→ advisory object or 404
```

### Snapshots

```
GET /api/snapshots/<package-name>
→ { hashes: [...], pkgbuilds: [...] }

GET /api/snapshots/<package-name>/<version>
→ snapshot entries for a specific version
```

### Delta sync

```
GET /api/delta?since=<timestamp>
→ { advisories: [...changed...], snapshots: [...changed...] }
```

Used by `cpac update` to pull only records that changed since the last sync,
rather than re-downloading the full database every time.

### Submissions (authenticated)

```
POST /api/submit/snapshot
Authorization: Bearer <token>
→ Submit a PKGBUILD hash or full sanitized PKGBUILD
```

Tokens are issued per CPAC installation on first run (anonymous, non-identifying).
Used for rate limiting and abuse prevention only — not for identifying users.

---

## Staleness Check System

CPAC never blindly re-downloads the full database. Instead it uses a
lightweight two-step check:

### Step 1 — Meta check (every cpac install/trust/audit)

```
GET /api/meta
  → { version: "abc123" }
          ↓
Compare against local ~/.cpac/trust-db/meta.toml
  → version matches?  Use local cache. Done. (one cheap HTTP request)
  → version differs?  Queue a delta sync for next cpac update.
  → no local cache?   Fetch full DB immediately.
```

### Step 2 — Delta sync (cpac update, or when meta check detects change)

```
GET /api/delta?since=<last_sync_timestamp>
  → only changed advisories and snapshots since last sync
          ↓
Merge into local cache
          ↓
Update local meta.toml with new version hash + timestamp
```

This means:
- `cpac install` — one lightweight GET to `/api/meta`, no full sync
- `cpac update` — full delta sync if version hash changed, no-op if already current
- **Offline** — local cache is always used if network is unavailable, never blocks

---

## Local Cache

```
~/.cpac/trust-db/
  meta.toml           # version hash, last sync timestamp, schema version
  advisories.db       # compiled advisory index (fast lookup by package name)
  snapshots.db        # compiled snapshot index (fast lookup by package + version)
```

The raw TOML from the GitHub repo is compiled into a local binary format on sync,
so runtime queries are fast and don't require network access.

If the local cache is stale and the network is unavailable, CPAC warns the user
but continues using the local copy — **never blocks on network.**

---

## Data Categories

### 1. Advisories (maintainer-curated)

Maintained directly by The Cinder Project core team. Stored as TOML in the
GitHub repo, synced to Supabase via GitHub Actions on merge.

```toml
[advisory]
package = "malicious-pkg"
severity = "critical"          # critical | high | medium | low
status = "confirmed"           # confirmed | suspected | resolved
reported = "2026-06-14"
updated = "2026-06-14"
reported_by = "The Cinder Project"
cve = ""                       # if applicable

[details]
summary = "PKGBUILD modified to execute remote script post-install"
description = """
On 2026-06-14, maintainer transferred ownership and introduced a
curl | bash call targeting an external IP.
"""
affected_versions = ["1.2.3-1", "1.2.4-1"]
safe_versions = []

[references]
urls = ["https://thecinderproject.qd.je/advisories/malicious-pkg-2026-06-14"]
```

**Submission:** Community members report via GitHub issue or Discord. Core team
reviews evidence and publishes. No automated advisory submissions.

### Advisory Severity → Trust Score Impact

| Severity | Trust Penalty | Recommendation Floor |
|---|---|---|
| Critical | -30 | DANGER |
| High | -20 | WARNING |
| Medium | -10 | CAUTION |
| Low | -5 | No floor change |
| Suspected (any) | -15 | WARNING |
| Resolved | 0 | No penalty |

---

### 2. PKGBUILD Snapshots (automated client submissions)

Submitted anonymously by CPAC clients that opted into crowdsourced sharing.
Two formats depending on user consent level.

#### Hash submissions (consent: `hash`)

```toml
[[entry]]
version = "152.0.1-1"
sha256 = "abc123..."
submitted_count = 847
first_seen = "2026-05-01"
last_seen = "2026-06-20"

[[entry]]
version = "152.0.1-1"
sha256 = "def456..."           # minority hash — potential divergence
submitted_count = 2
first_seen = "2026-06-14"
last_seen = "2026-06-14"
```

#### Full PKGBUILD submissions (consent: `full`)

Stored as sanitized PKGBUILD text. Pass 1 structural redaction (local paths,
hostname, local IPs, non-public emails) runs locally before submission.
See `CPAC_SPEC.md` for the full sanitization pipeline.

**Submission:** Automated only via `POST /api/submit/snapshot`. No manual PRs
for snapshot data. Submissions are batched on `cpac update`, never sent
mid-install.

**Effect on trust score:**
- Hash matches majority consensus → positive trust signal
- Hash matches small minority or no known submissions → warning signal

---

## Submission Pipeline

```
cpac install some-aur-package
        ↓
Fetch PKGBUILD locally
        ↓
Pass 1 sanitization (strip paths/hostname/IPs/emails)
        ↓
Pass 2 anomaly detection (flag suspicious patterns → trust signals, shown to user)
        ↓
consent=hash → compute SHA-256, queue locally
consent=full → queue sanitized PKGBUILD locally
        ↓
cpac update → batch POST to /api/submit/snapshot
        ↓
GitHub Actions aggregates into TOML → commits to repo → syncs to Supabase
```

Submissions are **queued locally and sent in batch on `cpac update`** — never
sent mid-install, never blocking the install flow.

---

## GitHub Actions Pipeline

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

---

## Auth Model

| Operation | Auth Required |
|---|---|
| Read advisories | None — fully public |
| Read snapshots | None — fully public |
| GET /api/meta | None — fully public |
| POST /api/submit/snapshot | Bearer token (per-install, anonymous) |
| Write advisories | Maintainer only (Supabase RLS) |

Anonymous tokens are issued on first CPAC run. They are used for rate limiting
and abuse prevention only — not linked to any user identity.

---

## Governance

| Data Type | Who Can Submit | Review Required |
|---|---|---|
| Advisories | Core team only (via GitHub PR) | Yes — maintainer merge |
| Snapshots (hash) | Automated CPAC clients | No — aggregated automatically |
| Snapshots (full) | Automated CPAC clients | No — aggregated automatically |

---

## Repository Structure

```
cpac-trust-db/
├── advisories/
│   ├── README.md
│   ├── schema.md
│   └── packages/
│       └── <package-name>.toml
├── snapshots/
│   ├── README.md
│   ├── schema.md
│   └── packages/
│       └── <package-name>/
│           ├── hashes.toml
│           └── pkgbuilds/
├── meta/
│   └── db.toml
├── .github/
│   └── workflows/
│       └── sync.yml           # GitHub Actions → Supabase pipeline
└── README.md
```

---

## Roadmap

- [ ] Supabase schema setup (advisories + snapshots tables)
- [ ] GitHub Actions sync pipeline (TOML → Supabase)
- [ ] `/api/meta` endpoint
- [ ] `/api/advisories` + `/api/snapshots` endpoints
- [ ] `/api/delta` endpoint
- [ ] CPAC integration — meta check on install, delta sync on update
- [ ] Submission pipeline — anonymous tokens, batch POST on update
- [ ] First advisory entries (Atomic Arch affected packages)
- [ ] Public advisory index on website

---

## Related Projects

| Project | Role |
|---|---|
| `cpac` | Consumes trust-db; submits snapshots on `cpac update` |
| `cinderos` | Ships CPAC (and therefore trust-db) by default |
| `website` | Public advisory index at `thecinderproject.qd.je/advisories` |

---

*Part of The Cinder Project — github.com/SabeeirSharrma/cpac-trust-db*